//
//  SecurityCoordinator.swift
//  Pupil
//
//  Deterministic security state machine and hardware/vision event coordinator.
//  States: DISARMED -> ARMING -> ARMED -> TAMPER_PENDING -> ALARM
//

import AppKit
import Foundation
import Observation

public enum SecurityState: String, Codable, Sendable, CaseIterable {
    case disarmed = "DISARMED"
    case arming = "ARMING"
    case armed = "ARMED"
    case tamperPending = "TAMPER_PENDING"
    case alarm = "ALARM"

    public var label: String {
        switch self {
        case .disarmed: return "Disarmed"
        case .arming: return "Arming…"
        case .armed: return "Armed"
        case .tamperPending: return "Tamper Countdown"
        case .alarm: return "Alarm Latched"
        }
    }

    public var symbolName: String {
        switch self {
        case .disarmed: return "eye"
        case .arming: return "timer"
        case .armed: return "eye.slash.fill"
        case .tamperPending: return "exclamationmark.triangle.fill"
        case .alarm: return "light.beacon.max.fill"
        }
    }
}

public enum TamperSource: String, Codable, Sendable {
    case chargerUnplugged = "AC Charger Unplugged"
    case lidClosed = "Clamshell Lid Closed"
    case screenLocked = "Screen Locked"
    case wakeWhileArmed = "System Woke While Armed"
    case manualTest = "Simulated Tamper Test"
}

public struct SecurityEventRecord: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let title: String
    public let detail: String
    public let stateAtEvent: SecurityState
    public let isSimulated: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        title: String,
        detail: String,
        stateAtEvent: SecurityState,
        isSimulated: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.title = title
        self.detail = detail
        self.stateAtEvent = stateAtEvent
        self.isSimulated = isSimulated
    }
}

@MainActor
@Observable
public final class SecurityCoordinator {
    public private(set) var state: SecurityState = .disarmed
    public private(set) var countdownSecondsRemaining: Int = 0
    public private(set) var activeTamperSource: TamperSource?
    public private(set) var isGazeWarningActive: Bool = false
    public private(set) var gazeDwellProgress: Double = 0
    public private(set) var latestGazeScore: Float = 0
    public private(set) var eyeLookOffset: CGPoint = .zero
    public private(set) var activeFaceCount: Int = 0
    public private(set) var events: [SecurityEventRecord] = []
    public private(set) var hasEnrolledPin: Bool = KeychainManager.hasEnrolledPin
    public private(set) var isCameraPreviewRequested: Bool = false
    public private(set) var isShieldPreviewActive: Bool = false

    public let settings: PupilSettings
    public let powerMonitor: PowerAndLidMonitor
    public let lockMonitor: LockMonitor
    public let cameraManager: CameraManager

    public var onStateChanged: ((SecurityState) -> Void)?
    public var onNotchUpdateNeeded: (() -> Void)?

    private var gazeAggregator = GazeTemporalAggregator()
    private var countdownTimer: Timer?
    private var gazeWarningDismissWorkItem: DispatchWorkItem?

    public init(
        settings: PupilSettings = .shared,
        powerMonitor: PowerAndLidMonitor = PowerAndLidMonitor(),
        lockMonitor: LockMonitor = LockMonitor(),
        cameraManager: CameraManager = CameraManager()
    ) {
        self.settings = settings
        self.powerMonitor = powerMonitor
        self.lockMonitor = lockMonitor
        self.cameraManager = cameraManager

        // Ensure a default PIN ("1234") is enrolled on first launch if none exists so the user can test immediately,
        // and clearly surface PIN changes in Settings.
        if !hasEnrolledPin {
            try? KeychainManager.enrollPin("1234")
            self.hasEnrolledPin = true
        }

        bindSensors()
    }

    public var isMonitoring: Bool {
        state != .disarmed
    }

    public var menuBarSymbolName: String {
        if state == .armed && isGazeWarningActive {
            return "eye.fill"
        }
        return state.symbolName
    }

    // MARK: - Arm & Disarm Lifecycle

    public func startArming(immediate: Bool = false) {
        guard state == .disarmed else { return }
        gazeAggregator.reset()
        isGazeWarningActive = false
        gazeDwellProgress = 0
        activeTamperSource = nil

        if settings.holdSleepOnLidClose {
            powerMonitor.acquireSleepHoldAssertion()
        }

        if immediate || settings.exitDelaySeconds <= 0 {
            completeArming()
            return
        }

        state = .arming
        countdownSecondsRemaining = settings.exitDelaySeconds
        logEvent("Arming Started", detail: "\(settings.exitDelaySeconds)s exit delay started.")
        syncCameraLifecycle()
        onStateChanged?(state)
        onNotchUpdateNeeded?()

        startCountdownTimer(seconds: settings.exitDelaySeconds) { [weak self] in
            self?.completeArming()
        }
    }

