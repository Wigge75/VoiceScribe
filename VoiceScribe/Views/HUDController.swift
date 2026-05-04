// HUDController.swift
// Zeigt kurz ein kleines Icon-Overlay wenn der Nutzer per Shortcut
// den Modus oder Stil wechselt. Verschwindet automatisch nach 1,5 Sek.

import SwiftUI
import AppKit

@MainActor
final class HUDController {

    private var window:      NSWindow?
    private var dismissTask: Task<Void, Never>?

    private let hudSize = CGSize(width: 64, height: 64)

    func show(icon: String) {
        dismissTask?.cancel()

        if window == nil {
            let win = NSWindow(
                contentRect: CGRect(origin: .zero, size: hudSize),
                styleMask:   [.borderless],
                backing:     .buffered,
                defer:       false
            )
            win.isOpaque           = false
            win.backgroundColor    = .clear
            win.level              = .floating
            win.ignoresMouseEvents = true
            win.collectionBehavior = [.canJoinAllSpaces, .stationary]
            window = win
        }

        let host = NSHostingView(rootView: HUDView(icon: icon))
        host.wantsLayer = true
        host.layer?.backgroundColor = CGColor.clear
        host.frame = CGRect(origin: .zero, size: hudSize)

        window?.contentView = host
        window?.setContentSize(hudSize)

        // Unter der Menüleiste, horizontal zentriert
        if let screen = NSScreen.main {
            let menuBarHeight = NSStatusBar.system.thickness
            let x = screen.frame.midX - hudSize.width / 2
            let y = screen.frame.maxY - menuBarHeight - hudSize.height - 16
            window?.setFrameOrigin(NSPoint(x: x, y: y))
        }

        window?.alphaValue = 0
        window?.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            window?.animator().alphaValue = 1
        }

        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            await self?.hide()
        }
    }

    private func hide() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            window?.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
        })
    }
}

// MARK: - HUD View

private struct HUDView: View {
    let icon: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )

            Image(systemName: icon)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.primary)
        }
        .frame(width: 64, height: 64)
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
    }
}
