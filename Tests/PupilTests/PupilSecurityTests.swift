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
}
