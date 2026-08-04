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
    }
}
