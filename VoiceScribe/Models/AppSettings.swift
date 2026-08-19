// AppSettings.swift
// Centralized app configuration. Persisted via UserDefaults.
// Also defines the global keyboard shortcut name and supporting enums.

import Foundation
import KeyboardShortcuts

// MARK: - Global Hotkey Name
// Must be defined at file scope (top-level), not inside a struct or class.
// Default shortcut: Option + Space
extension KeyboardShortcuts.Name {
    static let toggleRecording      = Self("toggleRecording",      default: .init(.space, modifiers: [.option]))
    static let toggleMode           = Self("toggleMode",           default: .init(.zero,  modifiers: [.option]))
    static let selectStyleBeruflich = Self("selectStyleBeruflich", default: .init(.one,   modifiers: [.option]))
    static let selectStyleLocker    = Self("selectStyleLocker",    default: .init(.two,   modifiers: [.option]))
    static let selectStyleMitEmojis = Self("selectStyleMitEmojis", default: .init(.three, modifiers: [.option]))
}

// MARK: - Enums

enum RecordingMode: String, CaseIterable, Identifiable, Codable {
    case dictation = "Diktat"
    case revision  = "Überarbeiten"
    var id: String { rawValue }
}

enum RevisionStyle: String, CaseIterable, Identifiable, Codable {
    case beruflich = "beruflich"
    case locker    = "locker"
    case mitEmojis = "mitEmojis"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beruflich: return "Beruflich"
        case .locker:    return "Locker"
        case .mitEmojis: return "Mit Emojis"
        }
    }

}

enum WhisperModelSize: String, CaseIterable, Identifiable {
    case fast     = "tiny"
    case balanced = "small_216MB"
    case best     = "large-v3-v20240930_turbo_632MB"

    var displayName: String {
        switch self {
        case .fast:     return "Schnell (~150 MB)"
        case .balanced: return "Ausgewogen (~216 MB)"
        case .best:     return "Beste Qualität (~632 MB)"
        }
    }

    var id: String { rawValue }
}

// MARK: - AppSettings

/// Singleton holding all user-configurable settings.
/// Persists to UserDefaults and notifies observers via Combine.
final class AppSettings: ObservableObject {

    static let appVersion = "2.1.1"

    static let shared = AppSettings()

