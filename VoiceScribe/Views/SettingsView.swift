// SettingsView.swift
// Settings window opened via Cmd+, or from the menu bar dropdown.
// Two tabs: General (hotkey, mode, language) and Models (Whisper + Apple Intelligence).

import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {

    @EnvironmentObject var settings:   AppSettings
    @EnvironmentObject var viewModel:  RecordingViewModel

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("Allgemein", systemImage: "gear") }
                .environmentObject(settings)
                .environmentObject(viewModel)

            ModelsTab()
                .tabItem { Label("Modelle", systemImage: "cpu") }
                .environmentObject(settings)
                .environmentObject(viewModel)

            PromptsTab()
                .tabItem { Label("Prompts", systemImage: "text.bubble") }
                .environmentObject(settings)
        }
        .padding()
    }
}

// MARK: - General Tab

private struct GeneralTab: View {

    @EnvironmentObject var settings:  AppSettings
    @EnvironmentObject var viewModel: RecordingViewModel

    var body: some View {
        Form {
            // Keyboard Shortcut
            Section("Tastenkürzel") {
                KeyboardShortcuts.Recorder("Push-to-Talk (halten für Aufnahme):", name: .toggleRecording)
                    .help("Drücke eine Tastenkombination. Die Standard-Kombination ist ⌥Space.")
                KeyboardShortcuts.Recorder("Modus wechseln (⌥0):", name: .toggleMode)
                KeyboardShortcuts.Recorder("Stil: Beruflich (⌥1):", name: .selectStyleBeruflich)
                KeyboardShortcuts.Recorder("Stil: Locker (⌥2):", name: .selectStyleLocker)
                KeyboardShortcuts.Recorder("Stil: Mit Emojis (⌥3):", name: .selectStyleMitEmojis)

                Text("Stil-Tastenkürzel wechseln automatisch in den Überarbeitungs-Modus.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Default Mode
            Section("Standard-Modus") {
                Picker("Modus beim Start", selection: $settings.mode) {
                    ForEach(RecordingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if settings.mode == .revision {
                    Picker("Standard-Stil", selection: $settings.revisionStyle) {
                        ForEach(RevisionStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.menu)

                    Label(
                        "Überarbeitungs-Modus: Whisper transkribiert, KI verfeinert den Text im gewählten Stil.",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            // Language
            Section("Sprache") {
                Picker("Transkriptions-Sprache", selection: $settings.language) {
                    Text("Automatisch erkennen").tag("auto")
                    Divider()
                    Text("Deutsch").tag("de")
                    Text("Englisch").tag("en")
                    Text("Französisch").tag("fr")
                    Text("Spanisch").tag("es")
                    Text("Italienisch").tag("it")
                    Text("Japanisch").tag("ja")
                    Text("Chinesisch").tag("zh")
                }

                Text("Bei Deutsch empfiehlt sich \"Deutsch\" statt \"Automatisch\" für bessere Genauigkeit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Verhalten nach Aufnahme") {
                Toggle("Text automatisch einfügen", isOn: $settings.autoPaste)
                    .onChange(of: settings.autoPaste) { _, newValue in
                        if newValue && !AXIsProcessTrusted() {
                            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                            AXIsProcessTrustedWithOptions(options)
                        }
                    }
                Text("Fügt den transkribierten Text direkt in das zuletzt fokussierte Eingabefeld ein. Erfordert einmalig die Berechtigung unter Systemeinstellungen > Datenschutz > Bedienungshilfen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        }
        .formStyle(.grouped)
    }
}

// MARK: - Models Tab

private struct ModelsTab: View {

    @EnvironmentObject var settings:  AppSettings
    @EnvironmentObject var viewModel: RecordingViewModel

    var body: some View {
        Form {
            Section("Whisper-Modell (Transkription)") {
                Picker("Modell", selection: $settings.whisperModel) {
                    ForEach(WhisperModelSize.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .onChange(of: settings.whisperModel) { _, _ in
                    viewModel.reloadWhisperModel()
                }

                HStack {
                    Text("Status:")
                        .foregroundStyle(.secondary)
                    WhisperStatusView()
                        .environmentObject(viewModel)
                }

                Text("Das Modell wird beim ersten Mal automatisch heruntergeladen (~300 MB für Base).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Überarbeitungs-Modus") {
                Label("Apple Intelligence (On-Device)", systemImage: "apple.intelligence")
                    .foregroundStyle(.primary)
                Text("Läuft vollständig lokal auf dem Neural Engine. Kein Server, keine Installation erforderlich.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Prompts Tab

private struct PromptsTab: View {

    @EnvironmentObject var settings: AppSettings
    @State private var selectedStyle: RevisionStyle = .beruflich

    private var promptBinding: Binding<String> {
        switch selectedStyle {
        case .beruflich: return $settings.promptBeruflich
        case .locker:    return $settings.promptLocker
        case .mitEmojis: return $settings.promptMitEmojis
        }
    }

    private var isEmpty: Bool {
        promptBinding.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("Stil") {
                Picker("Stil", selection: $selectedStyle) {
                    ForEach(RevisionStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("System-Prompt") {
                TextEditor(text: promptBinding)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 260)

                if isEmpty {
                    Label("Der Prompt darf nicht leer sein.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Whisper Status View

private struct WhisperStatusView: View {
    @EnvironmentObject var viewModel: RecordingViewModel

    var body: some View {
        switch viewModel.whisperService.loadState {
        case .idle:
            Text("Nicht geladen")
                .foregroundStyle(.secondary)
        case .loading:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("Lade…")
            }
        case .ready:
            Label("Bereit", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed(let msg):
            Label("Fehler: \(msg)", systemImage: "xmark.circle")
                .foregroundColor(.red)
        }
    }
}


