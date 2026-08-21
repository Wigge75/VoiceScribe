// HistoryEntry.swift
// Repräsentiert einen einzelnen Transkriptions- oder Überarbeitungsvorgang im Verlaufs-Archiv.

import Foundation

struct HistoryEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let appVersion: String
    let mode: RecordingMode
    let style: RevisionStyle?
    let transcript: String
    let result: String

    init(mode: RecordingMode, style: RevisionStyle?, transcript: String, result: String) {
        self.id         = UUID()
        self.timestamp  = Date()
        self.appVersion = AppSettings.appVersion
        self.mode       = mode
        self.style      = style
        self.transcript = transcript
        self.result     = result
    }
}
