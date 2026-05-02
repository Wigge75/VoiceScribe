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
    case inserting
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
    let textInserter   = TextInserter()

    private var settings: AppSettings { AppSettings.shared }
    private var panelController = PanelController()
    private var audioCancellable: AnyCancellable?
    private var currentTask: Task<Void, Never>?

    // The app that was frontmost when recording started.
    private var targetApp: NSRunningApplication?

    // AX-Element das den Cursor enthält — wird ganz am Anfang der Aufnahme gespeichert,
    // bevor das Panel erscheint. So funktioniert das Einfügen auch dann, wenn das
    // Panel während der Vorschau den Tastaturfokus übernimmt.
    private var savedFocusedElement: AXUIElement?

    // Suspension point: pipeline wartet hier bis der Nutzer Enter oder Escape drückt.
    private var insertionContinuation: CheckedContinuation<Bool, Never>?

    // MARK: - Init

    init() {
        audioCancellable = audioRecorder.$audioLevel
            .receive(on: RunLoop.main)
            .assign(to: \.audioLevel, on: self)

        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            Task { @MainActor [weak self] in
                self?.toggleRecording()
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
        case .inserting:               return "Füge Text ein…"
        case .done(let preview):       return "Fertig: \"\(preview)\""
        case .error(let msg):          return "Fehler: \(msg)"
        }
    }

    var menuBarIconName: String {
        switch state {
        case .recording:                           return "waveform.circle.fill"
        case .transcribing, .revising, .inserting: return "ellipsis.circle"
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
            // Tastenkürzel wirkt als "Abbrechen" in der Vorschau
            cancelInsertion()
        default:
            break
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
                // App UND fokussiertes AX-Element sichern, BEVOR das Panel erscheint.
                // In diesem Moment liegt der Cursor garantiert noch in der Ziel-App.
                targetApp = NSWorkspace.shared.frontmostApplication
                if let app = targetApp {
                    savedFocusedElement = textInserter.captureFocusedElement(
                        pid: app.processIdentifier
                    )
                }

                let fileURL = try audioRecorder.startRecording()
                state = .recording
                // orderFront (nicht makeKeyAndOrderFront) — Panel erscheint ohne Fokus zu stehlen
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
            savedFocusedElement = nil
            targetApp = nil
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

            // Schritt 3: Vorschau — Text im Panel zeigen, auf Bestätigung warten.
            // Das Panel wird Key-Window damit Enter/Escape empfangen werden können.
            // Die Ziel-App bleibt weiterhin die aktive App (vorderste App).
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

            // Schritt 4: Text in Zwischenablage kopieren.
            // Der Nutzer fügt ihn mit CMD+V selbst an der gewünschten Stelle ein.
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(finalText, forType: .string)

            let preview = String(finalText.prefix(40))
            state = .done(preview: preview)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            state = .idle

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

    // MARK: - Helpers

    private func getAudioDuration(url: URL) async -> Double? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return nil }
        guard duration.isValid, !duration.isIndefinite else { return nil }
        return duration.seconds
    }
}
