// RecordingViewModel.swift
// Central orchestrator for the recording pipeline.
// Owns all services, manages the floating panel lifecycle,
// registers the global keyboard shortcut, and drives all UI state.

import Foundation
import AVFoundation
import AppKit
import ApplicationServices
import Combine
import KeyboardShortcuts

// MARK: - Recording State

enum RecordingState {
    case idle
    case recording
    case transcribing
    case revising
    case preview(text: String)     // Text bereit — Panel ist Key-Window, wartet auf Enter
    case done(preview: String)
    case error(String)
}

// MARK: - Revision Warning

enum RevisionWarning {
    case notAvailable(String)
    case failed(String)

    var message: String {
        switch self {
        case .notAvailable(let reason): return "Überarbeitung nicht möglich: \(reason)"
        case .failed(let reason):       return "Überarbeitung fehlgeschlagen — Originaltext kopiert. (\(reason))"
        }
    }
}

// MARK: - RecordingViewModel

@MainActor
final class RecordingViewModel: ObservableObject {

    // Published state drives all UI
    @Published var state: RecordingState = .idle
    @Published var audioLevel: AudioLevel = AudioLevel(averageDB: -160, peakDB: -160)
    // Wird im Preview-Panel als gelber Hinweis angezeigt, wenn die Überarbeitung fehlschlug.
    @Published var revisionWarning: RevisionWarning?

    // Services — all created once and reused
    let audioRecorder  = AudioRecorder()
    let whisperService = WhisperService()
    let ollamaService  = OllamaService()

    private var settings: AppSettings { AppSettings.shared }
    private var panelController = PanelController()
    private var audioCancellable: AnyCancellable?
    private var currentTask: Task<Void, Never>?

    // Suspension point: pipeline wartet hier bis der Nutzer Enter oder Escape drückt.
    private var insertionContinuation: CheckedContinuation<Bool, Never>?

    private var silenceStart:       Date? = nil
    private var recordingStartTime: Date? = nil
    private var loudStart:          Date? = nil

    // MARK: - Init

