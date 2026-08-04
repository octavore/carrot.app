import SwiftUI

@main
struct CarrotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The UI is the status item, built in `AppDelegate`. `App` still requires a
        // scene, and this one never shows because the app runs as an accessory.
        Settings {
            EmptyView()
        }
    }
}
