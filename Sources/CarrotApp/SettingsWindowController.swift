import AppKit
import SwiftUI

/// Hosts `SettingsView` in a plain window. The app is an accessory (no Dock icon,
/// no app menu), so SwiftUI's `Settings` scene and `SettingsLink` aren't usable here.
@MainActor
final class SettingsWindowController: NSWindowController {
    convenience init(scheduler: BreakScheduler) {
        let hostingView = NSHostingView(rootView: SettingsView(scheduler: scheduler))
        hostingView.frame.size = hostingView.fittingSize

        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Carrot Settings"
        window.contentView = hostingView
        window.isReleasedWhenClosed = false

        self.init(window: window)
    }

    func show() {
        if let window, !window.isVisible {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
    }
}
