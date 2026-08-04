import AppKit
import SwiftUI

/// Puts one borderless, click-through-disabled window over every connected
/// screen while a break is in progress, and tears them down afterwards.
@MainActor
final class BreakOverlayController {
    private var windows: [NSWindow] = []

    func show(scheduler: BreakScheduler) {
        guard windows.isEmpty else { return }

        windows = NSScreen.screens.map { screen in
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.contentView = NSHostingView(
                rootView: BreakOverlayView(
                    scheduler: scheduler,
                    onSkip: { scheduler.skipBreak() },
                    onSnooze: { scheduler.snoozeBreak() },
                    onDismiss: { scheduler.skipBreak() }
                )
            )
            window.setFrame(screen.frame, display: true)
            return window
        }

        NSApp.activate(ignoringOtherApps: true)
        windows.forEach { $0.makeKeyAndOrderFront(nil) }
    }

    func hide() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}
