//
//  VisionMotionDetector.swift
//  Pupil
//
//  Zero-dependency Apple Vision Spatial Lift & Motion Detector ("Lift & Walk" Trigger).
//  Closes the "Unplugged Open-Lid Grab & Walk" blindspot when armed on battery power.
//  Processes frames strictly in memory; zero images or crops are written to disk.
//

import Accelerate
import CoreGraphics
import Foundation
import Vision
import simd

public struct MotionSample: Sendable, Equatable {
    public let timestamp: TimeInterval
    /// Normalized global background translation magnitude ||Δt|| (fraction of frame width).
    public let translationMagnitude: Float
    /// Frobenius deviation ||H - I||_F of upper-background homography warp.
    public let homographyWarpMagnitude: Float
    /// Full-frame mean luminance in [0, 1].
    public let meanLuminance: Float
    /// Full-frame luminance variance in [0, 1].
    public let luminanceVariance: Float
    /// Optional metric depth anchor Z_0 in meters from inter-pupillary distance.
    public let metricDepthZ0: Float?
    /// Whether this frame was captured as the initial Frame 0 anchor.
    public let isAnchorFrame: Bool

    public init(
        timestamp: TimeInterval,
        translationMagnitude: Float,
        homographyWarpMagnitude: Float = 0,
        meanLuminance: Float = 0.45,
        luminanceVariance: Float = 0.04,
        metricDepthZ0: Float? = nil,
        isAnchorFrame: Bool = false
    ) {
        self.timestamp = timestamp
        self.translationMagnitude = translationMagnitude
        self.homographyWarpMagnitude = homographyWarpMagnitude
        self.meanLuminance = meanLuminance
        self.luminanceVariance = luminanceVariance
        self.metricDepthZ0 = metricDepthZ0
        self.isAnchorFrame = isAnchorFrame
    }

    public var isFrameOccluded: Bool {
        meanLuminance < 0.035 && luminanceVariance < 0.0008
    }

    public static func anchor(at timestamp: TimeInterval, metricDepthZ0: Float? = nil) -> MotionSample {
        MotionSample(
            timestamp: timestamp,
            translationMagnitude: 0,
            homographyWarpMagnitude: 0,
            meanLuminance: 0.45,
            luminanceVariance: 0.04,
            metricDepthZ0: metricDepthZ0,
            isAnchorFrame: true
        )
    }
}

public struct MotionEscalationSnapshot: Sendable, Equatable {
    public let isTamperTriggered: Bool
    public let isSustainedLiftDetected: Bool
    public let isSustainedOcclusionDetected: Bool
    public let isTransientBumpSuppressed: Bool
    public let continuousDisplacementSeconds: Double
    public let continuousOcclusionSeconds: Double
    public let effectiveDisplacementScore: Float
    public let anchorDepthMeters: Float?
    public let hasCapturedAnchor: Bool
}

/// Deterministic temporal aggregator for spatial lift & webcam occlusion detection.
/// Suppresses transient < 0.5s table-bump spikes and triggers tamper escalation only when
/// background displacement or lens occlusion persists continuously for > 1.2s.
public struct MotionTemporalAggregator: Sendable {
    public static let tableBumpSuppressionSeconds: Double = 0.5
    public static let sustainedEscalationSeconds: Double = 1.2

    public private(set) var hasCapturedAnchor: Bool = false
    public private(set) var anchorTimestamp: TimeInterval?
    public private(set) var anchorDepthMeters: Float?
    private var continuousMotionStart: TimeInterval?
    private var continuousOcclusionStart: TimeInterval?

    public init() {}

    public mutating func reset() {
        hasCapturedAnchor = false
        anchorTimestamp = nil
        anchorDepthMeters = nil
        continuousMotionStart = nil
        continuousOcclusionStart = nil
    }

