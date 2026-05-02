// RecordingPanelContent.swift
// SwiftUI view inside the floating NSPanel.
//
// States:
//   recording    — pulsierender roter Punkt + Wellenform
//   transcribing — Ladekreis
//   revising     — Sparkles-Icon (Ollama läuft)
//   preview      — fertiger Text + "↩ Einfügen" / "Verwerfen"-Buttons
//   inserting    — Cursor-Icon
//   done         — grüner Haken
//   error        — Warnsymbol + Meldung (3 s sichtbar)

import SwiftUI

struct RecordingPanelContent: View {

    @EnvironmentObject var viewModel: RecordingViewModel
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ZStack {
            // Frosted glass background
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 10) {

                // ── Status row ──────────────────────────────────────────
                HStack(spacing: 10) {
                    stateIndicator
                        .frame(width: 16, height: 16)

                    Text(stateLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    // Stop button during recording
                    if case .recording = viewModel.state {
                        Button {
                            viewModel.toggleRecording()
                        } label: {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Aufnahme stoppen")
                    }
                }

                // ── Style-Picker (nur im Überarbeitungs-Modus) ─────────
                if settings.mode == .revision {
                    RevisionStylePicker()
                        .transition(.opacity)
                }

                // ── Waveform (recording only) ───────────────────────────
                if case .recording = viewModel.state {
                    WaveformView(level: viewModel.audioLevel.normalised)
                        .frame(height: 36)
                        .transition(.opacity)
                }

                // ── Revision hint ───────────────────────────────────────
                if case .revising = viewModel.state {
                    Text("KI überarbeitet… (kann 10–30 Sek. dauern)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                }

                // ── Preview: Text + Aktions-Buttons ────────────────────
                if case .preview(let text) = viewModel.state {
                    // Vorschau-Text
                    Text(text)
                        .font(.system(size: 12))
                        .foregroundStyle(.primary.opacity(0.85))
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)

                    // Hinweis wenn Überarbeitung fehlschlug (gelber Banner)
                    if let warning = viewModel.revisionWarning {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                                .font(.system(size: 11))
                            Text(warning.message)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                    }

                    // Buttons
                    HStack {
                        // Verwerfen — Escape
                        Button(role: .cancel) {
                            viewModel.cancelInsertion()
                        } label: {
                            Text("Verwerfen")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)

                        Spacer()

                        // Kopieren — Klick oder Enter-Taste
                        Button {
                            viewModel.confirmInsertion()
                        } label: {
                            Label("Kopieren", systemImage: "doc.on.clipboard")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(width: 400, height: 220)
        .background(Color.clear)
        .animation(.easeInOut(duration: 0.2), value: stateLabel)
    }

    // MARK: - State Indicator

    @ViewBuilder
    private var stateIndicator: some View {
        switch viewModel.state {
        case .recording:
            RecordingDot()
        case .transcribing:
            ProgressView()
                .controlSize(.small)
        case .revising:
            Image(systemName: AppSettings.shared.revisionStyle.sfSymbol)
                .foregroundColor(AppSettings.shared.revisionStyle.accentColor)
        case .preview:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .inserting:
            Image(systemName: "text.cursor")
                .foregroundColor(.green)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
        case .idle:
            EmptyView()
        }
    }

    // MARK: - State Label

    private var stateLabel: String {
        switch viewModel.state {
        case .idle:                  return "Bereit"
        case .recording:             return "Aufnahme läuft…"
        case .transcribing:          return "Transkribiere…"
        case .revising:              return "KI überarbeitet…"
        case .preview:               return "Ergebnis — ↩ Kopieren"
        case .inserting:             return "Text wird eingefügt…"
        case .done(let preview):     return "✓ \(preview.prefix(30))…"
        case .error(let msg):        return "Fehler: \(msg)"
        }
    }
}

// MARK: - Revision Style Picker

private struct RevisionStylePicker: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 4) {
            ForEach(RevisionStyle.allCases) { style in
                Button {
                    settings.revisionStyle = style
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: style.sfSymbol)
                            .font(.system(size: 11, weight: .medium))
                        Text(style.displayName)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(
                        settings.revisionStyle == style
                            ? style.accentColor.opacity(0.15)
                            : Color.clear
                    )
                    .foregroundColor(
                        settings.revisionStyle == style
                            ? style.accentColor
                            : .secondary
                    )
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                settings.revisionStyle == style
                                    ? style.accentColor.opacity(0.4)
                                    : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .help(style.displayName)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: settings.revisionStyle)
    }
}

// MARK: - Pulsing Recording Dot

private struct RecordingDot: View {
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .overlay(
                Circle()
                    .stroke(Color.red.opacity(0.4), lineWidth: 5)
                    .scaleEffect(pulsing ? 1.8 : 1.0)
                    .opacity(pulsing ? 0.0 : 0.6)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: false)) {
                    pulsing = true
                }
            }
    }
}
