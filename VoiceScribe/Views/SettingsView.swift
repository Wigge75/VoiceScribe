// SettingsView.swift
// Settings window opened via Cmd+, or from the menu bar dropdown.
// Two tabs: General (hotkey, mode, language) and Models (Whisper + Ollama).

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

            // Auto-Stop
            Section("Auto-Stopp") {
                Picker("Stopp nach Stille", selection: $settings.silenceTimeout) {
                    ForEach(SilenceTimeout.allCases) { timeout in
                        Text(timeout.displayName).tag(timeout)
                    }
                }
                .pickerStyle(.menu)

                Text("Aufnahme stoppt automatisch nach der gewählten Stille-Dauer. Standard: 1,5 Sek.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

private struct EditorContext: Identifiable {
    let id = UUID()
    let style: RevisionStyle
    let existing: StyleExample?
}

private struct StylesTab: View {
    @EnvironmentObject var settings: AppSettings
    @State private var editorContext: EditorContext?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(RevisionStyle.allCases) { style in
                    let examples = settings.styleExamples
                        .filter { $0.style == style }
                        .sorted { $0.createdAt > $1.createdAt }

                    StyleExamplesSection(
                        style: style,
                        examples: examples,
                        onAdd:  { editorContext = EditorContext(style: style, existing: nil) },
                        onEdit: { editorContext = EditorContext(style: style, existing: $0) }
                    )
                    .environmentObject(settings)
                }
            }
            .padding()
        }
        .frame(minHeight: 300)
        .sheet(item: $editorContext) { ctx in
            ExampleEditorSheet(context: ctx)
                .environmentObject(settings)
        }
    }
}

private struct StyleExamplesSection: View {
    @EnvironmentObject var settings: AppSettings
    let style: RevisionStyle
    let examples: [StyleExample]
    var onAdd:  () -> Void
    var onEdit: (StyleExample) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(style.displayName, systemImage: style.sfSymbol)
                    .font(.headline)
                    .foregroundColor(style.accentColor)
                Spacer()
                Button { onAdd() } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(style.accentColor)
                }
                .buttonStyle(.plain)
                .help("Neues \(style.displayName)-Beispiel hinzufügen")
            }

            if examples.isEmpty {
                Text("Noch keine Beispiele.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(examples) { example in
                    StyleExampleRow(example: example, onEdit: { onEdit(example) })
                        .environmentObject(settings)
                }
            }
        }
    }
}

private struct StyleExampleRow: View {
    @EnvironmentObject var settings: AppSettings
    let example: StyleExample
    var onEdit: () -> Void

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

            Button { onEdit() } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Beispiel bearbeiten")

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

// MARK: - Example Editor Sheet

private struct ExampleEditorSheet: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    let context: EditorContext
    @State private var draftText: String

    init(context: EditorContext) {
        self.context = context
        _draftText = State(initialValue: context.existing?.revisedText ?? "")
    }

    private var isValid: Bool {
        draftText.count >= AppSettings.styleExampleMinCharacters &&
        draftText.count <= AppSettings.styleExampleMaxCharacters
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    context.existing == nil
                        ? "Neues \(context.style.displayName)-Beispiel"
                        : "\(context.style.displayName)-Beispiel bearbeiten",
                    systemImage: context.style.sfSymbol
                )
                .font(.headline)
                .foregroundColor(context.style.accentColor)
                Spacer()
            }

            TextEditor(text: $draftText)
                .font(.system(size: 13))
                .frame(minHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            draftText.count > AppSettings.styleExampleMaxCharacters
                                ? Color.red : Color(nsColor: .separatorColor),
                            lineWidth: 1
                        )
                )
                .onChange(of: draftText) { _, new in
                    if new.count > AppSettings.styleExampleMaxCharacters {
                        draftText = String(new.prefix(AppSettings.styleExampleMaxCharacters))
                    }
                }

            HStack {
                if draftText.count < AppSettings.styleExampleMinCharacters {
                    Text("Noch \(AppSettings.styleExampleMinCharacters - draftText.count) Zeichen bis zum Minimum")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if draftText.count > AppSettings.styleExampleMaxCharacters {
                    Text("\(draftText.count)/\(AppSettings.styleExampleMaxCharacters) — zu lang")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("\(draftText.count)/\(AppSettings.styleExampleMaxCharacters)")
                        .font(.caption)
                        .foregroundStyle(
                            draftText.count > AppSettings.styleExampleMaxCharacters - 50
                                ? .orange : .secondary
                        )
                }
                Spacer()
            }

            HStack {
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Speichern") { save(); dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 440, height: 240)
    }

    private func save() {
        if let existing = context.existing {
            if let idx = settings.styleExamples.firstIndex(where: { $0.id == existing.id }) {
                settings.styleExamples[idx] = StyleExample(
                    id: existing.id,
                    style: context.style,
                    revisedText: draftText,
                    createdAt: existing.createdAt
                )
            }
        } else {
            settings.styleExamples.append(StyleExample(style: context.style, revisedText: draftText))
        }
    }
}

