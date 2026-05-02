// AppSettings.swift
// Centralized app configuration. Persisted via UserDefaults.
// Also defines the global keyboard shortcut name and supporting enums.

import Foundation
import KeyboardShortcuts

// MARK: - Global Hotkey Name
// Must be defined at file scope (top-level), not inside a struct or class.
// Default shortcut: Option + Space
extension KeyboardShortcuts.Name {
    static let toggleRecording = Self(
        "toggleRecording",
        default: .init(.space, modifiers: [.option])
    )
}

// MARK: - Enums

enum RecordingMode: String, CaseIterable, Identifiable {
    case dictation = "Diktat"
    case revision  = "Überarbeiten"
    var id: String { rawValue }
}

enum WhisperModelSize: String, CaseIterable, Identifiable {
    case tiny   = "tiny"
    case base   = "base"
    case small  = "small"
    case medium = "medium"

    var displayName: String {
        switch self {
        case .tiny:   return "Tiny (~150 MB, schnellste)"
        case .base:   return "Base (~300 MB, schnell)"
        case .small:  return "Small (~500 MB, gut)"
        case .medium: return "Medium (~1.5 GB, beste Qualität)"
        }
    }

    var id: String { rawValue }
}

// MARK: - AppSettings

/// Singleton holding all user-configurable settings.
/// Persists to UserDefaults and notifies observers via Combine.
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    @Published var mode: RecordingMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Keys.mode) }
    }

    @Published var whisperModel: WhisperModelSize {
        didSet { UserDefaults.standard.set(whisperModel.rawValue, forKey: Keys.whisperModel) }
    }

    @Published var ollamaModel: String {
        didSet { UserDefaults.standard.set(ollamaModel, forKey: Keys.ollamaModel) }
    }

    /// ISO 639-1 language code for Whisper transcription.
    /// Special value "auto" lets Whisper detect the language automatically.
    @Published var language: String {
        didSet { UserDefaults.standard.set(language, forKey: Keys.language) }
    }

    private init() {
        let defaults = UserDefaults.standard
        mode = RecordingMode(rawValue: defaults.string(forKey: Keys.mode) ?? "") ?? .dictation
        whisperModel = WhisperModelSize(rawValue: defaults.string(forKey: Keys.whisperModel) ?? "") ?? .small
        // Kein Default-Modell — der Nutzer wählt in Einstellungen → Modelle.
        // Ein leerer String führt zu einer verständlichen Fehlermeldung statt Timeout.
        ollamaModel = defaults.string(forKey: Keys.ollamaModel) ?? ""
        language = defaults.string(forKey: Keys.language) ?? "de"
    }

    private enum Keys {
        static let mode         = "vs_mode"
        static let whisperModel = "vs_whisperModel"
        static let ollamaModel  = "vs_ollamaModel"
        static let language     = "vs_language"
    }
}
