// AudioRecorder.swift
// Records audio to a temporary WAV file at 16 kHz mono.
// 16 kHz mono matches Whisper's native input rate and minimises file size.
// Exposes real-time audio level for the waveform animation.

import AVFoundation
import Foundation

/// Normalised audio level, usable directly as a 0–1 Float for the waveform view.
struct AudioLevel {
    let averageDB: Float   // raw dB value, typically -160…0
    let peakDB:    Float

    /// Normalised 0.0–1.0 using a -60 dB floor.
    var normalised: Float {
        max(0, min(1, (averageDB + 60) / 60))
    }
}

@MainActor
final class AudioRecorder: ObservableObject {

    @Published var audioLevel: AudioLevel = AudioLevel(averageDB: -160, peakDB: -160)
    @Published var isRecording = false

    private var recorder:    AVAudioRecorder?
    private var meterTimer:  Timer?
    private var tempFileURL: URL?

    // MARK: - Permissions

    /// Requests microphone access. Returns true if granted.
    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    // MARK: - Recording

    /// Starts recording. Returns the URL of the temp WAV file being written to.
    /// Throws if the recorder cannot be initialised (e.g. mic permission denied).
    func startRecording() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voicescribe_\(UUID().uuidString).wav")
        tempFileURL = url

        // 16 kHz mono 16-bit PCM — ideal for Whisper, small file size
        let settings: [String: Any] = [
            AVFormatIDKey:             kAudioFormatLinearPCM,
            AVSampleRateKey:           16_000.0,
            AVNumberOfChannelsKey:     1,
            AVLinearPCMBitDepthKey:    16,
            AVLinearPCMIsFloatKey:     false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey:  AVAudioQuality.high.rawValue
        ]

        let rec = try AVAudioRecorder(url: url, settings: settings)
        rec.isMeteringEnabled = true
        rec.record()
        recorder = rec
        isRecording = true

        // Poll the meter ~30 times per second for smooth waveform animation
        meterTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateMeters() }
        }

        return url
    }

    /// Stops recording and returns the path to the completed WAV file, or nil on failure.
    func stopRecording() -> URL? {
        meterTimer?.invalidate()
        meterTimer = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        audioLevel = AudioLevel(averageDB: -160, peakDB: -160)
        return tempFileURL
    }

    /// Deletes the temporary recording file after processing is complete.
    func cleanupTempFile(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Private

    private func updateMeters() {
        guard let rec = recorder, rec.isRecording else { return }
        rec.updateMeters()
        audioLevel = AudioLevel(
            averageDB: rec.averagePower(forChannel: 0),
            peakDB:    rec.peakPower(forChannel: 0)
        )
    }
}
