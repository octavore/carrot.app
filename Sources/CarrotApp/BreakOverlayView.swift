import SwiftUI

struct BreakOverlayView: View {
    @ObservedObject var scheduler: BreakScheduler
    @ObservedObject var media: MediaController
    let onSkip: () -> Void
    let onSnooze: () -> Void
    let onDismiss: () -> Void

    @State private var hasAppeared = false
    @State private var checkmarkScale: CGFloat = 0.7
    @State private var checkmarkOpacity: Double = 0
    @State private var flashOpacity: Double = 0

    /// Tune this to make the background blur stronger or weaker.
    private let blurRadius: CGFloat = 20

    /// Peak opacity of the white flash when the break finishes. Kept low so it
    /// reads as a soft pulse rather than a camera flash.
    private let flashPeakOpacity: Double = 0.18

    private var tintOpacity: Double {
        guard hasAppeared else { return 0 }
        return scheduler.breakFinished ? 0.15 : 0.4
    }

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blurRadius: blurRadius)
                .opacity(hasAppeared ? 1 : 0)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.7), value: hasAppeared)

            Color.black
                .opacity(tintOpacity)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.7), value: hasAppeared)
                .animation(.easeInOut(duration: 0.5), value: scheduler.breakFinished)

            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if scheduler.breakFinished {
                finishedContent
            } else {
                countdownContent
            }

            if scheduler.showTimeOnBreakScreen {
                VStack {
                    Spacer()
                    Text(Date(), style: .time)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.bottom, 20)
                }
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { hasAppeared = true }
        .onChange(of: scheduler.breakFinished) { _, finished in
            if finished {
                playFinish()
            } else {
                checkmarkScale = 0.7
                checkmarkOpacity = 0
            }
        }
    }

    /// Pops the checkmark in and pulses the background white once.
    private func playFinish() {
        // Low damping so the scale overshoots slightly before settling — that
        // overshoot is what reads as a "pop".
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
            checkmarkScale = 1
            checkmarkOpacity = 1
        }

        // Fast ramp up, slow fade out, so the flash feels like a pulse of light
        // rather than a symmetrical blink.
        withAnimation(.easeOut(duration: 0.12)) {
            flashOpacity = flashPeakOpacity
        }
        withAnimation(.easeIn(duration: 0.5).delay(0.12)) {
            flashOpacity = 0
        }
    }

    private var countdownContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "eye.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.85))

            Text("Look 20 feet away")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)

            Text("Give your eyes a rest for a few seconds")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.6))

            Text("\(scheduler.secondsRemaining)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .padding(.vertical, 8)

            HStack(spacing: 16) {
                Button("Snooze 5 min", action: onSnooze)
                    .buttonStyle(PillButtonStyle())
                Button("Skip", action: onSkip)
                    .buttonStyle(PillButtonStyle(prominent: true))
            }

            if scheduler.mediaControlsEnabled && media.available && media.hasTrack {
                mediaControls
                    .padding(.top, 8)
            }
        }
    }

    /// Shown only when there is a track to control, including one this break
    /// paused, so the user can resume it without leaving the overlay. Hidden
    /// when nothing is playing or loaded.
    private var mediaControls: some View {
        HStack(spacing: 12) {
            Button(action: media.togglePlayPause) {
                Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15))
                    .frame(width: 20)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 1) {
                Text(media.title ?? "Nothing playing")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(media.title == nil ? 0.5 : 0.9))
                if let artist = media.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: 320)
        .background(.white.opacity(0.1), in: Capsule())
    }

    private var finishedContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.9))
                .scaleEffect(checkmarkScale)
                .opacity(checkmarkOpacity)

            Text("Break complete")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)

            Text("Whenever you're ready")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.6))

            Button("Continue Working", action: onDismiss)
                .buttonStyle(PillButtonStyle(prominent: true))
        }
    }
}

/// Large pill-shaped button used on the break overlay. `prominent` fills the
/// pill solid white; the non-prominent variant is a translucent outline so it
/// reads as secondary against the blurred background.
private struct PillButtonStyle: ButtonStyle {
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(minWidth: 130, minHeight: 22)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(prominent ? Color.accentColor : Color.white.opacity(0.14))
            )
            .overlay(
                Capsule()
                    .strokeBorder(.white.opacity(prominent ? 0 : 0.3), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
