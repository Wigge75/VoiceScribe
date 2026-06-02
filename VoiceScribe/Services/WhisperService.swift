// WhisperService.swift
// Wraps WhisperKit for local speech-to-text transcription.
// The model is downloaded once (to ~/Library/Caches/) and reused across sessions.
// Supports German and other languages via the multilingual Whisper models.

import Foundation
import WhisperKit

// MARK: - Load State

enum WhisperLoadState: Equatable {
    case idle
    case downloading(progress: Double)   // 0.0–1.0, HuggingFace-Download
    case compiling                       // CoreML-Spezialisierung (kein Fortschritt verfügbar)
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

        loadState = .downloading(progress: 0)
        loadedModelName = modelName

        do {
            // downloadBase leitet den HuggingFace-Download in den Sandbox-eigenen
            // Caches-Ordner um. Ohne diese Angabe würde WhisperKit nach
            // ~/Documents/huggingface/ schreiben, das in der Sandbox nicht erreichbar ist.
            let downloadBase = FileManager.default
                .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let config = WhisperKitConfig(model: modelName, downloadBase: downloadBase)

            let wk = try await WhisperKit(config)

            // modelStateCallback liefert Download- und Kompilierungs-Fortschritt
            wk.modelStateCallback = { [weak self] _, newState in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch newState {
                    case .downloading:
                        let p = wk.progress.fractionCompleted
                        self.loadState = .downloading(progress: p)
                    case .downloaded, .loading, .prewarming, .prewarmed:
                        self.loadState = .compiling
                    case .loaded:
                        self.loadState = .ready
                    default:
                        break
                    }
                }
            }

            whisperKit = wk
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
