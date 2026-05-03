// StyleExample.swift
// Represents a saved revision the user wants the AI to use as a style reference.

import Foundation

struct StyleExample: Codable, Identifiable {
    let id: UUID
    let style: RevisionStyle
    let revisedText: String
    let createdAt: Date

    init(id: UUID = UUID(), style: RevisionStyle, revisedText: String, createdAt: Date = Date()) {
        self.id = id
        self.style = style
        self.revisedText = revisedText
        self.createdAt = createdAt
    }
}
