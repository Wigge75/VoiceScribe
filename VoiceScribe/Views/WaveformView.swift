// WaveformView.swift
// Animated waveform using Canvas + TimelineView.
// Each bar has an independent phase offset, creating an organic wave motion.
// Bar height scales with the microphone input level (0.0–1.0).

import SwiftUI

struct WaveformView: View {

    /// Normalised audio level from AudioRecorder, 0.0 (silence) to 1.0 (peak).
    var level: Float

    private let barCount = 24

    // Random phase offsets assigned once on appear for organic variation
    @State private var phases: [Double] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                drawBars(context: context, size: size, time: t)
            }
        }
        .onAppear {
            // Initialise with random phases so bars don't all move in sync
            phases = (0..<barCount).map { _ in Double.random(in: 0..<(2 * .pi)) }
        }
    }

    // MARK: - Drawing

    private func drawBars(context: GraphicsContext, size: CGSize, time: Double) {
        guard phases.count == barCount else { return }

        // Lay out barCount bars with equal spacing, leaving a gap between each
        let totalWidth  = size.width
        let barWidth    = totalWidth / CGFloat(barCount * 2 - 1)
        let minHeight: CGFloat = 4  // Always show a tiny bar even on silence

        for i in 0..<barCount {
            // Each bar oscillates at slightly different speed based on its index
            let speed  = 2.5 + Double(i) * 0.08
            let phase  = phases[i] + time * speed
            // noise: 0.4…1.0 to keep bars slightly different heights
            let noise  = (sin(phase) * 0.3 + 0.7)

            let height = max(minHeight, CGFloat(level) * CGFloat(noise) * size.height)
            let x      = CGFloat(i * 2) * barWidth
            let y      = (size.height - height) / 2

            let rect = CGRect(x: x, y: y, width: barWidth, height: height)
            let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)

            // Colour: grey at low levels, red at high levels
            let saturation = Double(min(1.0, level * 1.2))
            let color = Color(
                hue:        0.0,          // Red hue
                saturation: saturation,
                brightness: 0.88
            )
            context.fill(path, with: .color(color))
        }
    }
}

#Preview {
    WaveformView(level: 0.6)
        .frame(width: 360, height: 40)
        .padding()
        .background(.black)
}
