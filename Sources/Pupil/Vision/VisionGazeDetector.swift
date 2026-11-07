//
//  VisionGazeDetector.swift
//  Pupil
//
//  On-device Apple Vision iris & head-pose gaze estimator + temporal dwell aggregator.
//  Processes frames strictly in memory on the Apple Neural Engine (ANE); zero images are saved.
//

import CoreGraphics
import Foundation
import Vision

public struct GazeSample: Sendable, Equatable {
    public let timestamp: TimeInterval
    public let faceCount: Int
    public let faceInsideROI: Bool
    public let faceCentroid: CGPoint?
    public let towardScreenScore: Float
    public let yawRadians: Float
    public let pitchRadians: Float
    public let irisHorizontalRatio: Float
    public let trackingConfidence: Float
    public let faceBoundingBoxes: [CGRect]
    public let estimatedMetricDepthMeters: Float?

    public init(
        timestamp: TimeInterval,
        faceCount: Int,
        faceInsideROI: Bool,
        faceCentroid: CGPoint?,
        towardScreenScore: Float,
        yawRadians: Float,
        pitchRadians: Float,
        irisHorizontalRatio: Float,
        trackingConfidence: Float,
        faceBoundingBoxes: [CGRect] = [],
        estimatedMetricDepthMeters: Float? = nil
    ) {
        self.timestamp = timestamp
        self.faceCount = faceCount
        self.faceInsideROI = faceInsideROI
        self.faceCentroid = faceCentroid
        self.towardScreenScore = towardScreenScore
        self.yawRadians = yawRadians
        self.pitchRadians = pitchRadians
        self.irisHorizontalRatio = irisHorizontalRatio
        self.trackingConfidence = trackingConfidence
        self.faceBoundingBoxes = faceBoundingBoxes
        self.estimatedMetricDepthMeters = estimatedMetricDepthMeters
    }

    public static func empty(at timestamp: TimeInterval = Date().timeIntervalSince1970) -> GazeSample {
        GazeSample(
            timestamp: timestamp,
            faceCount: 0,
            faceInsideROI: false,
            faceCentroid: nil,
            towardScreenScore: 0,
            yawRadians: 0,
            pitchRadians: 0,
            irisHorizontalRatio: 0.5,
            trackingConfidence: 0,
            faceBoundingBoxes: [],
            estimatedMetricDepthMeters: nil
        )
    }
}

public struct GazeDwellSnapshot: Sendable, Equatable {
    public let isGazeWarningActive: Bool
    public let dwellProgress: Double
    public let elapsedDwellSeconds: Double
    public let latestScore: Float
    public let eyeLookOffset: CGPoint
    public let activeFaceCount: Int
}

/// Pure, synchronous temporal aggregator so it can be unit-tested deterministically.
public struct GazeTemporalAggregator: Sendable {
    private var samples: [GazeSample] = []
    private var activeTrackCentroid: CGPoint?
    private var continuousDwellStart: TimeInterval?

    public init() {}

    public mutating func reset() {
        samples.removeAll()
        activeTrackCentroid = nil
        continuousDwellStart = nil
    }

    public mutating func ingest(
        _ sample: GazeSample,
        scoreThreshold: Float = 0.65,
        dwellThresholdSeconds: Double = 2.0
    ) -> GazeDwellSnapshot {
        let windowSeconds: Double = max(2.5, dwellThresholdSeconds + 0.5)
        let cutoff = sample.timestamp - windowSeconds
        samples.removeAll { $0.timestamp < cutoff }

        // Reset transient track if face moved more than 0.18 normalized L2 distance
        if let newCenter = sample.faceCentroid, let prevCenter = activeTrackCentroid {
            let dx = newCenter.x - prevCenter.x
            let dy = newCenter.y - prevCenter.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist > 0.18 {
                samples.removeAll()
                continuousDwellStart = nil
            }
            activeTrackCentroid = newCenter
        } else if let newCenter = sample.faceCentroid {
            activeTrackCentroid = newCenter
        } else {
            activeTrackCentroid = nil
        }

        samples.append(sample)

        let qualifies = sample.faceInsideROI &&
            sample.trackingConfidence >= 0.55 &&
            sample.towardScreenScore >= scoreThreshold

        if qualifies {
            if continuousDwellStart == nil {
                continuousDwellStart = sample.timestamp
            }
        } else {
            // Tolerate brief blinks (<= 0.35s) before resetting continuous dwell
            if let lastQualifying = samples.last(where: {
                $0.faceInsideROI && $0.trackingConfidence >= 0.55 && $0.towardScreenScore >= scoreThreshold
            }) {
                if (sample.timestamp - lastQualifying.timestamp) > 0.35 {
                    continuousDwellStart = nil
                }
            } else {
                continuousDwellStart = nil
            }
        }

        let elapsedDwell: Double
        if let start = continuousDwellStart {
            elapsedDwell = max(0, sample.timestamp - start)
        } else {
            elapsedDwell = 0
        }

        let progress = min(1.0, elapsedDwell / max(0.5, dwellThresholdSeconds))
        let warningActive = elapsedDwell >= dwellThresholdSeconds

        let lookOffset: CGPoint
        if let center = sample.faceCentroid {
            // Mirror X so the animated eye looks toward the person in front of the screen
            let nx = max(-1.0, min(1.0, (0.5 - center.x) * 2.2))
            let ny = max(-1.0, min(1.0, (0.5 - center.y) * 2.0))
            lookOffset = CGPoint(x: nx, y: ny)
        } else {
            lookOffset = .zero
        }

        return GazeDwellSnapshot(
            isGazeWarningActive: warningActive,
            dwellProgress: progress,
            elapsedDwellSeconds: elapsedDwell,
            latestScore: sample.towardScreenScore,
            eyeLookOffset: lookOffset,
            activeFaceCount: sample.faceCount
        )
    }
}

