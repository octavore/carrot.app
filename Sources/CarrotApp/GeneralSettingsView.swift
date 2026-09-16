import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var scheduler: BreakScheduler
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                LabeledContent("Launch at login") {
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .onChange(of: launchAtLogin) { _, newValue in
                            try? newValue
                                ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                        }
                }
            }

            Section {
                LabeledContent("Menu bar countdown") {
                    Picker("", selection: $scheduler.timeDisplayFormat) {
                        ForEach(TimeDisplayFormat.allCases) { format in
                            Text(format.label).tag(format)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}
