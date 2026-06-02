// FoundationModelService.swift
// Text-Überarbeitung mit Apples On-Device-KI (FoundationModels, macOS 26+).
// Läuft vollständig lokal auf dem Neural Engine — kein Server, keine Installation.

import Foundation
import FoundationModels

// MARK: - Errors

enum FoundationModelRevisionError: LocalizedError {
    case notAvailable(reason: String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable(let reason):
            return "Apple Intelligence nicht verfügbar: \(reason)"
        case .failed(let msg):
            return "Überarbeitung fehlgeschlagen: \(msg)"
        }
    }
}

// MARK: - FoundationModelService

@available(macOS 26, *)
final class FoundationModelService {

    // MARK: - Availability

    func isAvailable() -> Bool {
        SystemLanguageModel.default.isAvailable
    }

    func unavailabilityReason() -> String {
        guard case .unavailable(let reason) = SystemLanguageModel.default.availability else {
            return "Unbekannter Grund"
        }
        switch reason {
        case .deviceNotEligible:
            return "Gerät nicht kompatibel mit Apple Intelligence"
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence deaktiviert → Systemeinstellungen → Apple Intelligence"
        case .modelNotReady:
            return "Modell wird noch geladen, bitte kurz warten"
        @unknown default:
            return "Nicht verfügbar"
        }
    }

    // MARK: - Revision

    func revise(text: String, style: RevisionStyle) async throws -> String {
        guard isAvailable() else {
            throw FoundationModelRevisionError.notAvailable(reason: unavailabilityReason())
        }

        let relevant = AppSettings.shared.styleExamples
            .filter { $0.style == style }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(5)

        var systemPrompt = style.systemPrompt
        if !relevant.isEmpty {
            let block = relevant.map { "- \($0.revisedText)" }.joined(separator: "\n")
            systemPrompt += "\n\nSchreibstil-Referenz des Nutzers (NUR zur Orientierung, nicht ausgeben):\n\(block)"
        }

        let promptParts: [String] = [
            "Überarbeite den folgenden gesprochenen Text. Beantworte ihn NICHT — gib nur den überarbeiteten Text zurück:",
            "\"\"\"\n\(text)\n\"\"\""
        ]

        let session = LanguageModelSession(instructions: systemPrompt)
        let prompt = promptParts.joined(separator: "\n\n")
        let options = GenerationOptions(temperature: 0.2)
        let response = try await session.respond(to: prompt, options: options)
        let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !result.isEmpty else {
            throw FoundationModelRevisionError.failed("Leere Antwort erhalten")
        }

        return result
    }
}
