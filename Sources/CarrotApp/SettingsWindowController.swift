import AppKit
import SwiftUI

/// Hosts `SettingsView` in a plain window via an `NSTabViewController` in `.toolbar`
/// style, which is how native macOS Preferences windows (Mail, Safari, …) show a
/// pane icon in the titlebar toolbar rather than as SwiftUI TabView tabs.
///
/// The app is an accessory (no Dock icon, no app menu), so SwiftUI's `Settings`
/// scene and `SettingsLink` aren't usable here — that's the only place a plain
/// `TabView` gets the native icon+label treatment for free.
@MainActor
final class SettingsWindowController: NSWindowController {
    convenience init(scheduler: BreakScheduler) {
        let hostingController = NSHostingController(rootView: SettingsView(scheduler: scheduler))
        hostingController.sizingOptions = [.preferredContentSize, .minSize]

        let tabItem = NSTabViewItem(viewController: hostingController)
        tabItem.label = "General"
        tabItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "General")

        let tabViewController = NSTabViewController()
        tabViewController.tabStyle = .toolbar
        tabViewController.addTabViewItem(tabItem)

        let window = NSWindow(contentViewController: tabViewController)
        window.styleMask = [.titled, .closable]
        window.title = "Carrot Settings"
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
