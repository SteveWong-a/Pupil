//
//  PupilSettings.swift
//  Pupil
//
//  Reactive, UserDefaults-backed configuration store modeled after GlanceSettings.
//

import Foundation
import Observation
import SwiftUI

public enum GazeSensitivity: String, CaseIterable, Identifiable, Codable, Sendable {
    case relaxed
    case balanced
    case strict
    case ultra

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .relaxed: return "Relaxed"
        case .balanced: return "Default"
        case .strict: return "Strict"
        case .ultra: return "Ultra"
        }
    }

    public var subtitle: String {
        switch self {
        case .relaxed: return "Direct frontal gaze only."
        case .balanced: return "Balanced detection cone."
        case .strict: return "Wide peripheral detection cone."
        case .ultra: return "Aggressive cone for side shoulder-surfing."
        }
    }

    public var scoreThreshold: Float {
        switch self {
        case .relaxed: return 0.75
        case .balanced: return 0.65
        case .strict: return 0.52
        case .ultra: return 0.40
        }
    }

    public var iconName: String {
        switch self {
        case .relaxed: return "eye"
        case .balanced: return "eye.fill"
        case .strict: return "eye.trianglebadge.exclamationmark"
        case .ultra: return "eye.trianglebadge.exclamationmark.fill"
        }
    }
}

public enum NotchDeterrentStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case minimalPill
    case silent

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .minimalPill: return "Minimal Pill"
        case .silent: return "Silent Log"
        }
    }

    public var subtitle: String {
        switch self {
        case .minimalPill: return "Widens the dark notch silhouette subtly with a status glyph."
        case .silent: return "Logs gaze events silently without modifying the notch."
        }
    }
}

public enum SpatialMotionSensitivity: String, CaseIterable, Identifiable, Codable, Sendable {
    case low
    case medium
    case high

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    public var subtitle: String {
        switch self {
        case .low: return "Large camera displacement required (ignores heavy desk vibration)."
        case .medium: return "Balanced lift & walk detection deadband."
        case .high: return "Strict spatial lock; detects subtle laptop tilt or lift."
        }
    }

    /// Normalized translation deadband threshold ||Δt|| (fraction of frame width).
    public var translationDeadband: Float {
        switch self {
        case .low: return 0.065
        case .medium: return 0.040
        case .high: return 0.022
        }
    }

    /// Homography warp Frobenius norm deadband threshold.
    public var warpDeadband: Float {
        switch self {
        case .low: return 0.22
        case .medium: return 0.14
        case .high: return 0.08
        }
    }
}

public enum HardwareTrigger: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case chargerUnplug
    case lidClose
    case screenLock

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .chargerUnplug: return "Power Unplug"
        case .lidClose: return "Lid Close"
        case .screenLock: return "Screen Lock"
        }
    }

    public var iconName: String {
        switch self {
        case .chargerUnplug: return "bolt.slash.fill"
        case .lidClose: return "laptopcomputer.slash"
        case .screenLock: return "lock.fill"
        }
    }
}

public struct CameraROI: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public static let `default` = CameraROI(x: 0.15, y: 0.10, width: 0.70, height: 0.80)

    public func contains(normalizedPoint point: CGPoint) -> Bool {
        point.x >= x && point.x <= (x + width) &&
        point.y >= y && point.y <= (y + height)
    }
}

@MainActor
@Observable
public final class PupilSettings {
    public static let shared = PupilSettings()

    private let defaults: UserDefaults
    private var menuBarVisibilityHandler: ((Bool) -> Void)?

    public var showsInMenuBar: Bool {
        didSet {
            defaults.set(showsInMenuBar, forKey: Keys.showsInMenuBar)
            menuBarVisibilityHandler?(showsInMenuBar)
        }
    }

    public var exitDelaySeconds: Int {
        didSet { defaults.set(exitDelaySeconds, forKey: Keys.exitDelaySeconds) }
    }

    public var gracePeriodSeconds: Int {
        didSet { defaults.set(gracePeriodSeconds, forKey: Keys.gracePeriodSeconds) }
    }

    public var gazeDetectionEnabled: Bool {
        didSet { defaults.set(gazeDetectionEnabled, forKey: Keys.gazeDetectionEnabled) }
    }

    public var gazeSensitivity: GazeSensitivity {
        didSet { defaults.set(gazeSensitivity.rawValue, forKey: Keys.gazeSensitivity) }
    }

    public var dwellThresholdSeconds: Double {
        didSet { defaults.set(dwellThresholdSeconds, forKey: Keys.dwellThresholdSeconds) }
    }

    public var notchStyle: NotchDeterrentStyle {
        didSet { defaults.set(notchStyle.rawValue, forKey: Keys.notchStyle) }
    }

    public var hardwareTriggers: Set<HardwareTrigger> {
        didSet {
            let raw = hardwareTriggers.map(\.rawValue)
            defaults.set(raw, forKey: Keys.hardwareTriggers)
        }
    }

    public var holdSleepOnLidClose: Bool {
        didSet { defaults.set(holdSleepOnLidClose, forKey: Keys.holdSleepOnLidClose) }
    }