    @Published var mode: RecordingMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Keys.mode) }
    }

    @Published var whisperModel: WhisperModelSize {
        didSet { UserDefaults.standard.set(whisperModel.rawValue, forKey: Keys.whisperModel) }
    }

    /// ISO 639-1 language code for Whisper transcription.
    /// Special value "auto" lets Whisper detect the language automatically.
    @Published var language: String {
        didSet { UserDefaults.standard.set(language, forKey: Keys.language) }
    }

    @Published var revisionStyle: RevisionStyle {
        didSet { UserDefaults.standard.set(revisionStyle.rawValue, forKey: Keys.revisionStyle) }
    }

    @Published var autoPaste: Bool {
        didSet { UserDefaults.standard.set(autoPaste, forKey: Keys.autoPaste) }
    }

    @Published var promptBeruflich: String {
        didSet {
            guard !promptBeruflich.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                promptBeruflich = oldValue
                return
            }
            UserDefaults.standard.set(promptBeruflich, forKey: Keys.promptBeruflich)
        }
    }

    @Published var promptLocker: String {
        didSet {
            guard !promptLocker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                promptLocker = oldValue
                return
            }
            UserDefaults.standard.set(promptLocker, forKey: Keys.promptLocker)
        }
    }

    @Published var promptMitEmojis: String {
        didSet {
            guard !promptMitEmojis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                promptMitEmojis = oldValue
                return
            }
            UserDefaults.standard.set(promptMitEmojis, forKey: Keys.promptMitEmojis)
        }
    }

    func prompt(for style: RevisionStyle) -> String {
        switch style {
        case .beruflich: return promptBeruflich
        case .locker:    return promptLocker
        case .mitEmojis: return promptMitEmojis
        }
    }

    func setPrompt(_ text: String, for style: RevisionStyle) {
        switch style {
        case .beruflich: promptBeruflich = text
        case .locker:    promptLocker = text
        case .mitEmojis: promptMitEmojis = text
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        mode = RecordingMode(rawValue: defaults.string(forKey: Keys.mode) ?? "") ?? .dictation
        whisperModel = WhisperModelSize(rawValue: defaults.string(forKey: Keys.whisperModel) ?? "") ?? .balanced
        language = defaults.string(forKey: Keys.language) ?? "de"
        revisionStyle = RevisionStyle(rawValue: defaults.string(forKey: Keys.revisionStyle) ?? "") ?? .beruflich
        autoPaste = defaults.bool(forKey: Keys.autoPaste)
        promptBeruflich = defaults.string(forKey: Keys.promptBeruflich) ?? """
            Du bist ein Transkriptions-Korrektor für professionelles Schriftdeutsch. Deine Aufgabe ist aktive Überarbeitung — nicht minimale Korrektur.

            DEINE AUFGABEN (alle Punkte sind Pflicht):
            1. Füllwörter entfernen: öh, ähm, halt, also (als Füllwort), ja (als Füllwort), genau (als Übergangsformel ohne inhaltliche Bedeutung), mal (als Füllwort)
            2. Satzstruktur glätten: Abbrüche und Neuansätze auflösen, holprige oder unfertige Sätze komplett umformulieren
            3. Grammatik korrigieren: Kommasetzung, Großschreibung, fehlende Artikel, falsche Flexion
            4. Gedankenkorrekturen: Wenn der Sprecher abbricht und neu ansetzt, nur die finale Version behalten
            5. Unstrukturierte Gedanken ordnen: Wenn ein Gedanke klar ist aber chaotisch formuliert, forme ihn in einen klaren, lesbaren Satz um

            NUR DIESES EINE VERBOT — Inhaltswörter sind tabu:
            Ersetze NIEMALS ein Inhaltswort durch ein anderes — auch nicht durch ein sinnverwandtes.
            Verboten: "gucken" → "schauen", "was" → "etwas", "erkennen" → "herausfinden", "macht" → "gestaltet" ❌
            Erlaubt: Wörter weglassen (Füllwörter), Wörter umstellen, Sätze komplett neu bauen ✓

            Füge KEINE Begrüßungen oder Verabschiedungen hinzu, außer sie wurden explizit diktiert.
            Antworte IMMER auf Deutsch.
            Antworte NUR mit dem korrigierten Text, ohne Erklärungen oder Anmerkungen.
            """
        promptLocker = defaults.string(forKey: Keys.promptLocker) ?? """
            Du bist ein Transkriptions-Korrektor für gesprochenes Deutsch. Deine Aufgabe ist aktive Überarbeitung — nicht minimale Korrektur.

            DEINE AUFGABEN (alle Punkte sind Pflicht):
            1. Füllwörter entfernen: öh, ähm, halt, also (als Füllwort), ja (als Füllwort), genau (als Übergangsformel ohne inhaltliche Bedeutung), ne, oder?, mal (als Füllwort)
            2. Satzstruktur glätten: Abbrüche und Neuansätze auflösen, holprige oder unfertige Sätze komplett umformulieren
            3. Grammatik korrigieren: Kommasetzung, Großschreibung, fehlende Artikel, falsche Flexion
            4. Gedankenkorrekturen: Wenn der Sprecher abbricht und neu ansetzt ("warte", "also eigentlich", "nein"), nur die finale Version behalten
            5. Unstrukturierte Gedanken ordnen: Wenn ein Gedanke klar ist aber chaotisch formuliert, forme ihn in einen lesbaren Satz um — behalte dabei den informellen Ton

            NUR DIESES EINE VERBOT — Inhaltswörter sind tabu:
            Ersetze NIEMALS ein Inhaltswort durch ein anderes — auch nicht durch ein sinnverwandtes.
            Verboten: "gucken" → "schauen", "was" → "etwas", "erkennen" → "herausfinden" ❌
            Erlaubt: Wörter weglassen (Füllwörter), Wörter umstellen, Sätze komplett neu bauen ✓

            Behalte den informellen Ton des Sprechers.
            Antworte IMMER auf Deutsch.
            Antworte NUR mit dem korrigierten Text, ohne Erklärungen.
            """
        promptMitEmojis = defaults.string(forKey: Keys.promptMitEmojis) ?? """
            Du bist ein Transkriptions-Korrektor für gesprochenes Deutsch mit Emojis. Deine Aufgabe ist aktive Überarbeitung — nicht minimale Korrektur.

            DEINE AUFGABEN (alle Punkte sind Pflicht):
            1. Füllwörter entfernen: öh, ähm, halt, also (als Füllwort), ja (als Füllwort), genau (als Übergangsformel ohne inhaltliche Bedeutung), ne, oder?, mal (als Füllwort)
            2. Satzstruktur glätten: Abbrüche und Neuansätze auflösen, holprige oder unfertige Sätze komplett umformulieren
            3. Grammatik korrigieren: Kommasetzung, Großschreibung, fehlende Artikel, falsche Flexion
            4. Gedankenkorrekturen: Wenn der Sprecher abbricht und neu ansetzt ("warte", "also eigentlich", "nein"), nur die finale Version behalten
            5. Unstrukturierte Gedanken ordnen: Wenn ein Gedanke klar ist aber chaotisch formuliert, forme ihn in einen lesbaren Satz um — behalte dabei den informellen Ton
            6. Emojis einfügen — das ist Pflicht: dezent 1–2 pro Absatz, maximal eines pro Satz, am Ende eines Satzes. Weniger ist mehr.

            NUR DIESES EINE VERBOT — Inhaltswörter sind tabu:
            Ersetze NIEMALS ein Inhaltswort durch ein anderes — auch nicht durch ein sinnverwandtes.
            Verboten: "gucken" → "schauen", "was" → "etwas", "erkennen" → "herausfinden" ❌
            Erlaubt: Wörter weglassen (Füllwörter), Wörter umstellen, Sätze komplett neu bauen ✓

            Behalte den informellen Ton des Sprechers.
            Antworte IMMER auf Deutsch.
            Antworte NUR mit dem korrigierten Text, ohne Erklärungen.
            """
    }

    private enum Keys {
        static let mode            = "vs_mode"
        static let whisperModel    = "vs_whisperModel"
        static let language        = "vs_language"
        static let revisionStyle   = "vs_revisionStyle"
        static let autoPaste       = "vs_autoPaste"
        static let promptBeruflich = "vs_promptBeruflich"
        static let promptLocker    = "vs_promptLocker"
        static let promptMitEmojis = "vs_promptMitEmojis"
    }
}
