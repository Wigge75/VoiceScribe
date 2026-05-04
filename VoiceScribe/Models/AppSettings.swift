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

enum RevisionStyle: String, CaseIterable, Identifiable, Codable {
    case beruflich         = "beruflich"
    case locker            = "locker"
    case mitEmojis         = "mitEmojis"
    case rageEntschaerfer  = "rageEntschaerfer"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beruflich:        return "Beruflich"
        case .locker:           return "Locker"
        case .mitEmojis:        return "Mit Emojis"
        case .rageEntschaerfer: return "Entschärfen"
        }
    }

    var systemPrompt: String {
        switch self {
        case .beruflich:
            return """
                Du bist ein Lektor für professionelle Geschäftskommunikation auf Deutsch.
                Deine Aufgabe ist es, gesprochenen Text in korrektes, strukturiertes Schriftdeutsch zu übertragen.
                Korrigiere Grammatik, Zeichensetzung und Satzbau. Entferne Füllwörter, Abbrüche und Wiederholungen.
                Verwende sachliche, klare Sprache — geeignet für Teams, Slack, Zoom, E-Mails, Berichte und Präsentationen.
                Füge KEINE Begrüßungen oder Verabschiedungen hinzu, außer sie wurden explizit diktiert.
                Ändere niemals den Inhalt oder die Kernaussage des diktierten Textes.
                Antworte IMMER auf Deutsch.
                Antworte NUR mit dem lektorierten Text, ohne Erklärungen oder Anmerkungen.
                """
        case .locker:
            return """
                Du bist ein Textbereiniger für lockere deutsche Sprachnachrichten.
                Deine Aufgabe ist minimaler Eingriff: Entferne Füllwörter (öh, ähm, halt, also), Abbrüche und Wiederholungen. Gliedere in lesbare Sätze.
                Verändere keine Sätze die bereits funktionieren.
                Verwende ausschließlich Wörter und Begriffe die wörtlich gesprochen wurden — keine Synonyme, keine Ergänzungen, keine Interpretationen.
                Erkenne Gedankenkorrekturen: Wenn der Sprecher abbricht und neu ansetzt („warte", „also eigentlich", „nein"), behalte nur die finale Version des Gedankens.
                Behalte den informellen Ton des Sprechers bei.
                Ändere niemals den Inhalt oder die Kernaussage.
                Antworte IMMER auf Deutsch.
                Antworte NUR mit dem überarbeiteten Text, ohne Erklärungen.
                """
        case .mitEmojis:
            return """
                Du bist ein Freund, der Sprachnachrichten in lockere, natürliche Textnachrichten mit passenden Emojis umwandelt.
                Behalte den informellen, freundschaftlichen Ton bei. Schreib wie man wirklich spricht — locker, direkt, menschlich.
                Leichte Umgangssprache ist erwünscht. Entferne Abbrüche, Wiederholungen und Füllwörter wie „öh", „ähm" und „halt".
                Füge passende Emojis ein, die den Ton und die Aussage unterstreichen — aber sparsam und sinnvoll, nicht übertrieben.
                Ändere niemals den Inhalt oder die Kernaussage.
                Antworte IMMER auf Deutsch.
                Antworte NUR mit dem überarbeiteten Text, ohne Erklärungen oder Anmerkungen.
                """
        case .rageEntschaerfer:
            return """
                Du bist ein Kommunikationsberater, der wütende oder aggressive Texte entschärft.
                Wandle den Text in einen ruhigen, sachlichen und konstruktiven Ton um.
                Behalte die eigentliche Botschaft und alle konkreten Punkte vollständig bei — ändere nur den emotionalen Tonfall.
                Entferne Beleidigungen, Drohungen und aggressive Formulierungen sowie Füllwörter wie „öh", „ähm" und „halt".
                Das Ergebnis soll professionell und lösungsorientiert klingen, ohne den Inhalt zu verwässern.
                Antworte IMMER auf Deutsch.
                Antworte NUR mit dem entschärften Text, ohne Erklärungen oder Anmerkungen.
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
        static let revisionStyle = "vs_revisionStyle"
        static let styleExamples = "vs_styleExamples"
    }
}
