// VoiceScribeApp.swift
// App entry point. Sets up the menu bar icon, the floating recording panel,
// and the Settings window.

import SwiftUI
import KeyboardShortcuts

@main
struct VoiceScribeApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = RecordingViewModel()

    var body: some Scene {
        MenuBarExtra("VoiceScribe", systemImage: viewModel.menuBarIconName) {
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

        Divider()

        // SettingsLink is the correct macOS 14+ way to open the Settings scene
        SettingsLink {
            Text("Einstellungen…")
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("VoiceScribe beenden") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)

        Divider()

        Text("Version \(AppSettings.appVersion)")
            .foregroundStyle(.secondary)
            .font(.caption)
    }
}
