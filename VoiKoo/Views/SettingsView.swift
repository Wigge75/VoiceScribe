// SettingsView.swift
// Settings window opened via Cmd+, or from the menu bar dropdown.
// Three tabs: System, General, and Prompts.

import SwiftUI
import AVFoundation
import KeyboardShortcuts

struct SettingsView: View {

    @EnvironmentObject var settings:   AppSettings
    @EnvironmentObject var viewModel:  RecordingViewModel

    var body: some View {
        TabView {
            SystemTab()
                .tabItem { Label("System", systemImage: "checklist") }
                .environmentObject(settings)

            GeneralTab()
                .tabItem { Label("Allgemein", systemImage: "gear") }
                .environmentObject(settings)
                .environmentObject(viewModel)

            PromptsTab()
                .tabItem { Label("Prompts", systemImage: "text.bubble") }
                .environmentObject(settings)
        }
        .padding()
    }
}

// MARK: - System Tab

private struct SystemTab: View {

    @EnvironmentObject var settings: AppSettings
    @State private var accessibilityTrusted = AXIsProcessTrusted()
    @State private var microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)

    var body: some View {
        Form {
            Section("VoiKoo einrichten") {
                Text("Für die beste Nutzung braucht VoiKoo Mikrofon-Zugriff. Automatisches Einfügen benötigt zusätzlich Bedienungshilfen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Freigaben") {
                SetupStatusRow(
                    title: "Mikrofon",
                    detail: microphoneDetail,
                    isReady: microphoneStatus == .authorized,
                    actionTitle: microphoneActionTitle,
                    action: handleMicrophoneAction
                )

                SetupStatusRow(
                    title: "Bedienungshilfen",
                    detail: "Erlaubt VoiKoo, den transkribierten Text per Cmd+V in das zuletzt fokussierte Textfeld einzufügen.",
                    isReady: accessibilityTrusted,
                    actionTitle: "Einstellungen öffnen",
                    action: openAccessibilitySettings
                )
            }

            Section("Automatisch einfügen") {
                Toggle("Text automatisch einfügen", isOn: $settings.autoPaste)
                    .onChange(of: settings.autoPaste) { _, newValue in
                        if newValue && !AXIsProcessTrusted() {
                            requestAccessibilityPermission()
                        }
                        refreshPermissionState()
                    }

                Text("Wenn aktiviert, landet der Text nach der Aufnahme direkt im aktuellen Eingabefeld. Ohne diese Option bleibt der Text in der Zwischenablage und kann manuell mit Cmd+V eingefügt werden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Apple Intelligence") {
                Label("Überarbeitung läuft lokal auf dem Gerät", systemImage: "apple.intelligence")
                    .foregroundStyle(.primary)

                Text("Der Überarbeitungs-Modus nutzt Apple Intelligence. Dafür muss Apple Intelligence in den Systemeinstellungen aktiviert und auf diesem Mac verfügbar sein.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refreshPermissionState)
    }

    private var microphoneDetail: String {
        switch microphoneStatus {
        case .authorized:
            return "VoiKoo darf dein Mikrofon für Aufnahmen verwenden."
        case .denied, .restricted:
            return "Der Mikrofon-Zugriff ist gesperrt. Bitte in den Systemeinstellungen erlauben."
        case .notDetermined:
            return "VoiKoo fragt beim ersten Aufnehmen nach Mikrofon-Zugriff."
        @unknown default:
            return "Der aktuelle Mikrofon-Status konnte nicht eindeutig gelesen werden."
        }
    }

    private var microphoneActionTitle: String {
        microphoneStatus == .notDetermined ? "Freigabe anfragen" : "Einstellungen öffnen"
    }

    private func handleMicrophoneAction() {
        if microphoneStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                DispatchQueue.main.async {
                    refreshPermissionState()
                }
            }
        } else {
            openPrivacySettings(anchor: "Privacy_Microphone")
        }
    }

    private func openAccessibilitySettings() {
        requestAccessibilityPermission()
        openPrivacySettings(anchor: "Privacy_Accessibility")
    }

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func openPrivacySettings(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func refreshPermissionState() {
        accessibilityTrusted = AXIsProcessTrusted()
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    }
}

private struct SetupStatusRow: View {
    let title: String
    let detail: String
    let isReady: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(title, systemImage: isReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(isReady ? .green : .orange)

                Spacer()

                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
            }

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
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

            Section("Whisper-Modell") {
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

                Text("Das Modell wird beim ersten Mal automatisch heruntergeladen (~216 MB für Ausgewogen).")
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
    @State private var editedPrompt: String = ""
    @State private var saved: Bool = false

    private var isEmpty: Bool {
        editedPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasUnsavedChanges: Bool {
        editedPrompt != settings.prompt(for: selectedStyle)
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
                .onChange(of: selectedStyle) { _, _ in
                    editedPrompt = settings.prompt(for: selectedStyle)
                    saved = false
                }
            }

            Section("System-Prompt") {
                TextEditor(text: $editedPrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 260)
                    .onChange(of: editedPrompt) { _, _ in saved = false }

                HStack {
                    if isEmpty {
                        Label("Der Prompt darf nicht leer sein.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    } else if saved {
                        Label("Gespeichert", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else if hasUnsavedChanges {
                        Label("Ungespeicherte Änderungen", systemImage: "circle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }

                    Spacer()

                    Button("Speichern") {
                        settings.setPrompt(editedPrompt, for: selectedStyle)
                        saved = true
                    }
                    .disabled(isEmpty || !hasUnsavedChanges)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            editedPrompt = settings.prompt(for: selectedStyle)
        }
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
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text(progress > 0
                         ? "Lädt herunter… \(Int(progress * 100)) %"
                         : "Lädt herunter…")
                }
                ProgressView(value: progress > 0 ? progress : nil)
                    .frame(maxWidth: 200)
                Text("Einmalig ~300 MB von HuggingFace — bitte warten.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .compiling:
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Modell wird kompiliert…")
                    Text("CoreML-Spezialisierung für dieses Gerät — einmalig ~2 Min.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
