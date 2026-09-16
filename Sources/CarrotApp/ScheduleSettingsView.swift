import SwiftUI

struct ScheduleSettingsView: View {
    @ObservedObject var scheduler: BreakScheduler

    var body: some View {
        Form {
            Section {
                LabeledContent("Break every") {
                    Stepper(value: $scheduler.workIntervalMinutes, in: 1...120) {
                        Text("\(scheduler.workIntervalMinutes) min")
                    }
                }

                LabeledContent("Break length") {
                    Stepper(value: $scheduler.breakDurationSeconds, in: 5...120, step: 5) {
                        Text("\(scheduler.breakDurationSeconds) sec")
                    }
                }
            }

            Section {
                LabeledContent("Restart when away") {
                    Toggle("", isOn: $scheduler.autoResetEnabled)
                        .labelsHidden()
                }

                LabeledContent("Away for") {
                    Stepper(value: $scheduler.autoResetIdleMinutes, in: 1...120) {
                        Text("\(scheduler.autoResetIdleMinutes) min")
                    }
                }
                .disabled(!scheduler.autoResetEnabled)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}