    init() {
        audioCancellable = audioRecorder.$audioLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                guard let self else { return }
                self.audioLevel = level
                self.checkSilence(level)
            }

        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            Task { @MainActor [weak self] in
                self?.toggleRecording()
            }
        }

        KeyboardShortcuts.onKeyDown(for: .selectStyleBeruflich) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                AppSettings.shared.revisionStyle = .beruflich
                AppSettings.shared.mode = .revision
            }
        }
        KeyboardShortcuts.onKeyDown(for: .selectStyleLocker) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                AppSettings.shared.revisionStyle = .locker
                AppSettings.shared.mode = .revision
            }
        }
        KeyboardShortcuts.onKeyDown(for: .selectStyleMitEmojis) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                AppSettings.shared.revisionStyle = .mitEmojis
                AppSettings.shared.mode = .revision
            }
        }

        Task {
            await whisperService.loadModel(settings.whisperModel.rawValue)
        }
    }

    // MARK: - Public Interface

    var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    var statusSummary: String {
        switch state {
        case .idle:                    return "Bereit (⌥Space)"
        case .recording:               return "Aufnahme läuft…"
        case .transcribing:            return "Transkribiere…"
        case .revising:                return "KI überarbeitet…"
        case .preview:                 return "Bereit zum Einfügen"
        case .done(let preview):       return "Fertig: \"\(preview)\""
        case .error(let msg):          return "Fehler: \(msg)"
        }
    }

    var menuBarIconName: String {
        switch state {
        case .recording:                           return "waveform.circle.fill"
        case .transcribing, .revising: return "ellipsis.circle"
        case .preview:                             return "checkmark.circle"
        case .error:                               return "exclamationmark.circle"
        default:                                   return "waveform.circle"
        }
    }

    func toggleRecording() {
        switch state {
        case .recording:
            stopAndProcess()
        case .idle, .done, .error:
            startRecording()
        case .preview:
            cancelInsertion()
        case .transcribing, .revising:
            forceAbort()
        default:
            break
        }
    }

    func forceAbort() { // called from panel abort button
        silenceStart = nil
        recordingStartTime = nil
        loudStart = nil
        currentTask?.cancel()
        currentTask = nil
        panelController.hide()
        state = .idle
    }

    private func checkSilence(_ level: AudioLevel) {
        guard case .recording = state else { silenceStart = nil; loudStart = nil; return }
        guard settings.silenceTimeout != .off else { return }
        guard let startTime = recordingStartTime,
              Date().timeIntervalSince(startTime) >= 1.0 else { return }

        if level.averageDB < -40.0 {
            // Silent frame: reset loud tracker, advance silence timer
            loudStart = nil
            if silenceStart == nil {
                silenceStart = Date()
            } else if Date().timeIntervalSince(silenceStart!) >= settings.silenceTimeout.rawValue {
                silenceStart = nil
                recordingStartTime = nil
                loudStart = nil
                stopAndProcess()
            }
        } else {
            // Loud frame: only reset silence timer after 0.4s of sustained noise
            if loudStart == nil {
                loudStart = Date()
            } else if Date().timeIntervalSince(loudStart!) >= 0.4 {
                silenceStart = nil
            }
        }
    }

    // MARK: - Preview Confirmation

    /// Wird vom "Einfügen"-Button (oder Enter-Taste) aufgerufen.
    func confirmInsertion() {
        insertionContinuation?.resume(returning: true)
        insertionContinuation = nil
    }

    /// Wird vom "Verwerfen"-Button, Escape oder dem Tastenkürzel aufgerufen.
    func cancelInsertion() {
        insertionContinuation?.resume(returning: false)
        insertionContinuation = nil
    }

    func reloadWhisperModel() {
        Task { await whisperService.loadModel(settings.whisperModel.rawValue) }
    }

    // MARK: - Recording Start

    private func startRecording() {
        currentTask = Task {
            let granted = await audioRecorder.requestPermission()
            guard granted else {
                state = .error("Kein Mikrofon-Zugriff")
                return
            }

            do {
                let fileURL = try audioRecorder.startRecording()
                state = .recording
                recordingStartTime = Date()
                panelController.show(viewModel: self)
                pendingRecordingURL = fileURL
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    private var pendingRecordingURL: URL?

    // MARK: - Recording Stop + Pipeline

    private func stopAndProcess() {
        silenceStart = nil
        recordingStartTime = nil
        loudStart = nil
        currentTask?.cancel()
        currentTask = nil

        let fileURL = audioRecorder.stopRecording() ?? pendingRecordingURL
        pendingRecordingURL = nil

        guard let url = fileURL else {
            state = .error("Aufnahme fehlgeschlagen")
            panelController.hide()
            return
        }

        currentTask = Task {
            await pipeline(fileURL: url)
        }
    }

    private func pipeline(fileURL: URL) async {
        defer {
            audioRecorder.cleanupTempFile(at: fileURL)
        }

        do {
            // Guard: sehr kurze Aufnahmen überspringen (Whisper halluziniert bei Stille)
            if let duration = await getAudioDuration(url: fileURL), duration < 0.5 {
                state = .idle
                panelController.hide()
                return
            }

            // Schritt 1: Transkription
            state = .transcribing
            let language = settings.language == "auto" ? nil : settings.language
            let transcribed = try await whisperService.transcribe(
                audioPath: fileURL.path,
                language:  language
            )

            guard !transcribed.isEmpty else {
                state = .idle
                panelController.hide()
                return
            }

            var finalText = transcribed
            revisionWarning = nil

            // Schritt 2 (optional): Überarbeitung
            if settings.mode == .revision {
                state = .revising
                finalText = await performRevision(of: transcribed)
            }

            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(finalText, forType: .string)

            let preview = String(finalText.prefix(40))

            if settings.mode == .dictation {
                // Diktat: Auto-Bestätigung — Text ist bereits in der Zwischenablage.
                // Panel zeigt 1 Sek. lang eine Bestätigung, dann schließt es sich automatisch.
                state = .done(preview: preview)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                panelController.hide()
                state = .idle
            } else {
                // Überarbeitung: Vorschau anzeigen, auf Bestätigung warten.
                state = .preview(text: finalText)
                panelController.makeKey(
                    onConfirm: { [weak self] in
                        Task { @MainActor [weak self] in self?.confirmInsertion() }
                    },
                    onCancel: { [weak self] in
                        Task { @MainActor [weak self] in self?.cancelInsertion() }
                    }
                )

                let confirmed = await waitForConfirmation()
                panelController.hide()

                guard confirmed else {
                    state = .idle
                    return
                }

                state = .done(preview: preview)
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                state = .idle
            }

        } catch {
            // Fehler im Panel für 3 s anzeigen, dann ausblenden
            state = .error(error.localizedDescription)
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            panelController.hide()
            if case .error = state { state = .idle }
        }
    }

    /// Pausiert die Pipeline bis der Nutzer im Vorschau-Panel bestätigt oder abbricht.
    private func waitForConfirmation() async -> Bool {
        await withCheckedContinuation { continuation in
            self.insertionContinuation = continuation
        }
    }

    // MARK: - Revision

    // Versucht den Text zu überarbeiten. Gibt immer einen String zurück —
    // entweder den überarbeiteten Text oder das Original als Fallback.
    // Fehlermeldungen werden über revisionWarning an das Panel weitergegeben.
    private func performRevision(of text: String) async -> String {
        let style = settings.revisionStyle

        // Bevorzugter Weg: Apple Intelligence (On-Device, kein Setup nötig)
        if #available(macOS 26, *) {
            let service = FoundationModelService()
            if service.isAvailable() {
                do {
                    return try await service.revise(text: text, style: style)
                } catch {
                    revisionWarning = .failed(error.localizedDescription)
                    return text
                }
            }
            // Apple Intelligence nicht verfügbar — Grund festhalten, dann Ollama versuchen
            let reason = service.unavailabilityReason()

            // Fallback: Ollama (wenn installiert und Modell gewählt)
            if await ollamaService.isRunning(), !settings.ollamaModel.isEmpty {
                do {
                    return try await ollamaService.revise(text: text, model: settings.ollamaModel, style: style)
                } catch {
                    revisionWarning = .failed(error.localizedDescription)
                    return text
                }
            }

            revisionWarning = .notAvailable(reason)
            return text
        }

        // macOS < 26: nur Ollama als Option
        guard await ollamaService.isRunning() else {
            revisionWarning = .notAvailable("Ollama läuft nicht (Terminal: ollama serve)")
            return text
        }
        guard !settings.ollamaModel.isEmpty else {
            revisionWarning = .notAvailable("Kein Ollama-Modell gewählt — Einstellungen → Modelle")
            return text
        }
        do {
            return try await ollamaService.revise(text: text, model: settings.ollamaModel, style: style)
        } catch {
            revisionWarning = .failed(error.localizedDescription)
            return text
        }
    }

    // MARK: - Style Examples

    func saveAsStyleExample() {
        guard case .preview(let text) = state,
              text.count >= AppSettings.styleExampleMinCharacters else { return }

        let example = StyleExample(
            style: settings.revisionStyle,
            revisedText: text
        )
        settings.styleExamples.append(example)
    }

    // MARK: - Helpers

    private func getAudioDuration(url: URL) async -> Double? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return nil }
        guard duration.isValid, !duration.isIndefinite else { return nil }
        return duration.seconds
    }
}