    public var isSpatialMotionEnabled: Bool {
        didSet { defaults.set(isSpatialMotionEnabled, forKey: Keys.isSpatialMotionEnabled) }
    }

    public var spatialMotionSensitivity: SpatialMotionSensitivity {
        didSet { defaults.set(spatialMotionSensitivity.rawValue, forKey: Keys.spatialMotionSensitivity) }
    }

    public var blurBackgroundWhenArmed: Bool {
        didSet {
            defaults.set(blurBackgroundWhenArmed, forKey: Keys.blurBackgroundWhenArmed)
            NotificationCenter.default.post(name: .screenShieldSync, object: nil)
        }
    }

    public var blurScreenOnGaze: Bool {
        didSet {
            defaults.set(blurScreenOnGaze, forKey: Keys.blurScreenOnGaze)
            NotificationCenter.default.post(name: .screenShieldSync, object: nil)
        }
    }

    public var lockOnInputWhenArmed: Bool {
        didSet {
            defaults.set(lockOnInputWhenArmed, forKey: Keys.lockOnInputWhenArmed)
            NotificationCenter.default.post(name: .screenShieldSync, object: nil)
        }
    }

    public var allowTouchIDDisarm: Bool {
        didSet { defaults.set(allowTouchIDDisarm, forKey: Keys.allowTouchIDDisarm) }
    }

    public var hapticFeedbackEnabled: Bool {
        didSet { defaults.set(hapticFeedbackEnabled, forKey: Keys.hapticFeedbackEnabled) }
    }

    public var sirenFrequencyHz: Int {
        didSet { defaults.set(sirenFrequencyHz, forKey: Keys.sirenFrequencyHz) }
    }

    public var preferredCameraID: String? {
        didSet { defaults.set(preferredCameraID, forKey: Keys.preferredCameraID) }
    }

    public var preferredDisplayID: String? {
        didSet { defaults.set(preferredDisplayID, forKey: Keys.preferredDisplayID) }
    }

    public var relayEnabled: Bool {
        didSet { defaults.set(relayEnabled, forKey: Keys.relayEnabled) }
    }

    public var relayURL: String {
        didSet { defaults.set(relayURL, forKey: Keys.relayURL) }
    }

    public var cameraRoi: CameraROI {
        didSet {
            if let encoded = try? JSONEncoder().encode(cameraRoi) {
                defaults.set(encoded, forKey: Keys.cameraRoi)
            }
        }
    }

    public var activeCameraROI: CameraROI {
        if gazeSensitivity == .ultra {
            return CameraROI(x: 0.05, y: 0.05, width: 0.90, height: 0.90)
        }
        return cameraRoi
    }

    public static let exitDelayStops: [Int] = [5, 10, 15, 30]
    public static let gracePeriodStops: [Int] = [5, 10, 15, 30]
    public static let dwellStops: [Double] = [0.5, 1.0, 1.5, 2.0, 3.0]

    public var exitDelaySliderIndex: Double {
        get { Double(Self.exitDelayStops.firstIndex(of: exitDelaySeconds) ?? 1) }
        set {
            let idx = max(0, min(Self.exitDelayStops.count - 1, Int(newValue.rounded())))
            exitDelaySeconds = Self.exitDelayStops[idx]
        }
    }

    public var gracePeriodSliderIndex: Double {
        get { Double(Self.gracePeriodStops.firstIndex(of: gracePeriodSeconds) ?? 1) }
        set {
            let idx = max(0, min(Self.gracePeriodStops.count - 1, Int(newValue.rounded())))
            gracePeriodSeconds = Self.gracePeriodStops[idx]
        }
    }

    public var dwellSliderIndex: Double {
        get { Double(Self.dwellStops.firstIndex(of: dwellThresholdSeconds) ?? 1) }
        set {
            let idx = max(0, min(Self.dwellStops.count - 1, Int(newValue.rounded())))
            dwellThresholdSeconds = Self.dwellStops[idx]
        }
    }

    public var gazeSensitivityIndex: Double {
        get { Double(GazeSensitivity.allCases.firstIndex(of: gazeSensitivity) ?? 1) }
        set {
            let cases = GazeSensitivity.allCases
            let idx = max(0, min(cases.count - 1, Int(newValue.rounded())))
            gazeSensitivity = cases[idx]
        }
    }

