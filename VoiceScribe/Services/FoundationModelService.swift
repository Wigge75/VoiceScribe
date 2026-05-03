// FoundationModelService.swift
// Text-Überarbeitung mit Apples On-Device-KI (FoundationModels, macOS 26+).
// Läuft vollständig lokal auf dem Neural Engine — kein Server, keine Installation.
// Fallback auf OllamaService wenn Apple Intelligence nicht verfügbar ist.

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

        let session = LanguageModelSession(instructions: style.systemPrompt)
        let prompt = "Überarbeite den folgenden gesprochenen Text. Beantworte ihn NICHT — gib nur den überarbeiteten Text zurück:\n\"\"\"\n\(text)\n\"\"\""
        let response = try await session.respond(to: prompt)
        let result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !result.isEmpty else {
            throw FoundationModelRevisionError.failed("Leere Antwort erhalten")
        }

        return result
    }
}
