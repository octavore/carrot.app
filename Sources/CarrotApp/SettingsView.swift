import ServiceManagement
import SwiftUI

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

                LabeledContent("Play sound when break ends") {
                    Toggle("", isOn: $scheduler.alertSoundEnabled)
                        .labelsHidden()
                }

                if scheduler.alertSoundEnabled {
                    LabeledContent("Alert sound") {
                        HStack {
                            Picker("", selection: $scheduler.alertSound) {
                                ForEach(AlertSound.allCases) { sound in
                                    Text(sound.label).tag(sound)
                                }
                            }
                            .labelsHidden()
                            .onChange(of: scheduler.alertSound) { _, newValue in
                                SoundPlayer.play(newValue, volume: scheduler.alertVolume)
                            }

                            Button {
                                SoundPlayer.play(scheduler.alertSound, volume: scheduler.alertVolume)
                            } label: {
                                Image(systemName: "play.fill")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Slider(value: $scheduler.alertVolume, in: 0...1) {
                        Text("Volume")
                    }
                }

                LabeledContent("Show media controls during breaks") {
                    Toggle("", isOn: $scheduler.mediaControlsEnabled)
                        .labelsHidden()
                }

                LabeledContent("Pause media during breaks") {
                    Toggle("", isOn: $scheduler.autoPauseMediaEnabled)
                        .labelsHidden()
                }

                LabeledContent("Restart after being away") {
                    Toggle("", isOn: $scheduler.autoResetEnabled)
                        .labelsHidden()
                }

                if scheduler.autoResetEnabled {
                    Stepper(value: $scheduler.autoResetIdleMinutes, in: 1...120) {
                        Text("Away for \(scheduler.autoResetIdleMinutes) minutes")
                    }
                }
            }

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    try? newValue
                        ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                }
        }
        .padding(24)
        .frame(width: 360)
    }
}
