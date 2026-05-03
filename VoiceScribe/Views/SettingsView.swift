// SettingsView.swift
// Settings window opened via Cmd+, or from the menu bar dropdown.
// Two tabs: General (hotkey, mode, language) and Models (Whisper + Ollama).

import SwiftUI
import KeyboardShortcuts
import ApplicationServices

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

            StylesTab()
                .tabItem { Label("Stile", systemImage: "bookmark.fill") }
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
                KeyboardShortcuts.Recorder("Aufnahme starten / stoppen:", name: .toggleRecording)
                    .help("Drücke eine Tastenkombination. Die Standard-Kombination ist ⌥Space.")
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

            // Accessibility permission status
            Section("Berechtigungen") {
                AccessibilityStatusRow()
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Models Tab

private struct ModelsTab: View {

    @EnvironmentObject var settings:  AppSettings
    @EnvironmentObject var viewModel: RecordingViewModel

    @State private var ollamaRunning      = false
    @State private var ollamaManagedByApp = false
    @State private var ollamaModels:      [String] = []
    @State private var isLoadingOllama    = false

    var body: some View {
        Form {
            // Whisper Model
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

            // Ollama Model
            Section("Ollama-Modell (Überarbeitungs-Modus)") {
                HStack {
                    Text("Ollama:")
                        .foregroundStyle(.secondary)
                    if ollamaRunning {
                        Text(ollamaManagedByApp ? "läuft ✓ (App)" : "läuft ✓ (extern)")
                            .foregroundColor(.green)
                    } else {
                        Text("nicht gestartet")
                            .foregroundColor(.orange)
                    }
                }

                if isLoadingOllama {
                    ProgressView("Lade Modell-Liste…")
                } else if ollamaModels.isEmpty && ollamaRunning {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Keine Modelle gefunden.")
                            .foregroundStyle(.secondary)
                        Text("Terminal: ollama pull mistral")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                } else if !ollamaModels.isEmpty {
                    Picker("Modell", selection: $settings.ollamaModel) {
                        ForEach(ollamaModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }

                HStack(spacing: 8) {
                    if !ollamaRunning {
                        Button("Ollama starten") {
                            Task {
                                isLoadingOllama = true
                                await viewModel.ollamaService.startServer()
                                await checkOllama()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.green)
                    } else {
                        Button("Ollama stoppen") {
                            viewModel.ollamaService.stopServer()
                            Task { await checkOllama() }
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }

                    Button("Aktualisieren") { Task { await checkOllama() } }
                        .buttonStyle(.bordered)
                }
            }
        }
        .formStyle(.grouped)
        .task { await checkOllama() }
    }

    private func checkOllama() async {
        isLoadingOllama = true
        ollamaRunning = await viewModel.ollamaService.isRunning()
        ollamaManagedByApp = viewModel.ollamaService.isManagedByApp
        if ollamaRunning {
            ollamaModels = (try? await viewModel.ollamaService.availableModels()) ?? []
        } else {
            ollamaModels = []
        }
        isLoadingOllama = false
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

// MARK: - Styles Tab

private struct StylesTab: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if settings.styleExamples.isEmpty {
                    ContentUnavailableView(
                        "Keine Stilbeispiele",
                        systemImage: "bookmark.slash",
                        description: Text("Speichere Beispiele mit \"Stil merken\" im Vorschau-Panel.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    ForEach(RevisionStyle.allCases) { style in
                        let examples = settings.styleExamples
                            .filter { $0.style == style }
                            .sorted { $0.createdAt > $1.createdAt }
                        if !examples.isEmpty {
                            StyleExamplesSection(style: style, examples: examples)
                                .environmentObject(settings)
                        }
                    }
                }
            }
            .padding()
        }
        .frame(minHeight: 300)
    }
}

private struct StyleExamplesSection: View {
    @EnvironmentObject var settings: AppSettings
    let style: RevisionStyle
    let examples: [StyleExample]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(style.displayName, systemImage: style.sfSymbol)
                .font(.headline)
                .foregroundColor(style.accentColor)

            ForEach(examples) { example in
                StyleExampleRow(example: example)
                    .environmentObject(settings)
            }
        }
    }
}

private struct StyleExampleRow: View {
    @EnvironmentObject var settings: AppSettings
    let example: StyleExample

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(example.revisedText)
                    .font(.system(size: 12))
                    .lineLimit(3)
                    .foregroundStyle(.primary)

                Text(example.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                settings.styleExamples.removeAll { $0.id == example.id }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .help("Beispiel löschen")
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Accessibility Status Row

private struct AccessibilityStatusRow: View {
    @State private var isTrusted = false
    // Timer fires every 2 s so the status updates automatically after the user
    // grants permission in System Settings without needing to re-open Settings.
    private let refreshTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Bedienungshilfen")
                Text("Benötigt für direktes Einfügen von Text (Strategie 1). Ohne Erlaubnis wird Zwischenablage + CMD+V verwendet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isTrusted {
                Label("Erlaubt", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Erlauben…") {
                    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                    AXIsProcessTrustedWithOptions(opts as CFDictionary)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
        .onAppear { isTrusted = AXIsProcessTrusted() }
        .onReceive(refreshTimer) { _ in isTrusted = AXIsProcessTrusted() }
    }
}
