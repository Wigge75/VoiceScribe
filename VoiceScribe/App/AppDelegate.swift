// AppDelegate.swift
// Handles NSApplication lifecycle events that aren't covered by SwiftUI's App protocol.

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // MenuBarExtra (macOS 13+) manages the activation policy internally.
        // Do NOT call setActivationPolicy here — it overrides MenuBarExtra's setup
        // and prevents the icon from appearing in the menu bar.
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Menu bar apps must keep running when the Settings window is closed.
        return false
    }
}
