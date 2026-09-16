import AppKit

@MainActor
enum SoundPlayer {
  /// Held so the sound isn't deallocated mid-playback.
  private static var current: NSSound?

  static func play(_ sound: AlertSound, volume: Double) {
    guard let nsSound = NSSound(named: sound.rawValue)?.copy() as? NSSound else { return }

    // Restart cleanly: play() is a no-op on a sound that's already playing.
    current?.stop()

    nsSound.volume = Float(volume)
    current = nsSound
    nsSound.play()
  }
}
