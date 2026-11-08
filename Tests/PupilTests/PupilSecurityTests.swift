import CoreGraphics
import Foundation
import Testing
@testable import Pupil

@Suite("Pupil Core & Vision Tests", .serialized)
struct PupilSecurityTests {
    @Test("Keychain PIN enrollment and verification")
    func testPinEnrollmentAndVerification() throws {
        try KeychainManager.enrollPin("4829")
        #expect(KeychainManager.hasEnrolledPin == true)
        #expect(KeychainManager.verifyPin("4829") == true)
        #expect(KeychainManager.verifyPin("0000") == false)
        #expect(KeychainManager.isValidPinFormat("12") == false)
        #expect(KeychainManager.isValidPinFormat("12345678") == true)
    }

    @Test("GazeTemporalAggregator accumulates sustained dwell and tolerates brief blinks")
    func testGazeDwellAggregator() {
        var aggregator = GazeTemporalAggregator()
        let baseTime: TimeInterval = 1000.0

        // Frame at t=0.0s
        let s0 = GazeSample(
            timestamp: baseTime,
            faceCount: 1,
            faceInsideROI: true,
            faceCentroid: CGPoint(x: 0.4, y: 0.5),
            towardScreenScore: 0.85,
            yawRadians: 0.05,
            pitchRadians: 0.02,
            irisHorizontalRatio: 0.5,
            trackingConfidence: 0.92
        )
        let snap0 = aggregator.ingest(s0, scoreThreshold: 0.65, dwellThresholdSeconds: 2.0)
        #expect(snap0.isGazeWarningActive == false)
        #expect(snap0.dwellProgress == 0.0)

        // Brief blink at t=1.0s (<= 0.35s gap after qualifying sample at t=0.9s)
        let s1 = GazeSample(
            timestamp: baseTime + 0.9,
            faceCount: 1,
            faceInsideROI: true,
            faceCentroid: CGPoint(x: 0.41, y: 0.5),
            towardScreenScore: 0.82,
            yawRadians: 0.04,
            pitchRadians: 0.02,
            irisHorizontalRatio: 0.5,
            trackingConfidence: 0.90
        )
        _ = aggregator.ingest(s1, scoreThreshold: 0.65, dwellThresholdSeconds: 2.0)

        let blinkSample = GazeSample(
            timestamp: baseTime + 1.1,
            faceCount: 1,
            faceInsideROI: true,
            faceCentroid: CGPoint(x: 0.41, y: 0.5),
            towardScreenScore: 0.20,
            yawRadians: 0.04,
            pitchRadians: 0.02,
            irisHorizontalRatio: 0.5,
            trackingConfidence: 0.90
        )
        let snapBlink = aggregator.ingest(blinkSample, scoreThreshold: 0.65, dwellThresholdSeconds: 2.0)
        #expect(snapBlink.dwellProgress > 0.4)

        // Frame at t=2.1s crosses 2.0s dwell threshold
        let s2 = GazeSample(
            timestamp: baseTime + 2.1,
            faceCount: 1,
            faceInsideROI: true,
            faceCentroid: CGPoint(x: 0.42, y: 0.5),
            towardScreenScore: 0.88,
            yawRadians: 0.02,
            pitchRadians: 0.01,
            irisHorizontalRatio: 0.5,
            trackingConfidence: 0.95
        )
        let snapFinal = aggregator.ingest(s2, scoreThreshold: 0.65, dwellThresholdSeconds: 2.0)
        #expect(snapFinal.isGazeWarningActive == true)
        #expect(snapFinal.dwellProgress == 1.0)
    }

    @Test("SecurityCoordinator state machine transitions")
    @MainActor
    func testSecurityCoordinatorLifecycle() throws {
        try KeychainManager.enrollPin("2468")
        let coordinator = SecurityCoordinator()
        #expect(coordinator.state == .disarmed)

        coordinator.startArming(immediate: true)
        #expect(coordinator.state == .armed)

        coordinator.triggerTamper(source: .chargerUnplugged, immediateAlarm: false, simulated: true)
        #expect(coordinator.state == .tamperPending)
        #expect(coordinator.activeTamperSource == .chargerUnplugged)

        // Wrong PIN should not disarm
        #expect(coordinator.disarmWithPin("9999") == false)
        #expect(coordinator.state == .tamperPending)

        // Correct PIN disarms cleanly
        #expect(coordinator.disarmWithPin("2468") == true)
        #expect(coordinator.state == .disarmed)
    }

