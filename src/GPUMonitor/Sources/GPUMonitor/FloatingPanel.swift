import AppKit
import SwiftUI

/// NSPanel subclass that floats above other windows and is movable by dragging anywhere.
class FloatingPanel: NSPanel {
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: backingStoreType,
            defer: flag
        )

        level = .floating
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        becomesKeyOnlyIfNeeded = true
    }

    override var canBecomeKey: Bool { true }
}

/// AppDelegate that manages window-level behavior.
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
    }

    func setAlwaysOnTop(_ enabled: Bool) {
        guard let window = NSApp.windows.first else { return }
        window.level = enabled ? .floating : .normal
    }
}
