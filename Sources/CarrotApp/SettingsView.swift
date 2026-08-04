import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var scheduler: BreakScheduler
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(spacing: 16) {
            Form {
                Stepper(value: $scheduler.workIntervalMinutes, in: 1...120) {
                    Text("Break every \(scheduler.workIntervalMinutes) minutes")
                }

                Stepper(value: $scheduler.breakDurationSeconds, in: 5...120, step: 5) {
                    Text("Break duration: \(scheduler.breakDurationSeconds) seconds")
                }

                Picker("Countdown display", selection: $scheduler.timeDisplayFormat) {
                    ForEach(TimeDisplayFormat.allCases) { format in
                        Text(format.label).tag(format)
                    }
                }
            }

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    try? newValue ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                }
        }
        .padding(24)
        .frame(width: 320)
    }
}
