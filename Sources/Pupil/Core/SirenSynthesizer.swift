//
//  SirenSynthesizer.swift
//  Pupil
//
//  Real-time alternating two-tone alarm synthesizer using AVAudioEngine + AVAudioSourceNode.
//  Zero external audio assets required; renders directly to the system output device.
//

import AVFoundation
import Foundation

public final class SirenSynthesizer: @unchecked Sendable {
    public static let shared = SirenSynthesizer()

    private let lock = NSLock()
    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var isSounding = false
    private var sampleIndex: UInt64 = 0
    private var baseFrequencyHz: Double = 880.0

    public init() {}

    public var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isSounding
    }

    public func start(baseFrequencyHz: Double = 880.0) {
        lock.lock()
        defer { lock.unlock() }
        self.baseFrequencyHz = baseFrequencyHz
        guard !isSounding else { return }
        isSounding = true
        sampleIndex = 0

        let audioEngine = AVAudioEngine()
        let outputFormat = audioEngine.outputNode.inputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 44100.0

        guard let monoFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return
        }

        let node = AVAudioSourceNode(format: monoFormat) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let highFreq = max(440.0, self.baseFrequencyHz)
            let lowFreq = highFreq * 0.75
            let halfSecondSamples = UInt64(sampleRate * 0.45)

            for frame in 0..<Int(frameCount) {
                let currentSample = self.sampleIndex
                self.sampleIndex &+= 1

                let useHigh = ((currentSample / max(1, halfSecondSamples)) % 2) == 0
                let freq = useHigh ? highFreq : lowFreq
                let periodSamples = max(2, UInt64(sampleRate / freq))
                let halfPeriod = max(1, periodSamples / 2)
                let sampleVal: Float = ((currentSample / halfPeriod) % 2 == 0) ? 0.65 : -0.65

                for buffer in ablPointer {
                    if let data = buffer.mData?.assumingMemoryBound(to: Float.self) {
                        data[frame] = sampleVal
                    }
                }
            }
            return noErr
        }

        audioEngine.attach(node)
        audioEngine.connect(node, to: audioEngine.mainMixerNode, format: monoFormat)
        audioEngine.mainMixerNode.outputVolume = 1.0

        do {
            try audioEngine.start()
            self.engine = audioEngine
            self.sourceNode = node
        } catch {
            self.isSounding = false
        }
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard isSounding else { return }
        isSounding = false
        engine?.stop()
        if let node = sourceNode {
            engine?.detach(node)
        }
        sourceNode = nil
        engine = nil
    }

    /// Plays a brief 1.2s test chirp so the user can verify speaker output from Settings.
    public func playTestChirp(baseFrequencyHz: Double = 880.0) {
        start(baseFrequencyHz: baseFrequencyHz)
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.stop()
        }
    }
}