nonisolated public enum VisionGazeDetector {
    /// Evaluates a single `CGImage` camera frame using Apple's native Vision framework.
    public static func analyzeFrame(
        _ image: CGImage,
        roi: CameraROI,
        timestamp: TimeInterval = Date().timeIntervalSince1970
    ) throws -> GazeSample {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        let rectRequest = VNDetectFaceRectanglesRequest()
        try handler.perform([rectRequest])

        guard let faceObservations = rectRequest.results, !faceObservations.isEmpty else {
            return .empty(at: timestamp)
        }

        let landmarksRequest = VNDetectFaceLandmarksRequest()
        landmarksRequest.inputFaceObservations = faceObservations
        try handler.perform([landmarksRequest])

        let landmarkObservations = landmarksRequest.results ?? []
        let imageSize = CGSize(width: image.width, height: image.height)
        let allBoundingBoxes = faceObservations.map(\.boundingBox)

        // Score all detected faces inside ROI and pick the strongest candidate
        var bestSample: GazeSample?

        for (index, obs) in faceObservations.enumerated() {
            let box = obs.boundingBox
            // Vision origin is bottom-left; convert centroid to top-left normalized coordinates
            let center = CGPoint(
                x: box.midX,
                y: 1.0 - box.midY
            )
            let insideROI = roi.contains(normalizedPoint: center)
            let yaw = obs.yaw?.floatValue ?? 0
            let pitch = obs.pitch?.floatValue ?? 0

            let landmarks = landmarkObservations.indices.contains(index) ? landmarkObservations[index].landmarks : nil
            let irisRatio = computeHorizontalIrisRatio(landmarks: landmarks)
            let depthZ0 = estimateMetricDepthMeters(landmarks: landmarks, imageSize: imageSize)

            // Compute composite toward-screen gaze score from head pose + iris centering
            let yawPenalty = min(1.0, abs(yaw) / 0.65)
            let pitchPenalty = min(1.0, abs(pitch) / 0.55)
            let irisDeviation = abs(irisRatio - 0.5) * 2.0 // 0 = dead center, 1 = extreme corner
            let irisPenalty = min(1.0, irisDeviation / 0.45)

            let rawScore = 1.0 - (0.48 * yawPenalty + 0.24 * pitchPenalty + 0.28 * irisPenalty)
            let score = max(0.0, min(1.0, rawScore))

            let candidate = GazeSample(
                timestamp: timestamp,
                faceCount: faceObservations.count,
                faceInsideROI: insideROI,
                faceCentroid: center,
                towardScreenScore: insideROI ? score : 0,
                yawRadians: yaw,
                pitchRadians: pitch,
                irisHorizontalRatio: irisRatio,
                trackingConfidence: obs.confidence,
                faceBoundingBoxes: allBoundingBoxes,
                estimatedMetricDepthMeters: depthZ0
            )

            if let currentBest = bestSample {
                if candidate.towardScreenScore > currentBest.towardScreenScore {
                    bestSample = candidate
                }
            } else {
                bestSample = candidate
            }
        }

        return bestSample ?? .empty(at: timestamp)
    }

    private static func computeHorizontalIrisRatio(landmarks: VNFaceLandmarks2D?) -> Float {
        guard let landmarks else { return 0.5 }

        func ratioForEye(eye: VNFaceLandmarkRegion2D?, pupil: VNFaceLandmarkRegion2D?) -> Float? {
            guard let eyePoints = eye?.normalizedPoints, eyePoints.count >= 4,
                  let pupilPoint = pupil?.normalizedPoints.first else {
                return nil
            }
            let xs = eyePoints.map { Float($0.x) }
            guard let minX = xs.min(), let maxX = xs.max(), (maxX - minX) > 0.001 else {
                return nil
            }
            let r = (Float(pupilPoint.x) - minX) / (maxX - minX)
            return max(0.0, min(1.0, r))
        }

        let leftR = ratioForEye(eye: landmarks.leftEye, pupil: landmarks.leftPupil)
        let rightR = ratioForEye(eye: landmarks.rightEye, pupil: landmarks.rightPupil)

        switch (leftR, rightR) {
        case let (l?, r?): return (l + r) * 0.5
        case let (l?, nil): return l
        case let (nil, r?): return r
        case (nil, nil): return 0.5
        }
    }

    /// Computes initial metric depth anchor Z_0 = (f_px * 0.063) / d_px using inter-pupillary pixel distance
    /// (human average IPD ≈ 0.063 m).
    public static func estimateMetricDepthMeters(
        landmarks: VNFaceLandmarks2D?,
        imageSize: CGSize,
        nominalFocalLengthAt640Px: Float = 560.0
    ) -> Float? {
        guard let landmarks,
              let leftPupil = landmarks.leftPupil,
              let rightPupil = landmarks.rightPupil else {
            return nil
        }
        let leftPts = leftPupil.pointsInImage(imageSize: imageSize)
        let rightPts = rightPupil.pointsInImage(imageSize: imageSize)
        guard let pL = leftPts.first, let pR = rightPts.first else {
            return nil
        }
        let dx = Float(pR.x - pL.x)
        let dy = Float(pR.y - pL.y)
        let dPx = sqrt(dx * dx + dy * dy)
        guard dPx > 4.0 else { return nil }

        let scale = Float(max(1.0, imageSize.width) / 640.0)
        let fPx = nominalFocalLengthAt640Px * scale
        let ipdMeters: Float = 0.063
        let z0 = (fPx * ipdMeters) / dPx
        return max(0.15, min(3.5, z0))
    }
}
