// RecordingPanelContent.swift
// SwiftUI view inside the floating NSPanel.
//
// States:
//   recording    — pulsierender roter Punkt + Wellenform
//   transcribing — Ladekreis
//   revising     — Sparkles-Icon (Apple Intelligence läuft)
//   done         — grüner Haken + Text-Preview
//   error        — Warnsymbol + Meldung (3 s sichtbar)

import SwiftUI

struct RecordingPanelContent: View {

    @EnvironmentObject var viewModel: RecordingViewModel
    @EnvironmentObject var settings: AppSettings
    @State private var recordingElapsed: Int = 0

    private var isRecording: Bool {
        if case .recording = viewModel.state { return true }
        return false
    }

    private var elapsedLabel: String {
        let m = recordingElapsed / 60
        let s = recordingElapsed % 60
        return String(format: "%d:%02d", m, s)
    }

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

                    if isRecording {
                        Text(elapsedLabel)
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

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

                    // Abort button during transcribing / revising
                    if case .transcribing = viewModel.state {
                        Button { viewModel.forceAbort() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Abbrechen")
                    }
                    if case .revising = viewModel.state {
                        Button { viewModel.forceAbort() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Abbrechen")
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

            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(width: 400)
        .background(Color.clear)
        .animation(.easeInOut(duration: 0.2), value: stateLabel)
        .task(id: isRecording) {
            guard isRecording else { recordingElapsed = 0; return }
            recordingElapsed = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if isRecording { recordingElapsed += 1 }
            }
        }
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
