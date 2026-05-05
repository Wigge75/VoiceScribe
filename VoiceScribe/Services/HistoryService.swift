// HistoryService.swift
// Schreibt jeden Transkriptions-/Überarbeitungsvorgang in eine JSON-Datei auf der Festplatte.
// Speicherort: ~/Library/Application Support/VoiceScribe/history.json

import Foundation

actor HistoryService {
    static let shared = HistoryService()
    private let maxEntries = 100

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
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save(entries)
    }

    func load() -> [HistoryEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let entries = try? JSONDecoder().decode([HistoryEntry].self, from: data)
        else { return [] }
        return entries
    }

    private func save(_ entries: [HistoryEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
