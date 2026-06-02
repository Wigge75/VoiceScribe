// RecordingPanel.swift
// FloatingPanel: NSPanel subclass that floats above all windows.
// Uses orderFront (not makeKeyAndOrderFront) — target app keeps keyboard focus.

import AppKit
import SwiftUI

// MARK: - FloatingPanel

final class FloatingPanel: NSPanel {

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 195),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing:   .buffered,
            defer:     false
        )
        level              = .floating
        hidesOnDeactivate  = false
        titlebarAppearsTransparent = true
        titleVisibility    = .hidden
        isMovableByWindowBackground = true
        backgroundColor    = .clear
        isOpaque           = false
        hasShadow          = true
    }

    override var canBecomeKey:  Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - PanelController

@MainActor
final class PanelController {

    private var panel: FloatingPanel?
    private var hostingController: NSHostingController<AnyView>?

    /// Shows the panel without stealing keyboard focus.
    func show(viewModel: RecordingViewModel) {
        if panel == nil {
            let p = FloatingPanel()
            let hc = NSHostingController(rootView: AnyView(
                RecordingPanelContent()
                    .environmentObject(viewModel)
                    .environmentObject(AppSettings.shared)
            ))
            p.contentViewController = hc
            panel = p
            hostingController = hc
            positionPanelNearTopCenter(p)
        }
        panel?.orderFront(nil)  // non-activating: target app keeps keyboard focus
    }

    func hide() {
        panel?.orderOut(nil)
    }

    /// Animates the panel to a new height, keeping the top edge fixed.
    func resize(to height: CGFloat) {
        guard let p = panel else { return }
        let current = p.frame
        let newY = current.maxY - height
        let newFrame = NSRect(x: current.minX, y: newY, width: current.width, height: height)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            p.animator().setFrame(newFrame, display: true)
        }
    }

    // MARK: - Positioning

    private func positionPanelNearTopCenter(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { panel.center(); return }
        let f = screen.visibleFrame
        let s = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: f.midX - s.width / 2,
                                     y: f.maxY - s.height - 20))
    }
}
