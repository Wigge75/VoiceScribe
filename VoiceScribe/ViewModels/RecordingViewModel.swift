// RecordingViewModel.swift
// Central orchestrator for the recording pipeline.
// Owns all services, manages the floating panel lifecycle,
// registers the global keyboard shortcut, and drives all UI state.

import Foundation
import AVFoundation
import AppKit
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
    let hud            = HUDController()

    private var settings: AppSettings { AppSettings.shared }
    private var panelController = PanelController()
    private var audioCancellable: AnyCancellable?
    private var currentTask: Task<Void, Never>?

    private var pendingRecordingURL: URL?
    private var recordingStartTime:     Date? = nil
    private var silencePhaseStart:      Date? = nil
    private var silenceAccumulatedTime: TimeInterval = 0
    private var loudStart:              Date? = nil

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
        case .idle:              return "Bereit (⌥Space)"
        case .recording:         return "Aufnahme läuft…"
        case .transcribing:      return "Transkribiere…"
        case .revising:          return "KI überarbeitet…"
        case .done(let preview): return "Fertig: \"\(preview)\""
        case .error(let msg):    return "Fehler: \(msg)"
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

    func forceAbort() {
        silencePhaseStart = nil
        silenceAccumulatedTime = 0
        recordingStartTime = nil
        loudStart = nil
        currentTask?.cancel()
        currentTask = nil
        panelController.hide()
        state = .idle
    }

    func reloadWhisperModel() {
        Task { await whisperService.loadModel(settings.whisperModel.rawValue) }
    }

    // MARK: - Silence Detection

    private func checkSilence(_ level: AudioLevel) {
        guard case .recording = state else {
            silencePhaseStart = nil
            silenceAccumulatedTime = 0
            loudStart = nil
            return
        }
        guard settings.silenceTimeout != .off else { return }
        guard let startTime = recordingStartTime,
              Date().timeIntervalSince(startTime) >= 1.0 else { return }

        if level.averageDB < -40.0 {
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
            if let phaseStart = silencePhaseStart {
                silenceAccumulatedTime += Date().timeIntervalSince(phaseStart)
                silencePhaseStart = nil
            }
            if loudStart == nil {
                loudStart = Date()
            } else if Date().timeIntervalSince(loudStart!) >= 0.4 {
                silenceAccumulatedTime = 0
                loudStart = Date()
            }
        }
    }

    // MARK: - Recording

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

    // MARK: - Pipeline

    private func pipeline(fileURL: URL) async {
        defer {
            audioRecorder.cleanupTempFile(at: fileURL)
        }

        do {
            if let duration = await getAudioDuration(url: fileURL), duration < 0.5 {
                state = .idle
                panelController.hide()
                return
            }

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

            let capturedMode  = settings.mode
            let capturedStyle = settings.revisionStyle

            var finalText = transcribed
            var didRevise = false

            if capturedMode == .revision {
                state = .revising
                panelController.resize(to: 160)
                if #available(macOS 26, *) {
                    let result = await performRevision(of: transcribed)
                    finalText = result.revised
                    didRevise = result.didRevise
                }
            }

            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(finalText, forType: .string)

            Task {
                await HistoryService.shared.append(HistoryEntry(
                    mode:       capturedMode,
                    style:      capturedMode == .revision ? capturedStyle : nil,
                    transcript: transcribed,
                    result:     finalText
                ))
            }

            let previewBase = String(finalText.prefix(40))
            let preview = (capturedMode == .revision && !didRevise)
                ? "⚠ KI nicht verfügbar — \(previewBase)"
                : previewBase

            let delay: UInt64 = capturedMode == .dictation ? 1_000_000_000 : 1_500_000_000
            state = .done(preview: preview)
            try? await Task.sleep(nanoseconds: delay)
            panelController.hide()
            state = .idle

        } catch {
            state = .error(error.localizedDescription)
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            panelController.hide()
            if case .error = state { state = .idle }
        }
    }

    // MARK: - Revision

    @available(macOS 26, *)
    private func performRevision(of text: String) async -> (revised: String, didRevise: Bool) {
        let service = FoundationModelService()
        guard service.isAvailable() else {
            print("[VoiceScribe] Apple Intelligence nicht verfügbar: \(service.unavailabilityReason())")
            return (text, false)
        }
        do {
            let result = try await service.revise(text: text, style: settings.revisionStyle)
            return (result, true)
        } catch {
            print("[VoiceScribe] Apple Intelligence Fehler: \(error)")
            return (text, false)
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