    public func completeArming() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownSecondsRemaining = 0
        state = .armed
        let acNote = powerMonitor.isOnACPower ? "AC power connected (unplug armed)." : "Armed on battery."
        logEvent("System Armed", detail: "Monitoring active. \(acNote)")
        syncCameraLifecycle()
        onStateChanged?(state)
        onNotchUpdateNeeded?()
    }

    @discardableResult
    public func disarmWithPin(_ pin: String) -> Bool {
        guard KeychainManager.verifyPin(pin) else {
            logEvent("Disarm Failed", detail: "Incorrect PIN entered during \(state.label).")
            if settings.hapticFeedbackEnabled {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            }
            return false
        }
        performValidatedDisarm(method: "PIN")
        return true
    }

    public func disarmWithTouchID() async -> Bool {
        guard settings.allowTouchIDDisarm else { return false }
        let ok = await KeychainManager.authenticateWithTouchID(reason: "Disarm Pupil laptop security")
        if ok {
            performValidatedDisarm(method: "Touch ID")
        }
        return ok
    }

    /// Allows canceling during the initial `ARMING` exit-delay without requiring a PIN.
    public func cancelArmingDuringExitDelay() {
        guard state == .arming else { return }
        performValidatedDisarm(method: "Exit Delay Cancel")
    }

    public func updatePin(newPin: String) throws {
        try KeychainManager.enrollPin(newPin)
        hasEnrolledPin = KeychainManager.hasEnrolledPin
        logEvent("PIN Updated", detail: "Security PIN updated in macOS Keychain.")
    }

    private func performValidatedDisarm(method: String) {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownSecondsRemaining = 0
        SirenSynthesizer.shared.stop()
        powerMonitor.releaseSleepHoldAssertion()

        state = .disarmed
        activeTamperSource = nil
        isGazeWarningActive = false
        isShieldPreviewActive = false
        gazeDwellProgress = 0
        gazeAggregator.reset()
        syncCameraLifecycle()

        logEvent("Disarmed", detail: "Session disarmed via \(method).")
        onStateChanged?(state)
        onNotchUpdateNeeded?()
    }

    // MARK: - Tamper & Alarm Escalation

    public func triggerTamper(source: TamperSource, immediateAlarm: Bool = false, simulated: Bool = false) {
        guard state != .disarmed else { return }
        if state == .arming {
            completeArming()
        }

        if state == .alarm {
            logEvent("Repeated Tamper Signal", detail: "\(source.rawValue) while alarm already latched.", simulated: simulated)
            return
        }

        activeTamperSource = source

        if immediateAlarm {
            enterAlarm(source: source, simulated: simulated)
            return
        }

        guard state == .armed else { return }
        state = .tamperPending
        countdownSecondsRemaining = settings.gracePeriodSeconds
        logEvent(
            "Tamper Detected: \(source.rawValue)",
            detail: "\(settings.gracePeriodSeconds)s grace countdown started before siren latches.",
            simulated: simulated
        )
        onStateChanged?(state)
        onNotchUpdateNeeded?()

        startCountdownTimer(seconds: settings.gracePeriodSeconds) { [weak self] in
            guard let self else { return }
            self.enterAlarm(source: source, simulated: simulated)
        }
    }

    public func enterAlarm(source: TamperSource, simulated: Bool = false) {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownSecondsRemaining = 0
        activeTamperSource = source
        state = .alarm

        powerMonitor.acquireSleepHoldAssertion(reason: "Pupil Active Theft Siren")
        SirenSynthesizer.shared.start(baseFrequencyHz: Double(settings.sirenFrequencyHz))

        logEvent(
            "ALARM LATCHED",
            detail: "Triggered by \(source.rawValue). Audible siren active until PIN or Touch ID disarm.",
            simulated: simulated
        )
        onStateChanged?(state)
        onNotchUpdateNeeded?()
    }

    // MARK: - Gaze Processing & Simulation

    public func ingestGazeSample(_ sample: GazeSample) {
        let snapshot = gazeAggregator.ingest(
            sample,
            scoreThreshold: settings.gazeSensitivity.scoreThreshold,
            dwellThresholdSeconds: settings.dwellThresholdSeconds
        )
        latestGazeScore = snapshot.latestScore
        gazeDwellProgress = snapshot.dwellProgress
        eyeLookOffset = snapshot.eyeLookOffset
        activeFaceCount = snapshot.activeFaceCount

        guard state == .armed, settings.gazeDetectionEnabled else { return }

        if snapshot.isGazeWarningActive && !isGazeWarningActive {
            activateGazeWarning(simulated: false)
        }
    }

    public func simulateGazeWarning() {
        if state == .disarmed {
            startArming(immediate: true)
        }
        gazeDwellProgress = 1.0
        latestGazeScore = 0.92
        eyeLookOffset = CGPoint(x: 0.25, y: -0.1)
        activateGazeWarning(simulated: true)
    }

    public func previewScreenShield(durationSeconds: Double = 4.5) {
        isShieldPreviewActive = true
        logEvent("Screen Shield Preview", detail: "Previewing full-screen privacy blur for \(String(format: "%.1fs", durationSeconds)).", simulated: true)
        onStateChanged?(state)
        onNotchUpdateNeeded?()

        DispatchQueue.main.asyncAfter(deadline: .now() + durationSeconds) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isShieldPreviewActive else { return }
                self.isShieldPreviewActive = false
                self.onStateChanged?(self.state)
                self.onNotchUpdateNeeded?()
            }
        }
    }

    private func activateGazeWarning(simulated: Bool) {
        isGazeWarningActive = true
        gazeWarningDismissWorkItem?.cancel()

        logEvent(
            "Gaze Warning",
            detail: "Sustained gaze toward screen detected (≥ \(String(format: "%.1fs", settings.dwellThresholdSeconds))). Eye deterrent opened.",
            simulated: simulated
        )
        if settings.hapticFeedbackEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        onNotchUpdateNeeded?()

        let dismissItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isGazeWarningActive = false
                self.gazeDwellProgress = 0
                self.gazeAggregator.reset()
                self.onNotchUpdateNeeded?()
            }
        }
        gazeWarningDismissWorkItem = dismissItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5, execute: dismissItem)
    }

    // MARK: - Camera Lifecycle

    public func setCameraPreviewRequested(_ requested: Bool) {
        isCameraPreviewRequested = requested
        syncCameraLifecycle()
    }

    public func syncCameraLifecycle() {
        let shouldRunCamera = isCameraPreviewRequested || (isMonitoring && settings.gazeDetectionEnabled)
        if shouldRunCamera {
            cameraManager.startCapture(preferredDeviceID: settings.preferredCameraID)
        } else {
            cameraManager.stopCapture()
        }
    }

    public func clearEventLog() {
        events.removeAll()
    }

    // MARK: - Private Sensor Bindings

    private func bindSensors() {
        powerMonitor.onHardwareEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .chargerUnplugged:
                if self.settings.hardwareTriggers.contains(.chargerUnplug) {
                    self.triggerTamper(source: .chargerUnplugged, immediateAlarm: false)
                }
            case .lidClosed, .systemWillSleep:
                if self.settings.hardwareTriggers.contains(.lidClose) {
                    // Lid close triggers immediate siren before macOS cuts audio on sleep
                    self.triggerTamper(source: .lidClosed, immediateAlarm: true)
                }
            case .systemDidWake:
                if self.isMonitoring {
                    self.triggerTamper(source: .wakeWhileArmed, immediateAlarm: true)
                }
            case .chargerPluggedIn, .lidOpened:
                break
            }
        }

        lockMonitor.onLockEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .screenLocked:
                if self.settings.hardwareTriggers.contains(.screenLock) {
                    self.triggerTamper(source: .screenLocked, immediateAlarm: false)
                }
            case .willSleep:
                if self.settings.hardwareTriggers.contains(.lidClose) {
                    self.triggerTamper(source: .lidClosed, immediateAlarm: true)
                }
            case .wake:
                if self.isMonitoring && self.state == .alarm {
                    SirenSynthesizer.shared.start(baseFrequencyHz: Double(self.settings.sirenFrequencyHz))
                }
            case .screenUnlocked:
                break
            }
        }

        cameraManager.onGazeSample = { [weak self] sample in
            self?.ingestGazeSample(sample)
        }
    }

    private func startCountdownTimer(seconds: Int, onExpire: @escaping @MainActor () -> Void) {
        countdownTimer?.invalidate()
        countdownSecondsRemaining = seconds
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.countdownSecondsRemaining > 1 {
                    self.countdownSecondsRemaining -= 1
                    self.onNotchUpdateNeeded?()
                } else {
                    self.countdownTimer?.invalidate()
                    self.countdownTimer = nil
                    self.countdownSecondsRemaining = 0
                    onExpire()
                }
            }
        }
    }

    private func logEvent(_ title: String, detail: String, simulated: Bool = false) {
        let record = SecurityEventRecord(
            title: title,
            detail: detail,
            stateAtEvent: state,
            isSimulated: simulated
        )
        events.insert(record, at: 0)
        if events.count > 100 {
            events.removeLast(events.count - 100)
        }
    }
}