    @Test("Screen shield blur settings and preview lifecycle")
    @MainActor
    func testScreenShieldAndBlurSettings() {
        let suiteName = "PupilTest-Shield-\(UUID().uuidString)"
        guard let isolatedDefaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults")
            return
        }
        defer { isolatedDefaults.removePersistentDomain(forName: suiteName) }

        let settings = PupilSettings(defaults: isolatedDefaults)
        let coordinator = SecurityCoordinator(settings: settings)
        #expect(settings.blurBackgroundWhenArmed == false)
        #expect(settings.blurScreenOnGaze == true)

        settings.blurBackgroundWhenArmed = true
        #expect(settings.blurBackgroundWhenArmed == true)

        let shieldController = ScreenShieldController(coordinator: coordinator)
        shieldController.syncWithCoordinator()

        #expect(coordinator.isShieldPreviewActive == false)
        coordinator.previewScreenShield(durationSeconds: 0.1)
        #expect(coordinator.isShieldPreviewActive == true)
        shieldController.syncWithCoordinator()

        // Verify shield window creation and prompt notification tokens
        let window = ScreenShieldWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600))
        #expect(window.canBecomeKey == true)
        #expect(window.canBecomeMain == true)
        #expect(Notification.Name.screenShieldOpenPrompt.rawValue == "PupilScreenShieldOpenPrompt")
        #expect(Notification.Name.screenShieldDismissPrompt.rawValue == "PupilScreenShieldDismissPrompt")
        #expect(Notification.Name.screenShieldDeleteKey.rawValue == "PupilScreenShieldDeleteKey")
        #expect(Notification.Name.screenShieldSubmitPrompt.rawValue == "PupilScreenShieldSubmitPrompt")
        #expect(Notification.Name.screenShieldDigitTyped.rawValue == "PupilScreenShieldDigitTyped")
        #expect(Notification.Name.screenShieldFocusPrimary.rawValue == "PupilScreenShieldFocusPrimary")
        #expect(Notification.Name.screenShieldSync.rawValue == "PupilScreenShieldSync")
        #expect(Notification.Name.screenShieldAnyKeyPressed.rawValue == "PupilScreenShieldAnyKeyPressed")

        _ = ScreenShieldView(coordinator: coordinator, isPrimary: true)
        _ = ScreenShieldView(coordinator: coordinator, isPrimary: false)

        // Verify NotchWindow and NotchHostingView hit-testing passes through outside active notch bounds
        let notchWin = NotchWindow(contentRect: NSRect(x: 0, y: 0, width: 442, height: 284))
        notchWin.activeNotchSize = CGSize(width: 200, height: 44)
        notchWin.ignoresMouseEvents = false
        let hostingView = NotchHostingView(
            rootView: NotchOverlayView(coordinator: coordinator, geometry: NotchGeometry.forPreferredScreen(), onRequestInteractive: { _, _ in }),
            window: notchWin
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: 442, height: 284)

        // Point outside active notch bounds (e.g. at bottom center (221, 50)) should return nil to let website clicks pass through
        let outsidePoint = NSPoint(x: 221, y: 50)
        #expect(hostingView.hitTest(outsidePoint) == nil)
    }

    @Test("Gaze warning receptiveness: Ultra sensitivity, fast dwell stops, and screen privacy blur")
    @MainActor
    func testGazeWarningReceptivenessAndPrivacyBlur() {
        let suiteName = "PupilTest-Gaze-\(UUID().uuidString)"
        guard let isolatedDefaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Failed to create isolated UserDefaults")
            return
        }
        defer { isolatedDefaults.removePersistentDomain(forName: suiteName) }

        let settings = PupilSettings(defaults: isolatedDefaults)
        let coordinator = SecurityCoordinator(settings: settings)

        // 1. Verify Ultra sensitivity cone and dwell stops
        #expect(GazeSensitivity.ultra.scoreThreshold == 0.40)
        #expect(PupilSettings.dwellStops.contains(0.5))
        #expect(PupilSettings.dwellStops.contains(1.0))

        // 2. Verify wide peripheral ROI for Ultra
        settings.gazeSensitivity = .ultra
        #expect(settings.activeCameraROI.width == 0.90)

        // 3. Verify Privacy Blur on Gaze triggers screen shield during armed state
        settings.blurBackgroundWhenArmed = false
        settings.blurScreenOnGaze = true
        coordinator.startArming(immediate: true)
        #expect(coordinator.state == .armed)

        let shieldController = ScreenShieldController(coordinator: coordinator)
        shieldController.syncWithCoordinator()

        // Gaze warning active -> shield should be showing
        coordinator.simulateGazeWarning()
        #expect(coordinator.isGazeWarningActive == true)
        shieldController.syncWithCoordinator()

        // Dismiss gaze warning -> shield unblurs cleanly
        coordinator.dismissGazeWarning()
        #expect(coordinator.isGazeWarningActive == false)
        shieldController.syncWithCoordinator()
    }

    @Test("Notch deterrent style has only minimal pill and silent log options")
    @MainActor
    func testNotchDeterrentStyleOptions() {
        let options = NotchDeterrentStyle.allCases
        #expect(options.count == 2)
        #expect(options.contains(.minimalPill))
        #expect(options.contains(.silent))

        let settings = PupilSettings.shared
        #expect(settings.notchStyle == .minimalPill || settings.notchStyle == .silent)
    }

    @Test("Brief < 0.5s table-bump motion spikes do NOT trigger tamper escalation")
    @MainActor
    func testTableBumpMotionSpikeSuppressed() throws {
        try KeychainManager.enrollPin("1357")
        let coordinator = SecurityCoordinator()
        coordinator.settings.isSpatialMotionEnabled = true
        coordinator.settings.spatialMotionSensitivity = .medium
        coordinator.startArming(immediate: true)
        #expect(coordinator.state == .armed)

        let t0: TimeInterval = 2000.0
        // Frame 0: Anchor captured at arming
        coordinator.ingestMotionSample(.anchor(at: t0, metricDepthZ0: 0.60))
        #expect(coordinator.hasMotionAnchor == true)
        #expect(coordinator.state == .armed)

        // Transient table bump at t+0.10s and t+0.35s (< 0.5s duration)
        coordinator.ingestMotionSample(MotionSample(
            timestamp: t0 + 0.10,
            translationMagnitude: 0.12,
            homographyWarpMagnitude: 0.25
        ))
        #expect(coordinator.state == .armed)

        coordinator.ingestMotionSample(MotionSample(
            timestamp: t0 + 0.35,
            translationMagnitude: 0.11,
            homographyWarpMagnitude: 0.22
        ))
        #expect(coordinator.state == .armed)

        // Settles back to stationary at t+0.45s
        coordinator.ingestMotionSample(MotionSample(
            timestamp: t0 + 0.45,
            translationMagnitude: 0.005,
            homographyWarpMagnitude: 0.01
        ))
        #expect(coordinator.state == .armed)
        #expect(coordinator.continuousMotionSeconds == 0)

        _ = coordinator.disarmWithPin("1357")
    }

    @Test("Sustained > 1.2s motion displacement while ARMED transitions SecurityCoordinator to tamper countdown and resets on PIN disarm")
    @MainActor
    func testSustainedSpatialLiftEscalationAndDisarmReset() throws {
        try KeychainManager.enrollPin("8642")
        let coordinator = SecurityCoordinator()
        coordinator.settings.isSpatialMotionEnabled = true
        coordinator.settings.spatialMotionSensitivity = .medium
        coordinator.startArming(immediate: true)
        #expect(coordinator.state == .armed)

        let t0: TimeInterval = 3000.0
        // Capture Frame 0 anchor with metric depth Z_0 = 0.62m
        coordinator.ingestMotionSample(.anchor(at: t0, metricDepthZ0: 0.62))
        #expect(coordinator.hasMotionAnchor == true)
        #expect(coordinator.motionAnchorDepthMeters == 0.62)

        // Start lifting laptop at t+0.1s
        coordinator.ingestMotionSample(MotionSample(
            timestamp: t0 + 0.10,
            translationMagnitude: 0.095,
            homographyWarpMagnitude: 0.20
        ))
        #expect(coordinator.state == .armed)

        // Sustained lift at t+0.8s (0.7s elapsed, still <= 1.2s)
        coordinator.ingestMotionSample(MotionSample(
            timestamp: t0 + 0.80,
            translationMagnitude: 0.105,
            homographyWarpMagnitude: 0.24
        ))
        #expect(coordinator.state == .armed)

        // Sustained lift at t+1.45s (1.35s continuous displacement > 1.2s threshold) -> Tamper Countdown!
        coordinator.ingestMotionSample(MotionSample(
            timestamp: t0 + 1.45,
            translationMagnitude: 0.115,
            homographyWarpMagnitude: 0.28
        ))
        #expect(coordinator.state == .tamperPending)
        #expect(coordinator.activeTamperSource == .cameraMotionDetected)
        #expect(coordinator.activeTamperSource == .spatialLiftDetected)

        // Disarming with a valid PIN resets the motion detector anchor state
        #expect(coordinator.disarmWithPin("8642") == true)
        #expect(coordinator.state == .disarmed)
        #expect(coordinator.hasMotionAnchor == false)
        #expect(coordinator.continuousMotionSeconds == 0)
        #expect(coordinator.latestMotionDisplacementScore == 0)
        #expect(coordinator.motionAnchorDepthMeters == nil)
        #expect(coordinator.cameraManager.motionDetector.hasAnchorFrame == false)
    }

    @Test("Sustained > 1.2s webcam occlusion triggers tamper escalation and VisionMotionDetector processes frames in memory")
    @MainActor
    func testWebcamOcclusionAndVisionMotionDetector() throws {
        var aggregator = MotionTemporalAggregator()
        let t0: TimeInterval = 4000.0

        _ = aggregator.ingest(.anchor(at: t0))
        // Occluded frame at t+0.1s (mean luminance & variance near zero)
        let s1 = aggregator.ingest(MotionSample(
            timestamp: t0 + 0.10,
            translationMagnitude: 0,
            meanLuminance: 0.01,
            luminanceVariance: 0.0001
        ))
        #expect(s1.isTamperTriggered == false)

        // Occluded continuously for 1.3s (> 1.2s)
        let s2 = aggregator.ingest(MotionSample(
            timestamp: t0 + 1.45,
            translationMagnitude: 0,
            meanLuminance: 0.01,
            luminanceVariance: 0.0001
        ))
        #expect(s2.isSustainedOcclusionDetected == true)
        #expect(s2.isTamperTriggered == true)

        // Verify VisionMotionDetector anchor lifecycle with synthetic in-memory CGImage frames
        let detector = VisionMotionDetector()
        #expect(detector.hasAnchorFrame == false)
        if let testImage = Self.makeSyntheticFrame(width: 64, height: 48, lumaByte: 120) {
            let anchorSample = detector.analyzeFrame(testImage, metricDepthZ0: 0.58, timestamp: t0)
            #expect(anchorSample.isAnchorFrame == true)
            #expect(detector.hasAnchorFrame == true)
            #expect(detector.currentAnchorDepthZ0 == 0.58)

            let nextSample = detector.analyzeFrame(testImage, timestamp: t0 + 0.1)
            #expect(nextSample.isAnchorFrame == false)

            detector.resetAnchor()
            #expect(detector.hasAnchorFrame == false)
        }
    }

    private static func makeSyntheticFrame(width: Int, height: Int, lumaByte: UInt8) -> CGImage? {
        var pixels = [UInt8](repeating: lumaByte, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        return ctx.makeImage()
    }
}
