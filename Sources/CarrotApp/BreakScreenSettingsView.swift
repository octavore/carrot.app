import SwiftUI

struct BreakScreenSettingsView: View {
  @ObservedObject var scheduler: BreakScheduler

  var body: some View {
    Form {
      Section {
        LabeledContent("Show clock") {
          Toggle("", isOn: $scheduler.showTimeOnBreakScreen)
            .labelsHidden()
        }
      }

      Section {
        LabeledContent("Show media controls") {
          VStack(alignment: .leading, spacing: 4) {
            Toggle("", isOn: $scheduler.mediaControlsEnabled)
              .labelsHidden()
            Text("Experimental. May not work with every app.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        LabeledContent("Pause media") {
          Toggle("", isOn: $scheduler.autoPauseMediaEnabled)
            .labelsHidden()
        }
      }

      Section {
        LabeledContent("Play when break ends") {
          Toggle("", isOn: $scheduler.alertSoundEnabled)
            .labelsHidden()
        }

        Group {
          LabeledContent("Sound") {
            HStack {
              Picker("", selection: $scheduler.alertSound) {
                ForEach(AlertSound.allCases) { sound in
                  Text(sound.label).tag(sound)
                }
              }
              .labelsHidden()
              .fixedSize()
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

          LabeledContent("Volume") {
            Slider(value: $scheduler.alertVolume, in: 0...1)
          }
        }
        .disabled(!scheduler.alertSoundEnabled)
      }
    }
    .padding(24)
    .frame(width: 380)
  }
}
