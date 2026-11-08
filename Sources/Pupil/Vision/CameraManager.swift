//
//  CameraManager.swift
//  Pupil
//
//  AVFoundation camera capture & device enumeration, running at a battery-efficient 10 FPS
//  for real-time Vision gaze analysis. Never writes frames to disk.
//

@preconcurrency import AVFoundation
import CoreGraphics
@preconcurrency import CoreImage
import Foundation
import Observation

public struct CameraDeviceInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let isBuiltIn: Bool
}

@MainActor
@Observable
public final class CameraManager: NSObject {
    public private(set) var availableCameras: [CameraDeviceInfo] = []
    public private(set) var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    public private(set) var isRunning: Bool = false
    public private(set) var lastFrameImage: CGImage?

    public var onGazeSample: ((GazeSample) -> Void)?
    public var onMotionSample: ((MotionSample) -> Void)?

    @ObservationIgnored private nonisolated(unsafe) let captureSession = AVCaptureSession()
    @ObservationIgnored private let sessionQueue = DispatchQueue(label: "com.pupil.camera.session", qos: .userInitiated)
    @ObservationIgnored private nonisolated let videoOutputQueue = DispatchQueue(label: "com.pupil.camera.output", qos: .userInitiated)
    @ObservationIgnored private nonisolated(unsafe) let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    @ObservationIgnored private nonisolated(unsafe) var lastProcessedTime: TimeInterval = 0
    @ObservationIgnored private nonisolated(unsafe) var activeROI: CameraROI = .default
    @ObservationIgnored public nonisolated let motionDetector = VisionMotionDetector()

    public override init() {
        super.init()
        refreshCameras()
    }

    public func updateActiveROI(_ roi: CameraROI) {
        activeROI = roi
    }

    public var captureSessionReference: AVCaptureSession {
        captureSession
    }

    nonisolated private static let supportedDeviceTypes: [AVCaptureDevice.DeviceType] = [
        .builtInWideAngleCamera,
        .continuityCamera,
        .external
    ]

    public func refreshCameras() {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: Self.supportedDeviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        availableCameras = discovery.devices.map { device in
            CameraDeviceInfo(
                id: device.uniqueID,
                name: device.localizedName,
                isBuiltIn: device.deviceType == .builtInWideAngleCamera
            )
        }
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    public func requestCameraAccess() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized {
            authorizationStatus = .authorized
            return true
        }
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        return granted
    }

    public func startCapture(preferredDeviceID: String? = nil) {
        guard !isRunning else { return }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            Task {
                let granted = await requestCameraAccess()
                if granted {
                    self.startCapture(preferredDeviceID: preferredDeviceID)
                }
            }
            return
        }
        guard status == .authorized else { return }

        let targetID = preferredDeviceID ?? PupilSettings.shared.preferredCameraID
        isRunning = true

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureAndStartSession(preferredID: targetID)
        }
    }

    public nonisolated func resetMotionAnchor() {
        motionDetector.resetAnchor()
    }

    public func stopCapture() {
        guard isRunning else { return }
        isRunning = false
        lastFrameImage = nil
        motionDetector.resetAnchor()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }

    private nonisolated func configureAndStartSession(preferredID: String?) {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .vga640x480

        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }
        for output in captureSession.outputs {
            captureSession.removeOutput(output)
        }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: Self.supportedDeviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        let device = discovery.devices.first(where: { $0.uniqueID == preferredID })
            ?? discovery.devices.first(where: { $0.deviceType == .builtInWideAngleCamera })
            ?? discovery.devices.first

        if let device, let input = try? AVCaptureDeviceInput(device: device), captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        output.setSampleBufferDelegate(self, queue: videoOutputQueue)
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }

        captureSession.commitConfiguration()
        captureSession.startRunning()
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = Date().timeIntervalSince1970
        // Throttle Vision inference to ~10 FPS to keep CPU and battery footprint minimal
        guard (now - lastProcessedTime) >= 0.10 else { return }
        lastProcessedTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            return
        }

        let sample = (try? VisionGazeDetector.analyzeFrame(cgImage, roi: activeROI, timestamp: now)) ?? .empty(at: now)
        let motionSample = motionDetector.analyzeFrame(
            cgImage,
            faceBoundingBoxes: sample.faceBoundingBoxes,
            metricDepthZ0: sample.estimatedMetricDepthMeters,
            timestamp: now
        )

        Task { @MainActor [weak self] in
            guard let self, self.isRunning else { return }
            self.lastFrameImage = cgImage
            self.onGazeSample?(sample)
            self.onMotionSample?(motionSample)
        }
    }
}
