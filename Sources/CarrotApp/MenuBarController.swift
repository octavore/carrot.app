import AppKit
import Combine
import SwiftUI

/// Owns the status bar item. Uses AppKit directly rather than SwiftUI's `MenuBarExtra`
/// because that renders its label with the system menu bar font and drops font
/// modifiers, so `.monospacedDigit()` never applied and the countdown jittered.
@MainActor
final class MenuBarController: NSObject {
    private let scheduler: BreakScheduler
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var cancellable: AnyCancellable?

    private let statusMenuItem = NSMenuItem()
    private let pauseMenuItem = NSMenuItem()
    private let restartMenuItem = NSMenuItem()
    private let breakNowMenuItem = NSMenuItem()

    private lazy var settingsWindowController = SettingsWindowController(scheduler: scheduler)

    private static let titleFont: NSFont = .monospacedDigitSystemFont(
        ofSize: NSFont.menuBarFont(ofSize: 0).pointSize,
        weight: .regular
    )

    init(scheduler: BreakScheduler) {
        self.scheduler = scheduler
        super.init()

        buildMenu()

        // `objectWillChange` fires before the properties are updated, so hop to the
        // next run loop pass to read the new values.
        cancellable = scheduler.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.refresh() }

        refresh()
    }

    private func buildMenu() {
        let menu = NSMenu()

        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        pauseMenuItem.target = self
        pauseMenuItem.action = #selector(togglePause)
        menu.addItem(pauseMenuItem)

        restartMenuItem.title = "Restart"
        restartMenuItem.target = self
        restartMenuItem.action = #selector(restart)
        menu.addItem(restartMenuItem)

        breakNowMenuItem.title = "Take a Break Now"
        breakNowMenuItem.target = self
        breakNowMenuItem.action = #selector(startBreakNow)
        menu.addItem(breakNowMenuItem)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Carrot", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        // Items are enabled/disabled explicitly in `refresh()`.
        menu.autoenablesItems = false
        statusItem.menu = menu
    }

    private func refresh() {
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: scheduler.isOnBreak ? "carrot.fill" : "carrot",
                accessibilityDescription: "Carrot"
            )
            button.imagePosition = .imageLeading
            button.attributedTitle = NSAttributedString(
                string: scheduler.isPaused ? " …" : " \(scheduler.timeString)",
                attributes: [.font: Self.titleFont]
            )
        }

        if scheduler.isPaused {
            statusMenuItem.title = "Paused for \(scheduler.pausedTimeString)"
        } else if scheduler.isOnBreak {
            statusMenuItem.title = "On break: \(scheduler.timeString)"
        } else {
            statusMenuItem.title = "Next break in \(scheduler.timeString)"
        }

        pauseMenuItem.title = scheduler.isPaused ? "Resume" : "Pause"
        restartMenuItem.isHidden = !scheduler.isPaused
        breakNowMenuItem.isEnabled = !scheduler.isOnBreak
    }

    @objc private func togglePause() {
        scheduler.togglePause()
    }

    @objc private func restart() {
        scheduler.restart()
    }

    @objc private func startBreakNow() {
        scheduler.startBreakNow()
    }

    @objc private func openSettings() {
        settingsWindowController.show()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