    public mutating func ingest(
        _ sample: MotionSample,
        sensitivity: SpatialMotionSensitivity = .medium,
        tableBumpDeadbandSeconds: Double = Self.tableBumpSuppressionSeconds,
        sustainedThresholdSeconds: Double = Self.sustainedEscalationSeconds
    ) -> MotionEscalationSnapshot {
        // Capture Frame 0 anchor when first sample arrives after arming/reset
        if !hasCapturedAnchor || sample.isAnchorFrame {
            hasCapturedAnchor = true
            anchorTimestamp = sample.timestamp
            if let z0 = sample.metricDepthZ0 {
                anchorDepthMeters = z0
            }
            continuousMotionStart = nil
            continuousOcclusionStart = sample.isFrameOccluded ? sample.timestamp : nil

            return MotionEscalationSnapshot(
                isTamperTriggered: false,
                isSustainedLiftDetected: false,
                isSustainedOcclusionDetected: false,
                isTransientBumpSuppressed: false,
                continuousDisplacementSeconds: 0,
                continuousOcclusionSeconds: 0,
                effectiveDisplacementScore: 0,
                anchorDepthMeters: anchorDepthMeters,
                hasCapturedAnchor: true
            )
        }

        if anchorDepthMeters == nil, let z0 = sample.metricDepthZ0 {
            anchorDepthMeters = z0
        }

        // Scale translation by metric depth Z_0 relative to nominal 0.60m desk distance when available
        let depthScale: Float
        if let z0 = anchorDepthMeters {
            depthScale = max(0.75, min(1.50, z0 / 0.60))
        } else {
            depthScale = 1.0
        }

        let scaledTranslation = sample.translationMagnitude * depthScale
        let translationRatio = scaledTranslation / max(0.001, sensitivity.translationDeadband)
        let warpRatio = sample.homographyWarpMagnitude / max(0.001, sensitivity.warpDeadband)
        let effectiveScore = max(translationRatio, warpRatio)
        let exceedsDeadband = effectiveScore >= 1.0

        if exceedsDeadband {
            if continuousMotionStart == nil {
                continuousMotionStart = sample.timestamp
            }
        } else {
            continuousMotionStart = nil
        }

        if sample.isFrameOccluded {
            if continuousOcclusionStart == nil {
                continuousOcclusionStart = sample.timestamp
            }
        } else {
            continuousOcclusionStart = nil
        }

        let elapsedMotion: Double
        if let start = continuousMotionStart {
            elapsedMotion = max(0, sample.timestamp - start)
        } else {
            elapsedMotion = 0
        }

        let elapsedOcclusion: Double
        if let start = continuousOcclusionStart {
            elapsedOcclusion = max(0, sample.timestamp - start)
        } else {
            elapsedOcclusion = 0
        }

        // Transient motion spikes lasting < 0.5s (e.g., desk bumps) are suppressed
        let isBumpSuppressed = elapsedMotion > 0 && elapsedMotion < tableBumpDeadbandSeconds
        // Sustained displacement or occlusion continuously for > 1.2s triggers tamper escalation
        let liftTriggered = elapsedMotion > sustainedThresholdSeconds
        let occlusionTriggered = elapsedOcclusion > sustainedThresholdSeconds

        return MotionEscalationSnapshot(
            isTamperTriggered: liftTriggered || occlusionTriggered,
            isSustainedLiftDetected: liftTriggered,
            isSustainedOcclusionDetected: occlusionTriggered,
            isTransientBumpSuppressed: isBumpSuppressed,
            continuousDisplacementSeconds: elapsedMotion,
            continuousOcclusionSeconds: elapsedOcclusion,
            effectiveDisplacementScore: effectiveScore,
            anchorDepthMeters: anchorDepthMeters,
            hasCapturedAnchor: hasCapturedAnchor
        )
    }
}

/// On-device Apple Vision upper-background registration & occlusion analyzer.
/// Evaluates `VNTrackTranslationalImageRegistrationRequest` and `VNTrackHomographyImageRegistrationRequest`
/// on the face-masked top 25% ROI against the armed anchor frame.
public final class VisionMotionDetector: @unchecked Sendable {
    private let lock = NSLock()
    private var anchorUpperBackgroundImage: CGImage?
    private var anchorMetricDepthZ0: Float?

    public init() {}

    public var hasAnchorFrame: Bool {
        lock.lock()
        defer { lock.unlock() }
        return anchorUpperBackgroundImage != nil
    }

    public var currentAnchorDepthZ0: Float? {
        lock.lock()
        defer { lock.unlock() }
        return anchorMetricDepthZ0
    }

