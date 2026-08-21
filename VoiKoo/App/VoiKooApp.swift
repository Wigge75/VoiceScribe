// VoiKooApp.swift
// App entry point. Sets up the menu bar icon, the floating recording panel,
// and the Settings window.

import SwiftUI
import KeyboardShortcuts

@main
struct VoiKooApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = RecordingViewModel()

    var body: some Scene {
        MenuBarExtra("VoiKoo", systemImage: viewModel.menuBarIconName) {
            MenuBarMenuView()
                .environmentObject(viewModel)
                .environmentObject(AppSettings.shared)
        }
        .menuBarExtraStyle(.menu)

        // Settings window, opened via Cmd+, or the menu bar menu.
        Settings {
            SettingsView()
                .environmentObject(viewModel)
                .environmentObject(AppSettings.shared)
                .frame(width: 480, height: 360)
        }
    }
}

// MARK: - Menu Bar Menu

/// The dropdown menu shown when the user clicks the menu bar icon.
struct MenuBarMenuView: View {
    @EnvironmentObject var viewModel: RecordingViewModel
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        // Current recording status as a non-interactive label
        Text(viewModel.statusSummary)
            .foregroundStyle(.secondary)

        Divider()

        // Mode picker — switches between Dictation and Revision inline
        Picker("Modus", selection: $settings.mode) {
            ForEach(RecordingMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.inline)

        Divider()

        // Start/stop recording button
        Button(viewModel.isRecording ? "Aufnahme stoppen" : "Aufnahme starten") {
            viewModel.toggleRecording()
        }

        Button("Audiodatei importieren…") {
            viewModel.importAudioFile()
        }
        .disabled(!viewModel.canImport)

        Menu("Verlauf") {
            if viewModel.recentHistory.isEmpty {
                Text("Noch kein Verlauf")
            } else {
                ForEach(viewModel.recentHistory) { entry in
                    Button {
                        viewModel.copyHistoryEntryToClipboard(entry)
                    } label: {
                        Label {
                            Text(historyRowTitle(for: entry))
                                + Text("  ·  ")
                                + Text(entry.timestamp, format: .relative(presentation: .named))
                        } icon: {
                            Image(systemName: historyRowIcon(for: entry))
                        }
                    }
                }
            }
        }

        Divider()

        // SettingsLink is the correct macOS 14+ way to open the Settings scene
        SettingsLink {
            Text("Einstellungen…")
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("VoiKoo beenden") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)

        Divider()

        Text("Version \(AppSettings.appVersion)")
            .foregroundStyle(.secondary)
            .font(.caption)
    }
}

// MARK: - History Row Helpers

private func historyRowIcon(for entry: HistoryEntry) -> String {
    entry.style?.sfSymbol ?? "mic.fill"
}

private func historyRowTitle(for entry: HistoryEntry) -> String {
    let preview = entry.result
        .replacingOccurrences(of: "\n", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let truncated = preview.count > 40 ? String(preview.prefix(40)) + "…" : preview
    return truncated.isEmpty ? "(leer)" : truncated
}
