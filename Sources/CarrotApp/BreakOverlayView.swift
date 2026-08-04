import SwiftUI

struct BreakOverlayView: View {
    @ObservedObject var scheduler: BreakScheduler
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
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                Button("Skip", action: onSkip)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
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
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }
}
