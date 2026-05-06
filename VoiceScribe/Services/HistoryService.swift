// HistoryService.swift
// Schreibt jeden Transkriptions-/Überarbeitungsvorgang in eine JSON-Datei auf der Festplatte.
// Speicherort: ~/Library/Application Support/VoiceScribe/history.json

import Foundation

actor HistoryService {
    static let shared = HistoryService()

    private var fileURL: URL {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VoiceScribe")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    func append(_ entry: HistoryEntry) {
        var entries = load()
        entries.insert(entry, at: 0)
        save(entries)
    }

    func load() -> [HistoryEntry] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: fileURL),
              let entries = try? decoder.decode([HistoryEntry].self, from: data)
        else { return [] }
        return entries
    }

    private func save(_ entries: [HistoryEntry]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
