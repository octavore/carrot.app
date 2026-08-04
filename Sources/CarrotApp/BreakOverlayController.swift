import AppKit
import SwiftUI

/// Puts one borderless, click-through-disabled window over every connected
/// screen while a break is in progress, and tears them down afterwards.
/// Borderless windows can't become key by default, which would prevent them
/// from receiving key events needed to dismiss the "break complete" overlay.
private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class BreakOverlayController {
    private var windows: [NSWindow] = []
    private var keyMonitor: Any?

    func show(scheduler: BreakScheduler) {
        guard windows.isEmpty else { return }

        windows = NSScreen.screens.map { screen in
            let window = OverlayWindow(
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

        // Any key dismisses the overlay once the break is over. This has to be a
        // monitor rather than SwiftUI's `.onKeyPress`, which only fires for a
        // focused view — the hosting view in a borderless window never is.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let dismissed = MainActor.assumeIsolated { () -> Bool in
                guard self?.windows.isEmpty == false, scheduler.breakFinished else { return false }
                scheduler.skipBreak()
                return true
            }
            return dismissed ? nil : event
        }
    }

    func hide() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}
