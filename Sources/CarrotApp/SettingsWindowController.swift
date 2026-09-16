import AppKit
import SunshineUI
import SwiftUI

/// Hosts the settings panes in a plain window via an `NSTabViewController` in
/// `.toolbar` style, which is how native macOS Preferences windows (Mail, Safari,
/// …) show a pane icon in the titlebar toolbar rather than as SwiftUI TabView tabs.
///
/// The app is an accessory (no Dock icon, no app menu), so SwiftUI's `Settings`
/// scene and `SettingsLink` aren't usable here — that's the only place a plain
/// `TabView` gets the native icon+label treatment for free.
@MainActor
final class SettingsWindowController: NSWindowController {
  private let tabViewController: NSTabViewController
  private let updatesTabIndex: Int

  init(scheduler: BreakScheduler, updaterUI: SunshineUpdaterUIController) {
    let tabViewController = NSTabViewController()
    tabViewController.tabStyle = .toolbar
    // The window title is bound to the content view controller's title. The tab
    // controller otherwise copies the selected pane's title, which is nil.
    tabViewController.canPropagateSelectedChildViewControllerTitle = false
    tabViewController.title = "Carrot Settings"

    func addTab(label: String, symbol: String, view: some View) {
      let hostingController = NSHostingController(rootView: view)
      hostingController.sizingOptions = [.preferredContentSize, .minSize]

      let tabItem = NSTabViewItem(viewController: hostingController)
      tabItem.label = label
      tabItem.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
      tabViewController.addTabViewItem(tabItem)
    }

    addTab(label: "General", symbol: "gearshape", view: GeneralSettingsView(scheduler: scheduler))
    addTab(label: "Schedule", symbol: "timer", view: ScheduleSettingsView(scheduler: scheduler))
    addTab(label: "Break", symbol: "eye", view: BreakScreenSettingsView(scheduler: scheduler))
    addTab(
      label: "Updates", symbol: "arrow.down.circle",
      view: ScrollView { SunshineUpdateSettingsView(controller: updaterUI, appName: "Carrot") })
    updatesTabIndex = tabViewController.tabViewItems.count - 1

    let window = NSWindow(contentViewController: tabViewController)
    window.styleMask = [.titled, .closable]
    window.isReleasedWhenClosed = false

    self.tabViewController = tabViewController
    super.init(window: window)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show() {
    if let window, !window.isVisible {
      window.center()
    }
    NSApp.activate(ignoringOtherApps: true)
    showWindow(nil)
  }

  func showUpdatesTab() {
    tabViewController.selectedTabViewItemIndex = updatesTabIndex
    show()
  }
}