    public func resetAnchor() {
        lock.lock()
        anchorUpperBackgroundImage = nil
        anchorMetricDepthZ0 = nil
        lock.unlock()
    }

    /// Evaluates a camera frame against the armed Frame 0 anchor using Apple Vision image registration
    /// on the face-masked upper 25% background ROI, plus full-frame luminance/variance occlusion checks.
    public func analyzeFrame(
        _ image: CGImage,
        faceBoundingBoxes: [CGRect] = [],
        metricDepthZ0: Float? = nil,
        timestamp: TimeInterval = Date().timeIntervalSince1970
    ) -> MotionSample {
        let (meanLuma, lumaVariance) = Self.computeFrameLuminanceStats(image)
        guard let upperROIImage = Self.makeFaceMaskedUpperBackgroundCrop(
            from: image,
            faceBoundingBoxes: faceBoundingBoxes
        ) else {
            return MotionSample(
                timestamp: timestamp,
                translationMagnitude: 0,
                homographyWarpMagnitude: 0,
                meanLuminance: meanLuma,
                luminanceVariance: lumaVariance,
                metricDepthZ0: metricDepthZ0,
                isAnchorFrame: false
            )
        }

        lock.lock()
        let existingAnchor = anchorUpperBackgroundImage
        if existingAnchor == nil {
            anchorUpperBackgroundImage = upperROIImage
            anchorMetricDepthZ0 = metricDepthZ0
            lock.unlock()
            return MotionSample(
                timestamp: timestamp,
                translationMagnitude: 0,
                homographyWarpMagnitude: 0,
                meanLuminance: meanLuma,
                luminanceVariance: lumaVariance,
                metricDepthZ0: metricDepthZ0,
                isAnchorFrame: true
            )
        }
        if anchorMetricDepthZ0 == nil, let z0 = metricDepthZ0 {
            anchorMetricDepthZ0 = z0
        }
        let anchorZ0 = anchorMetricDepthZ0
        lock.unlock()

        guard let anchorImage = existingAnchor else {
            return .anchor(at: timestamp, metricDepthZ0: anchorZ0)
        }

        let (translationMag, warpMag) = Self.computeRegistrationDisplacement(
            anchorImage: anchorImage,
            currentImage: upperROIImage
        )

        return MotionSample(
            timestamp: timestamp,
            translationMagnitude: translationMag,
            homographyWarpMagnitude: warpMag,
            meanLuminance: meanLuma,
            luminanceVariance: lumaVariance,
            metricDepthZ0: anchorZ0,
            isAnchorFrame: false
        )
    }

