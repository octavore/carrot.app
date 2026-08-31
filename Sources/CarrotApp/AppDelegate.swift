import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let scheduler = BreakScheduler()
    private let overlayController = BreakOverlayController()
    private let mediaController = MediaController()
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        menuBarController = MenuBarController(scheduler: scheduler)

        scheduler.onBreakStateChange = { [weak self] isOnBreak in
            guard let self else { return }
            if isOnBreak {
                // The helper only runs for the length of a break, and only when
                // a media setting asks for it.
                if self.scheduler.mediaControlsEnabled || self.scheduler.autoPauseMediaEnabled {
                    self.mediaController.beginBreak(
                        autoPause: self.scheduler.autoPauseMediaEnabled
                    )
                }
                self.overlayController.show(scheduler: self.scheduler, media: self.mediaController)
            } else {
                self.mediaController.endBreak()
                self.overlayController.hide()
            }
        }
        scheduler.onBreakFinished = { [weak self] in
            self?.playBreakFinishedSound()
        }
        scheduler.start()
        observeSystemIdleState()
    }

    func applicationWillTerminate(_ notification: Notification) {
        mediaController.stop()
    }

    private func playBreakFinishedSound() {
        guard scheduler.alertSoundEnabled else { return }
        SoundPlayer.play(scheduler.alertSound, volume: scheduler.alertVolume)
    }

    /// Freezes the countdown while the display or computer is asleep or the
    /// screensaver is running, so time spent away from the screen doesn't count
    /// toward the next break. If that stretch of idleness is long enough, the
    /// scheduler also restarts the countdown from scratch (see
    /// `BreakScheduler.autoResetEnabled`). Display/system sleep and wake come
    /// from `NSWorkspace`; the screensaver only announces itself via distributed
    /// notifications, since it runs as a separate process outside any app's
    /// control.
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
        workspaceCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [scheduler] _ in
            MainActor.assumeIsolated { scheduler.systemDidBecomeIdle(.systemAsleep) }
        }
        workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [scheduler] _ in
            MainActor.assumeIsolated { scheduler.systemDidBecomeActive(.systemAsleep) }
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
