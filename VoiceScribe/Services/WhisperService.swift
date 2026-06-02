// WhisperService.swift
// Wraps WhisperKit for local speech-to-text transcription.
// The model is downloaded once (to ~/Library/Caches/) and reused across sessions.
// Supports German and other languages via the multilingual Whisper models.

import Foundation
import WhisperKit

// MARK: - Load State

enum WhisperLoadState: Equatable {
    case idle
    case loading
    case ready
    case failed(String)
}

// MARK: - Errors

enum WhisperError: LocalizedError {
    case notLoaded
    case emptyResult

    var errorDescription: String? {
        switch self {
        case .notLoaded:    return "Whisper-Modell ist noch nicht geladen"
        case .emptyResult:  return "Transkription ergab keinen Text"
        }
    }
}

// MARK: - WhisperService

@MainActor
final class WhisperService: ObservableObject {

    @Published var loadState: WhisperLoadState = .idle

    private var whisperKit: WhisperKit?
    private var loadedModelName = ""

    // MARK: - Model Management

    /// Loads (or reloads) the Whisper model with the given name.
    /// Safe to call multiple times — skips loading if the same model is already ready.
    func loadModel(_ modelName: String) async {
        guard loadState != .ready || loadedModelName != modelName else { return }

        loadState = .loading
        loadedModelName = modelName

        do {
            // WhisperKit downloads and caches the CoreML model files automatically.
            // First run requires internet; subsequent runs are fully offline.
            whisperKit = try await WhisperKit(WhisperKitConfig(model: modelName))
            loadState = .ready
        } catch {
            loadState = .failed(error.localizedDescription)
            whisperKit = nil
        }
    }

    // MARK: - Transcription

    /// Transcribes an audio file and returns the cleaned text.
    /// - Parameters:
    ///   - audioPath: Full path to a WAV/M4A/MP3 file.
    ///   - language: ISO 639-1 language code (e.g. "de", "en"), or nil for auto-detect.
    func transcribe(audioPath: String, language: String? = nil) async throws -> String {
        guard let wk = whisperKit else {
            throw WhisperError.notLoaded
        }

        let options = DecodingOptions(
            language:          language,
            topK:              1,      // greedy decoding: ~3–5× schneller, minimal weniger akkurat
            withoutTimestamps: true    // wird ohnehin entfernt; sauberere Ausgabe
        )

        let results = try await wk.transcribe(audioPath: audioPath, decodeOptions: options)

        guard let text = results.first?.text, !text.isEmpty else {
            throw WhisperError.emptyResult
        }

        return cleanTranscription(text)
    }

    // MARK: - Private

    /// Strips Whisper timing tags like "[00:00.000 --> 00:02.000]" that
    /// WhisperKit sometimes includes in segment-level output.
    private func cleanTranscription(_ raw: String) -> String {
        let timestampPattern = #"\[\d{2}:\d{2}\.\d{3} --> \d{2}:\d{2}\.\d{3}\]\s*"#
        let text = raw.replacingOccurrences(of: timestampPattern, with: "",
                                            options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
