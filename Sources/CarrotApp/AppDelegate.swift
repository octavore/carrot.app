import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let scheduler = BreakScheduler()
    private let overlayController = BreakOverlayController()
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        menuBarController = MenuBarController(scheduler: scheduler)

        scheduler.onBreakStateChange = { [weak self] isOnBreak in
            guard let self else { return }
            if isOnBreak {
                self.overlayController.show(scheduler: self.scheduler)
            } else {
                self.overlayController.hide()
            }
        }
        scheduler.start()
        observeSystemIdleState()
    }

    /// Freezes the countdown while the display is asleep or the screensaver is
    /// running, so time spent away from the screen doesn't count toward the
    /// next break. Display sleep/wake come from `NSWorkspace`; the screensaver
    /// only announces itself via distributed notifications, since it runs as a
    /// separate process outside any app's control.
    private func observeSystemIdleState() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main
        ) { [scheduler] _ in
            MainActor.assumeIsolated { scheduler.systemDidBecomeIdle(.displayAsleep) }
        }
        workspaceCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main
        ) { [scheduler] _ in
            MainActor.assumeIsolated { scheduler.systemDidBecomeActive(.displayAsleep) }
        }

        let distributedCenter = DistributedNotificationCenter.default()
        distributedCenter.addObserver(
            forName: Notification.Name("com.apple.screensaver.didstart"), object: nil, queue: .main
        ) { [scheduler] _ in
            MainActor.assumeIsolated { scheduler.systemDidBecomeIdle(.screenSaverActive) }
        }
        distributedCenter.addObserver(
            forName: Notification.Name("com.apple.screensaver.didstop"), object: nil, queue: .main
        ) { [scheduler] _ in
            MainActor.assumeIsolated { scheduler.systemDidBecomeActive(.screenSaverActive) }
        }
    }
}
