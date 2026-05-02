// TextInserter.swift
// Inserts text at the cursor position using three strategies (in order):
//
// Strategy 1a — Pre-captured AX element (best):
//   Uses an AXUIElement captured BEFORE the panel appeared (cursor was in target app).
//   Works even after the panel takes keyboard focus during the preview step.
//
// Strategy 1b — Live AX lookup:
//   Sets kAXSelectedTextAttribute on the currently focused element of the target PID.
//   Fallback when no element was captured (Accessibility not yet granted at recording start).
//
// Strategy 2 — Clipboard + CMD+V:
//   Universal fallback for apps that don't expose kAXSelectedText.
//   Saves clipboard → writes text → activates target app → simulates CMD+V → restores.

import AppKit
import ApplicationServices

@MainActor
final class TextInserter {

    // MARK: - Public Insert (with pre-captured element)

    /// Primary insert method.  Tries the saved element first, then live AX, then clipboard.
    func insert(_ text: String, into element: AXUIElement?, targetApp: NSRunningApplication?) async {
        // Strategy 1a: saved element (cursor position captured before panel showed)
        if let el = element {
            let result = AXUIElementSetAttributeValue(
                el,
                kAXSelectedTextAttribute as CFString,
                text as CFTypeRef
            )
            if result == .success { return }
        }

        // Strategy 1b: live AX lookup on target PID
        if let app = targetApp, !app.isTerminated {
            if tryAccessibility(text: text, pid: app.processIdentifier) { return }
        }

        // Strategy 2: clipboard + CMD+V
        await clipboardInsert(text: text, targetApp: targetApp)
    }

    /// Convenience overload used when no element was captured.
    func insert(_ text: String, into targetApp: NSRunningApplication?) async {
        await insert(text, into: nil, targetApp: targetApp)
    }

    // MARK: - Focused Element Capture

    /// Captures the currently focused AX element for a given PID.
    /// Call this BEFORE showing the panel so the cursor is still in the target app.
    /// Returns nil if Accessibility permission is not yet granted.
    func captureFocusedElement(pid: pid_t) -> AXUIElement? {
        guard AXIsProcessTrusted() else { return nil }

        let appElement = AXUIElementCreateApplication(pid)
        var focusedRaw: AnyObject?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRaw
        ) == .success else { return nil }

        // swiftlint:disable force_cast
        return (focusedRaw as! AXUIElement)
    }

    // MARK: - Accessibility helpers (used by SettingsView)

    func isAccessibilityTrusted() -> Bool { AXIsProcessTrusted() }

    func requestAccessibilityPermission() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }

    // MARK: - Strategy 1b: Live AX Lookup

    private func tryAccessibility(text: String, pid: pid_t) -> Bool {
        guard AXIsProcessTrusted() else { return false }

        let appElement = AXUIElementCreateApplication(pid)
        var focusedRaw: AnyObject?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRaw
        ) == .success else { return false }

        // swiftlint:disable force_cast
        let element = focusedRaw as! AXUIElement

        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )

        return result == .success
    }

    // MARK: - Strategy 2: Clipboard + CMD+V

    private func clipboardInsert(text: String, targetApp: NSRunningApplication?) async {
        let pb = NSPasteboard.general

        // 1. Save current clipboard
        let saved = savedPasteboardContents()

        // 2. Write text to clipboard
        pb.clearContents()
        pb.setString(text, forType: .string)

        // 3. Activate the target app immediately.
        //    Because the panel was non-activating, the target app is still the
        //    active (frontmost) app. activate() ensures its window becomes key again.
        if let app = targetApp, !app.isTerminated {
            app.activate(options: [])
        }

        // 4. Wait for the window to receive keyboard focus
        try? await Task.sleep(nanoseconds: 600_000_000)   // 600 ms

        // 5. Simulate CMD+V
        simulateCmdV()

        // 6. Wait for the paste event to be processed
        try? await Task.sleep(nanoseconds: 300_000_000)   // 300 ms

        // 7. Restore original clipboard
        restorePasteboard(saved)
    }

    private func simulateCmdV() {
        let source  = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags   = .maskCommand
        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)
    }

    // MARK: - Clipboard save / restore

    private struct SavedItem {
        let type: NSPasteboard.PasteboardType
        let data: Data
    }

    private func savedPasteboardContents() -> [[SavedItem]] {
        let pb = NSPasteboard.general
        return (pb.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in
                item.data(forType: type).map { SavedItem(type: type, data: $0) }
            }
        }
    }

    private func restorePasteboard(_ saved: [[SavedItem]]) {
        let pb = NSPasteboard.general
        pb.clearContents()
        guard !saved.isEmpty else { return }
        pb.writeObjects(saved.map { items in
            let item = NSPasteboardItem()
            items.forEach { item.setData($0.data, forType: $0.type) }
            return item
        })
    }
}