    /// Crops the static upper-background ROI (top 25% of the frame, viewing ceiling/upper walls)
    /// and masks out any expanded `VNFaceObservation` bounding boxes.
    public static func makeFaceMaskedUpperBackgroundCrop(
        from image: CGImage,
        faceBoundingBoxes: [CGRect]
    ) -> CGImage? {
        let fullW = image.width
        let fullH = image.height
        guard fullW >= 8, fullH >= 8 else { return nil }

        let roiH = max(4, Int(Double(fullH) * 0.25))
        let topCropRect = CGRect(x: 0, y: 0, width: fullW, height: roiH)
        guard let cropped = image.cropping(to: topCropRect) else { return nil }

        // If no faces overlap the top 25% band (in Vision bottom-left coords, y >= 0.75), return crop directly
        let expandedBoxes = faceBoundingBoxes.map { box -> CGRect in
            let expandX = box.width * 0.25
            let expandY = box.height * 0.25
            return box.insetBy(dx: -expandX, dy: -expandY)
        }
        let overlapsUpperBand = expandedBoxes.contains { $0.maxY > 0.75 }
        guard overlapsUpperBand else { return cropped }

        // Render crop into transient in-memory bitmap context and mask overlapping face boxes
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: fullW,
            height: roiH,
            bitsPerComponent: 8,
            bytesPerRow: fullW * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return cropped
        }

        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: fullW, height: roiH))
        ctx.setFillColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)

        for box in expandedBoxes where box.maxY > 0.75 {
            let minX = max(0.0, box.minX) * CGFloat(fullW)
            let maxX = min(1.0, box.maxX) * CGFloat(fullW)
            // Vision y in [0.75, 1.0] maps to crop y in [0, roiH]
            let overlapMinY = max(0.75, box.minY)
            let overlapMaxY = min(1.0, box.maxY)
            let cropMinY = ((overlapMinY - 0.75) / 0.25) * CGFloat(roiH)
            let cropMaxY = ((overlapMaxY - 0.75) / 0.25) * CGFloat(roiH)
            let maskRect = CGRect(
                x: minX,
                y: cropMinY,
                width: max(0, maxX - minX),
                height: max(0, cropMaxY - cropMinY)
            )
            ctx.fill(maskRect)
        }

        return ctx.makeImage() ?? cropped
    }

    /// Runs `VNTranslationalImageRegistrationRequest` and `VNHomographyImageRegistrationRequest`
    /// between the armed anchor crop and the current upper-background crop.
    public static func computeRegistrationDisplacement(
        anchorImage: CGImage,
        currentImage: CGImage
    ) -> (translationMagnitude: Float, warpMagnitude: Float) {
        let translationRequest = VNTranslationalImageRegistrationRequest(
            targetedCGImage: anchorImage,
            options: [:]
        )
        let homographyRequest = VNHomographicImageRegistrationRequest(
            targetedCGImage: anchorImage,
            options: [:]
        )

        let handler = VNImageRequestHandler(cgImage: currentImage, options: [:])
        do {
            try handler.perform([translationRequest, homographyRequest])
        } catch {
            return (0, 0)
        }

        var translationMag: Float = 0
        if let transObs = translationRequest.results?.first as? VNImageTranslationAlignmentObservation {
            let transform = transObs.alignmentTransform
            let dx = Float(transform.tx) / Float(max(1, currentImage.width))
            let dy = Float(transform.ty) / Float(max(1, currentImage.height))
            translationMag = sqrtf(dx * dx + dy * dy)
        }

        var warpMag: Float = 0
        if let homoObs = homographyRequest.results?.first as? VNImageHomographicAlignmentObservation {
            let H = homoObs.warpTransform
            let scale = H[2][2]
            if abs(scale) > 1e-5 {
                let n = H * (1.0 / scale)
                let identity = matrix_identity_float3x3
                let diff = n - identity
                // Frobenius norm of normalized homography deviation
                var sumSq: Float = 0
                for c in 0..<3 {
                    for r in 0..<3 {
                        let v = diff[c][r]
                        // Normalize translation column entries by image dimension if unnormalized
                        let adjusted: Float
                        if c == 2 && r < 2 {
                            let dim = Float(r == 0 ? max(1, currentImage.width) : max(1, currentImage.height))
                            adjusted = abs(v) > 2.0 ? (v / dim) : v
                        } else {
                            adjusted = v
                        }
                        sumSq += adjusted * adjusted
                    }
                }
                warpMag = sqrtf(sumSq)
            }
        }

        return (translationMag, warpMag)
    }

    /// Downsamples the frame in memory to a 32x24 grid and computes Rec. 709 mean luminance and variance
    /// across 100% of the frame for webcam occlusion detection.
    public static func computeFrameLuminanceStats(_ image: CGImage) -> (mean: Float, variance: Float) {
        let sampleW = 32
        let sampleH = 24
        let count = sampleW * sampleH
        var rawBytes = [UInt8](repeating: 0, count: count * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let ctx = CGContext(
            data: &rawBytes,
            width: sampleW,
            height: sampleH,
            bitsPerComponent: 8,
            bytesPerRow: sampleW * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return (0.5, 0.05)
        }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: sampleW, height: sampleH))

        var lumaValues = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let offset = i * 4
            let r = Float(rawBytes[offset]) / 255.0
            let g = Float(rawBytes[offset + 1]) / 255.0
            let b = Float(rawBytes[offset + 2]) / 255.0
            lumaValues[i] = 0.2126 * r + 0.7152 * g + 0.0722 * b
        }

        var mean: Float = 0
        vDSP_meanv(lumaValues, 1, &mean, vDSP_Length(count))

        var meanSq: Float = 0
        vDSP_measqv(lumaValues, 1, &meanSq, vDSP_Length(count))
        let variance = max(0, meanSq - mean * mean)

        return (mean, variance)
    }
}
