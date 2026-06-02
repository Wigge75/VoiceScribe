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
    case done(preview: String)
    case error(String)
}

// MARK: - RecordingViewModel

@MainActor
final class RecordingViewModel: ObservableObject {

    // Published state drives all UI
    @Published var state: RecordingState = .idle
    @Published var audioLevel: AudioLevel = AudioLevel(averageDB: -160, peakDB: -160)

    // Services — all created once and reused
    let audioRecorder  = AudioRecorder()
    let whisperService = WhisperService()
    let ollamaService  = OllamaService()
    let hud            = HUDController()

    private var settings: AppSettings { AppSettings.shared }
    private var panelController = PanelController()
    private var audioCancellable: AnyCancellable?
    private var currentTask: Task<Void, Never>?

    private var recordingStartTime:      Date? = nil
    private var silencePhaseStart:       Date? = nil   // Beginn der aktuellen Stille-Phase
    private var silenceAccumulatedTime:  TimeInterval = 0  // Stille über mehrere Phasen summiert
    private var loudStart:               Date? = nil

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

        KeyboardShortcuts.onKeyDown(for: .toggleMode) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let newMode: RecordingMode = AppSettings.shared.mode == .dictation ? .revision : .dictation
                AppSettings.shared.mode = newMode
                let icon = newMode == .dictation ? "mic.fill" : "doc.on.clipboard.fill"
                hud.show(icon: icon)
            }
        }

        KeyboardShortcuts.onKeyDown(for: .selectStyleBeruflich) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                AppSettings.shared.revisionStyle = .beruflich
                AppSettings.shared.mode = .revision
                hud.show(icon: RevisionStyle.beruflich.sfSymbol)
            }
        }
        KeyboardShortcuts.onKeyDown(for: .selectStyleLocker) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                AppSettings.shared.revisionStyle = .locker
                AppSettings.shared.mode = .revision
                hud.show(icon: RevisionStyle.locker.sfSymbol)
            }
        }
        KeyboardShortcuts.onKeyDown(for: .selectStyleMitEmojis) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                AppSettings.shared.revisionStyle = .mitEmojis
                AppSettings.shared.mode = .revision
                hud.show(icon: RevisionStyle.mitEmojis.sfSymbol)
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
        case .done(let preview):       return "Fertig: \"\(preview)\""
        case .error(let msg):          return "Fehler: \(msg)"
        }
    }

    var menuBarIconName: String {
        switch state {
        case .recording:               return "waveform.circle.fill"
        case .transcribing, .revising: return "ellipsis.circle"
        case .error:                   return "exclamationmark.circle"
        default:                       return "waveform.circle"
        }
    }

    func toggleRecording() {
        switch state {
        case .recording:
            stopAndProcess()
        case .idle, .done, .error:
            startRecording()
        case .transcribing, .revising:
            forceAbort()
        }
    }

    func forceAbort() { // called from panel abort button
        silencePhaseStart = nil
        silenceAccumulatedTime = 0
        recordingStartTime = nil
        loudStart = nil
        currentTask?.cancel()
        currentTask = nil
        panelController.hide()
        state = .idle
    }

    private func checkSilence(_ level: AudioLevel) {
        guard case .recording = state else { silencePhaseStart = nil; silenceAccumulatedTime = 0; loudStart = nil; return }
        guard settings.silenceTimeout != .off else { return }
        guard let startTime = recordingStartTime,
              Date().timeIntervalSince(startTime) >= 1.0 else { return }

        if level.averageDB < -40.0 {
            // Stille-Phase: akkumulierte Zeit vorantreiben
            loudStart = nil
            if silencePhaseStart == nil { silencePhaseStart = Date() }
            let total = silenceAccumulatedTime + Date().timeIntervalSince(silencePhaseStart!)
            if total >= settings.silenceTimeout.rawValue {
                silencePhaseStart = nil
                silenceAccumulatedTime = 0
                recordingStartTime = nil
                loudStart = nil
                stopAndProcess()
            }
        } else {
            // Geräusch-Phase: akkumulierte Stille einfrieren
            if let phaseStart = silencePhaseStart {
                silenceAccumulatedTime += Date().timeIntervalSince(phaseStart)
                silencePhaseStart = nil
            }
            if loudStart == nil {
                loudStart = Date()
            } else if Date().timeIntervalSince(loudStart!) >= 0.4 {
                // 0,4s anhaltende Sprache → Stille komplett zurücksetzen
                silenceAccumulatedTime = 0
                loudStart = Date()
            }
        }
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
                NSSound(named: .init("Tink"))?.play()
                panelController.show(viewModel: self)
                panelController.resize(to: 195)
                pendingRecordingURL = fileURL
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    private var pendingRecordingURL: URL?

    // MARK: - Recording Stop + Pipeline

    private func stopAndProcess() {
        silencePhaseStart = nil
        silenceAccumulatedTime = 0
        recordingStartTime = nil
        loudStart = nil
        currentTask?.cancel()
        currentTask = nil

        NSSound(named: .init("Pop"))?.play()
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
            panelController.resize(to: 160)
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

            // Schritt 2 (optional): Überarbeitung
            if settings.mode == .revision {
                state = .revising
                panelController.resize(to: 160)
                finalText = await performRevision(of: transcribed)
            }

            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(finalText, forType: .string)

            let historyMode  = settings.mode
            let historyStyle = settings.mode == .revision ? settings.revisionStyle : nil
            Task {
                await HistoryService.shared.append(HistoryEntry(
                    mode:       historyMode,
                    style:      historyStyle,
                    transcript: transcribed,
                    result:     finalText
                ))
            }

            let preview = String(finalText.prefix(40))

            // Beide Modi: Text ist bereits in der Zwischenablage.
            // Panel zeigt kurz eine Bestätigung, dann schließt es sich automatisch.
            let delay: UInt64 = settings.mode == .dictation ? 1_000_000_000 : 1_500_000_000
            state = .done(preview: preview)
            try? await Task.sleep(nanoseconds: delay)
            panelController.hide()
            state = .idle

        } catch {
            // Fehler im Panel für 3 s anzeigen, dann ausblenden
            state = .error(error.localizedDescription)
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            panelController.hide()
            if case .error = state { state = .idle }
        }
    }

    // MARK: - Revision

    // Versucht den Text zu überarbeiten. Gibt immer einen String zurück —
    // entweder den überarbeiteten Text oder das Original als Fallback.
    private func performRevision(of text: String) async -> String {
        let style = settings.revisionStyle

        // Bevorzugter Weg: Apple Intelligence (On-Device, kein Setup nötig)
        if #available(macOS 26, *) {
            let service = FoundationModelService()
            if service.isAvailable() {
                do {
                    return try await service.revise(text: text, style: style)
                } catch {
                    return text
                }
            }

            // Fallback: Ollama (wenn installiert und Modell gewählt)
            if await ollamaService.isRunning(), !settings.ollamaModel.isEmpty {
                do {
                    return try await ollamaService.revise(text: text, model: settings.ollamaModel, style: style)
                } catch {
                    return text
                }
            }

            return text
        }

        // macOS < 26: nur Ollama als Option
        guard await ollamaService.isRunning(), !settings.ollamaModel.isEmpty else {
            return text
        }
        do {
            return try await ollamaService.revise(text: text, model: settings.ollamaModel, style: style)
        } catch {
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
