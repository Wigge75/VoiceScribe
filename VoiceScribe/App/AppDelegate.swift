// AppDelegate.swift
// Handles NSApplication lifecycle events that aren't covered by SwiftUI's App protocol.

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Menu bar apps must keep running when the Settings window is closed.
        return false
    }
}
