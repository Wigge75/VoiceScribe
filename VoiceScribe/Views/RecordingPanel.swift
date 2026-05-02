// RecordingPanel.swift
// FloatingPanel: NSPanel subclass that floats above all windows.
//
// During recording/transcribing/revising:
//   • orderFront (not makeKeyAndOrderFront) — target app keeps keyboard focus
//   • canBecomeKey = true so we CAN make it key when needed
//
// During preview:
//   • makeKeyAndOrderFront — panel takes keyboard focus
//   • keyDown override handles Return (confirm) and Escape (cancel)
//   • AppKit keyDown is more reliable than SwiftUI .keyboardShortcut in NSPanel

import AppKit
import SwiftUI

// MARK: - FloatingPanel

final class FloatingPanel: NSPanel {

    /// Set by PanelController before calling makeKeyAndOrderFront.
    var confirmHandler: (() -> Void)?
    var cancelHandler:  (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 160),
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

    override var canBecomeKey:  Bool { true  }  // explicitly made key in preview
    override var canBecomeMain: Bool { false }

    /// Handles Enter (confirm) and Escape (cancel) in preview state.
    /// Called when the panel is the key window.
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76:   // Return (36) or Numpad Enter (76)
            confirmHandler?()
        case 53:        // Escape
            cancelHandler?()
        default:
            super.keyDown(with: event)
        }
    }
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
                RecordingPanelContent().environmentObject(viewModel)
            ))
            p.contentViewController = hc
            panel = p
            hostingController = hc
            positionPanelNearTopCenter(p)
        }
        panel?.orderFront(nil)  // non-activating: target app keeps keyboard focus
    }

    /// Makes the panel the key window so it can receive Enter / Escape.
    /// Registers AppKit-level key handlers (more reliable than SwiftUI shortcuts
    /// in a floating NSPanel).
    func makeKey(onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        guard let p = panel else { return }
        p.confirmHandler = onConfirm
        p.cancelHandler  = onCancel
        p.makeKeyAndOrderFront(nil)
    }

    func hide() {
        // Clear handlers so stale callbacks can't fire after the panel is hidden
        panel?.confirmHandler = nil
        panel?.cancelHandler  = nil
        panel?.orderOut(nil)
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