    public var spatialMotionSensitivityIndex: Double {
        get { Double(SpatialMotionSensitivity.allCases.firstIndex(of: spatialMotionSensitivity) ?? 1) }
        set {
            let cases = SpatialMotionSensitivity.allCases
            let idx = max(0, min(cases.count - 1, Int(newValue.rounded())))
            spatialMotionSensitivity = cases[idx]
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.showsInMenuBar = defaults.object(forKey: Keys.showsInMenuBar) as? Bool ?? true
        self.exitDelaySeconds = defaults.object(forKey: Keys.exitDelaySeconds) as? Int ?? 10
        self.gracePeriodSeconds = defaults.object(forKey: Keys.gracePeriodSeconds) as? Int ?? 15
        self.gazeDetectionEnabled = defaults.object(forKey: Keys.gazeDetectionEnabled) as? Bool ?? true
        if let rawSens = defaults.string(forKey: Keys.gazeSensitivity),
           let sens = GazeSensitivity(rawValue: rawSens) {
            self.gazeSensitivity = sens
        } else {
            self.gazeSensitivity = .balanced
        }
        self.dwellThresholdSeconds = defaults.object(forKey: Keys.dwellThresholdSeconds) as? Double ?? 2.0
        if let rawStyle = defaults.string(forKey: Keys.notchStyle),
           let style = NotchDeterrentStyle(rawValue: rawStyle) {
            self.notchStyle = style
        } else {
            self.notchStyle = .minimalPill
        }
        if let rawTriggers = defaults.stringArray(forKey: Keys.hardwareTriggers) {
            let parsed = Set(rawTriggers.compactMap(HardwareTrigger.init(rawValue:)))
            self.hardwareTriggers = parsed.isEmpty ? Set(HardwareTrigger.allCases) : parsed
        } else {
            self.hardwareTriggers = Set(HardwareTrigger.allCases)
        }
        self.holdSleepOnLidClose = defaults.object(forKey: Keys.holdSleepOnLidClose) as? Bool ?? true
        self.isSpatialMotionEnabled = defaults.object(forKey: Keys.isSpatialMotionEnabled) as? Bool ?? true
        if let rawMotionSens = defaults.string(forKey: Keys.spatialMotionSensitivity),
           let motionSens = SpatialMotionSensitivity(rawValue: rawMotionSens) {
            self.spatialMotionSensitivity = motionSens
        } else {
            self.spatialMotionSensitivity = .medium
        }
        self.blurBackgroundWhenArmed = defaults.object(forKey: Keys.blurBackgroundWhenArmed) as? Bool ?? false
        self.blurScreenOnGaze = defaults.object(forKey: Keys.blurScreenOnGaze) as? Bool ?? true
        self.lockOnInputWhenArmed = defaults.object(forKey: Keys.lockOnInputWhenArmed) as? Bool ?? true
        self.allowTouchIDDisarm = defaults.object(forKey: Keys.allowTouchIDDisarm) as? Bool ?? true
        self.hapticFeedbackEnabled = defaults.object(forKey: Keys.hapticFeedbackEnabled) as? Bool ?? true
        self.sirenFrequencyHz = defaults.object(forKey: Keys.sirenFrequencyHz) as? Int ?? 880
        self.preferredCameraID = defaults.string(forKey: Keys.preferredCameraID)
        self.preferredDisplayID = defaults.string(forKey: Keys.preferredDisplayID)
        self.relayEnabled = defaults.object(forKey: Keys.relayEnabled) as? Bool ?? false
        self.relayURL = defaults.string(forKey: Keys.relayURL) ?? "ws://127.0.0.1:8787"
        if let roiData = defaults.data(forKey: Keys.cameraRoi),
           let decoded = try? JSONDecoder().decode(CameraROI.self, from: roiData) {
            self.cameraRoi = decoded
        } else {
            self.cameraRoi = .default
        }
    }

    public func bindMenuBarVisibility(_ handler: @escaping (Bool) -> Void) {
        self.menuBarVisibilityHandler = handler
        handler(showsInMenuBar)
    }

    private enum Keys {
        static let showsInMenuBar = "pupil.showsInMenuBar"
        static let exitDelaySeconds = "pupil.exitDelaySeconds"
        static let gracePeriodSeconds = "pupil.gracePeriodSeconds"
        static let gazeDetectionEnabled = "pupil.gazeDetectionEnabled"
        static let gazeSensitivity = "pupil.gazeSensitivity"
        static let dwellThresholdSeconds = "pupil.dwellThresholdSeconds"
        static let notchStyle = "pupil.notchStyle"
        static let hardwareTriggers = "pupil.hardwareTriggers"
        static let holdSleepOnLidClose = "pupil.holdSleepOnLidClose"
        static let isSpatialMotionEnabled = "pupil.isSpatialMotionEnabled"
        static let spatialMotionSensitivity = "pupil.spatialMotionSensitivity"
        static let blurBackgroundWhenArmed = "pupil.blurBackgroundWhenArmed"
        static let blurScreenOnGaze = "pupil.blurScreenOnGaze"
        static let lockOnInputWhenArmed = "pupil.lockOnInputWhenArmed"
        static let allowTouchIDDisarm = "pupil.allowTouchIDDisarm"
        static let hapticFeedbackEnabled = "pupil.hapticFeedbackEnabled"
        static let sirenFrequencyHz = "pupil.sirenFrequencyHz"
        static let preferredCameraID = "pupil.preferredCameraID"
        static let preferredDisplayID = "pupil.preferredDisplayID"
        static let relayEnabled = "pupil.relayEnabled"
        static let relayURL = "pupil.relayURL"
        static let cameraRoi = "pupil.cameraRoi"
    }
}
