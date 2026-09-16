import AppKit
import Combine
import SunshineUI
import SwiftUI

/// Owns the status bar item. Uses AppKit directly rather than SwiftUI's `MenuBarExtra`
/// because that renders its label with the system menu bar font and drops font
/// modifiers, so `.monospacedDigit()` never applied and the countdown jittered.
@MainActor
final class MenuBarController: NSObject {
  private let scheduler: BreakScheduler
  private let updaterUI: SunshineUpdaterUIController
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private var cancellable: AnyCancellable?

  private let statusMenuItem = NSMenuItem()
  private let pauseMenuItem = NSMenuItem()
  private let restartMenuItem = NSMenuItem()
  private let breakNowMenuItem = NSMenuItem()
  private let checkForUpdatesMenuItem = NSMenuItem()

  /// Small red dot pinned over the status item's icon while an update is pending,
  /// so a found update is visible without opening the menu.
  private let updateBadgeView: NSView = {
    let view = NSView()
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.systemRed.cgColor
    view.layer?.cornerRadius = 3
    view.isHidden = true
    return view
  }()

  private lazy var settingsWindowController = SettingsWindowController(
    scheduler: scheduler, updaterUI: updaterUI)

  private static let titleFont: NSFont = .monospacedDigitSystemFont(
    ofSize: NSFont.menuBarFont(ofSize: 0).pointSize,
    weight: .regular
  )

  init(scheduler: BreakScheduler, updaterUI: SunshineUpdaterUIController) {
    self.scheduler = scheduler
    self.updaterUI = updaterUI
    super.init()

    buildMenu()
    statusItem.button?.addSubview(updateBadgeView)

    // `objectWillChange` fires before the properties are updated, so hop to the
    // next run loop pass to read the new values.
    cancellable = Publishers.Merge(scheduler.objectWillChange, updaterUI.objectWillChange)
      .receive(on: RunLoop.main)
      .sink { [weak self] in self?.refresh() }

    refresh()
  }

  private func buildMenu() {
    let menu = NSMenu()

    statusMenuItem.isEnabled = false
    menu.addItem(statusMenuItem)
    menu.addItem(.separator())

    breakNowMenuItem.title = "Take a Break Now"
    breakNowMenuItem.target = self
    breakNowMenuItem.action = #selector(startBreakNow)
    menu.addItem(breakNowMenuItem)

    restartMenuItem.title = "Restart"
    restartMenuItem.target = self
    restartMenuItem.action = #selector(restart)
    menu.addItem(restartMenuItem)

    pauseMenuItem.target = self
    pauseMenuItem.action = #selector(togglePause)
    menu.addItem(pauseMenuItem)

    menu.addItem(.separator())

    let settings = NSMenuItem(
      title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
    settings.target = self
    menu.addItem(settings)

    checkForUpdatesMenuItem.target = self
    checkForUpdatesMenuItem.action = #selector(checkForUpdates)
    menu.addItem(checkForUpdatesMenuItem)

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

    pauseMenuItem.title = scheduler.isPaused ? "Resume breaks" : "Pause breaks"
    breakNowMenuItem.isEnabled = !scheduler.isOnBreak

    let updatePending = updaterUI.pendingUpdate != nil
    checkForUpdatesMenuItem.title = updatePending ? "Update Available…" : "Check for Updates…"

    let badgeDiameter: CGFloat = 6
    updateBadgeView.frame = NSRect(
      x: 9, y: NSStatusBar.system.thickness - badgeDiameter - 3,
      width: badgeDiameter, height: badgeDiameter)
    updateBadgeView.isHidden = !updatePending
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

  @objc private func checkForUpdates() {
    settingsWindowController.showUpdatesTab()
  }

  @objc private func quit() {
    NSApplication.shared.terminate(nil)
  }
}
