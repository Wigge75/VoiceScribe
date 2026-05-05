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

enum RecordingMode: String, CaseIterable, Identifiable {
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

    var systemPrompt: String {
        switch self {
        case .beruflich:
            return """
                Du bist ein Transkriptions-Korrektor für professionelles Schriftdeutsch.

                OBERSTES GEBOT — Worttreue: Ersetze NIEMALS ein gesprochenes Wort durch ein anderes, auch nicht durch ein sinnverwandtes oder "präziseres".

                Erlaubte Eingriffe (ausschließlich diese):
                - Füllwörter entfernen: öh, ähm, halt, also
                - Abbrüche und Wiederholungen entfernen
                - Satzzeichen, Großschreibung und offensichtliche Grammatikfehler korrigieren (fehlende Artikel, falsche Flexion)
                - Gedankenkorrekturen: nur die finale Version eines Gedankens behalten

                Behalte die Wortwahl des Sprechers vollständig bei — auch wenn du andere Wörter "besser" finden würdest.
                Füge KEINE Begrüßungen oder Verabschiedungen hinzu, außer sie wurden explizit diktiert.
                Antworte IMMER auf Deutsch.
                Antworte NUR mit dem korrigierten Text, ohne Erklärungen oder Anmerkungen.
                """
        case .locker:
            return """
                Du bist ein Transkriptions-Korrektor für gesprochenes Deutsch.

                OBERSTES GEBOT — Worttreue: Ersetze NIEMALS ein gesprochenes Wort durch ein anderes.
                Auch nicht durch ein sinnverwandtes. Auch nicht durch eine "bessere" Formulierung.
                Falsch: Sprecher sagt "erkennen" → du schreibst "herausfinden". ❌
                Richtig: Sprecher sagt "erkennen" → du schreibst "erkennen". ✓

                Erlaubte Eingriffe (ausschließlich diese):
                - Füllwörter entfernen: öh, ähm, halt, also, ne, oder?
                - Offensichtliche Abbrüche und Wiederholungen entfernen
                - Satzzeichen und Großschreibung ergänzen
                - Gedankenkorrekturen: Wenn der Sprecher abbricht und neu ansetzt ("warte", "also eigentlich", "nein"), nur die finale Version behalten

                Alles andere bleibt exakt wie gesprochen — Wortwahl, Satzbau, Reihenfolge, Ton.
                Antworte IMMER auf Deutsch.
                Antworte NUR mit dem korrigierten Text, ohne Erklärungen.
                """
        case .mitEmojis:
            return """
                Du bist ein Transkriptions-Korrektor für gesprochenes Deutsch mit Emojis.

                OBERSTES GEBOT — Worttreue: Ersetze NIEMALS ein gesprochenes Wort durch ein anderes.
                Auch nicht durch ein sinnverwandtes. Auch nicht durch eine "bessere" Formulierung.
                Falsch: Sprecher sagt "erkennen" → du schreibst "herausfinden". ❌
                Richtig: Sprecher sagt "erkennen" → du schreibst "erkennen". ✓

                Erlaubte Eingriffe (ausschließlich diese):
                - Füllwörter entfernen: öh, ähm, halt, also, ne, oder?
                - Offensichtliche Abbrüche und Wiederholungen entfernen
                - Satzzeichen und Großschreibung ergänzen
                - Gedankenkorrekturen: Wenn der Sprecher abbricht und neu ansetzt ("warte", "also eigentlich", "nein"), nur die finale Version behalten
                - Emojis einfügen — das ist Pflicht: dezent 1–2 pro Absatz, maximal eines pro Satz, am Ende eines Satzes. Weniger ist mehr.

                Alles andere bleibt exakt wie gesprochen — Wortwahl, Satzbau, Reihenfolge, Ton.
                Antworte IMMER auf Deutsch.
                Antworte NUR mit dem korrigierten Text, ohne Erklärungen.
                """
        }
    }
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

enum SilenceTimeout: Double, CaseIterable, Identifiable {
    case off          = 0
    case one          = 1.0
    case onePointFive = 1.5
    case two          = 2.0
    case three        = 3.0
    case five         = 5.0

    var id: Double { rawValue }

    var displayName: String {
        switch self {
        case .off:          return "Aus"
        case .one:          return "1 Sek."
        case .onePointFive: return "1,5 Sek."
        case .two:          return "2 Sek."
        case .three:        return "3 Sek."
        case .five:         return "5 Sek."
        }
    }
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

    @Published var silenceTimeout: SilenceTimeout {
        didSet { UserDefaults.standard.set(silenceTimeout.rawValue, forKey: Keys.silenceTimeout) }
    }

    @Published var revisionStyle: RevisionStyle {
        didSet { UserDefaults.standard.set(revisionStyle.rawValue, forKey: Keys.revisionStyle) }
    }

    @Published var styleExamples: [StyleExample] {
        didSet {
            if let data = try? JSONEncoder().encode(styleExamples) {
                UserDefaults.standard.set(data, forKey: Keys.styleExamples)
            }
        }
    }

    static let styleExampleMinCharacters = 80
    static let styleExampleMaxCharacters = 500

    private init() {
        let defaults = UserDefaults.standard
        mode = RecordingMode(rawValue: defaults.string(forKey: Keys.mode) ?? "") ?? .dictation
        whisperModel = WhisperModelSize(rawValue: defaults.string(forKey: Keys.whisperModel) ?? "") ?? .small
        // Kein Default-Modell — der Nutzer wählt in Einstellungen → Modelle.
        // Ein leerer String führt zu einer verständlichen Fehlermeldung statt Timeout.
        ollamaModel = defaults.string(forKey: Keys.ollamaModel) ?? ""
        language = defaults.string(forKey: Keys.language) ?? "de"
        silenceTimeout = SilenceTimeout(rawValue: defaults.double(forKey: Keys.silenceTimeout)) ?? .onePointFive
        revisionStyle = RevisionStyle(rawValue: defaults.string(forKey: Keys.revisionStyle) ?? "") ?? .beruflich
        if let data = defaults.data(forKey: Keys.styleExamples),
           let decoded = try? JSONDecoder().decode([StyleExample].self, from: data) {
            styleExamples = decoded
        } else {
            styleExamples = []
        }
    }

    private enum Keys {
        static let mode          = "vs_mode"
        static let whisperModel  = "vs_whisperModel"
        static let ollamaModel   = "vs_ollamaModel"
        static let language      = "vs_language"
        static let silenceTimeout = "vs_silenceTimeout"
        static let revisionStyle  = "vs_revisionStyle"
        static let styleExamples = "vs_styleExamples"
    }
}
