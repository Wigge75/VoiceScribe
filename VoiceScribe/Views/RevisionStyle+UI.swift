// RevisionStyle+UI.swift
// SwiftUI-spezifische Eigenschaften für RevisionStyle (Icons, Farben).
// Getrennt von AppSettings.swift damit das Model-Layer SwiftUI-frei bleibt.

import SwiftUI

extension RevisionStyle {

    var sfSymbol: String {
        switch self {
        case .beruflich: return "briefcase.fill"
        case .locker:    return "bubble.left.fill"
        case .mitEmojis: return "face.smiling.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .beruflich: return .blue
        case .locker:    return .green
        case .mitEmojis: return .orange
        }
    }
}
