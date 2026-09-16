import Combine
import Foundation

/// Reads and drives the system "now playing" state, the same state Control
/// Center shows.
///
/// None of this can be done in-process. Since macOS 15.4 the private
/// MediaRemote framework only answers processes whose code-signing identifier
/// starts with `com.apple.`, and Carrot is a Developer ID app, so a direct call
/// returns an empty dictionary. Instead a small dylib we ship is loaded into
/// `/usr/bin/perl` (identifier `com.apple.perl`) and talks to MediaRemote from
/// there, reporting back as JSON lines. See
/// `research/2026-08-31-mediaremote-perl-adapter.md`.
@MainActor
final class MediaController: ObservableObject {
  /// False when the helper can't run at all, which is the expected outcome if
  /// a future macOS drops `/usr/bin/perl` or starts enforcing library
  /// validation on it. Callers hide their media UI rather than showing dead
  /// controls.
  @Published private(set) var available = false
  @Published private(set) var isPlaying = false
  @Published private(set) var title: String?
  @Published private(set) var artist: String?

  /// True when there is something for the user to control: media is playing,
  /// or this break paused media that it can resume. False when nothing was
  /// playing at the start of the break, which is when callers hide their
  /// media UI. A stale title left over from a stopped player does not count.
  var hasTrack: Bool { isPlaying || sawPlaybackThisBreak }

  /// MediaRemote command ids.
  private enum Command: Int {
    case play = 0
    case pause = 1
  }

  /// Set when a break paused media that was playing, so the same break can put
  /// it back and nothing else does.
  private var didAutoPause = false

  /// Latched true once the helper reports playback during a break, so pausing
  /// from the overlay button does not make the controls disappear. Reset at
  /// each break boundary.
  @Published private(set) var sawPlaybackThisBreak = false

  /// Set when a break has started and the auto-pause decision is still waiting
  /// on the helper's first report of what is playing.
  private var pendingAutoPause = false

  private var streamProcess: Process?
  private let perlPath = "/usr/bin/perl"

  private struct Payload: Decodable {
    var playing: Bool
    var title: String?
    var artist: String?
    var album: String?
  }

  // MARK: - Bundled helper paths

  private static let scriptURL = Bundle.main.url(
    forResource: "carrot-media", withExtension: "pl"
  )

  /// `embed_libs` puts the dylib in Contents/Frameworks, alongside the other
  /// embedded libraries rather than in Resources.
  private static let libraryURL = Bundle.main.privateFrameworksURL?
    .appendingPathComponent("libCarrotMediaShim.dylib")

  private static var helper: (script: URL, library: URL)? {
    guard let scriptURL, let libraryURL,
      FileManager.default.fileExists(atPath: scriptURL.path),
      FileManager.default.fileExists(atPath: libraryURL.path)
    else { return nil }
    return (scriptURL, libraryURL)
  }

  // MARK: - Lifecycle

  /// Brings the helper up for the duration of a break and, if asked, pauses
  /// whatever is playing.
  ///
  /// The pause cannot be decided here: the helper has only just been spawned
  /// and nothing is known about the session yet. It is deferred to the first
  /// state the helper reports, which it emits immediately on startup. Cold
  /// start is 14-20ms, so the pause lands well inside the first second of the
  /// break.
  func beginBreak(autoPause: Bool) {
    pendingAutoPause = autoPause
    sawPlaybackThisBreak = false
    start()
  }

  /// Resumes anything this break paused and shuts the helper down. Safe to
  /// call whether or not `beginBreak` ran.
  func endBreak() {
    resumeAfterBreak()
    stop()
  }

  /// Starts the helper that reports every change in now-playing state.
  /// MediaRemote pushes real notifications, so there is nothing to poll and
  /// the process costs nothing while it waits.
  private func start() {
    guard streamProcess == nil, let helper = Self.helper else { return }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: perlPath)
    process.arguments = [helper.script.path, helper.library.path, "stream"]

    let output = Pipe()
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice

    // The helper exits on its own only if MediaRemote is unreachable, which
    // is also the one case where we want to give up rather than respawn.
    process.terminationHandler = { [weak self] _ in
      Task { @MainActor in
        self?.streamProcess = nil
        self?.available = false
        self?.isPlaying = false
      }
    }

    do {
      try process.run()
    } catch {
      available = false
      return
    }

    streamProcess = process
    available = true
    readLines(from: output.fileHandleForReading)
  }

  func stop() {
    pendingAutoPause = false
    sawPlaybackThisBreak = false
    guard let streamProcess else { return }
    self.streamProcess = nil
    streamProcess.terminationHandler = nil
    streamProcess.terminate()

    // Nothing is reporting state any more, so drop it rather than leave the
    // last known track showing behind a control that no longer works.
    available = false
    isPlaying = false
    title = nil
    artist = nil
  }

  /// Accumulates helper output and hands back whole lines. `readabilityHandler`
  /// delivers whatever has arrived, which is not necessarily a whole number of
  /// lines, so a partial trailing line is held until the rest shows up.
  ///
  /// A lock rather than an actor because `readabilityHandler` is a
  /// synchronous, non-isolated callback with nowhere to await.
  private final class LineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func take(_ chunk: Data) -> [Data] {
      lock.lock()
      defer { lock.unlock() }
      data.append(chunk)

      var lines: [Data] = []
      while let newline = data.firstIndex(of: UInt8(ascii: "\n")) {
        lines.append(data[data.startIndex..<newline])
        data.removeSubrange(data.startIndex...newline)
      }
      return lines
    }
  }

  private func readLines(from handle: FileHandle) {
    let buffer = LineBuffer()
    handle.readabilityHandler = { handle in
      let chunk = handle.availableData
      guard !chunk.isEmpty else {
        handle.readabilityHandler = nil
        return
      }
      for line in buffer.take(chunk) {
        guard let payload = try? JSONDecoder().decode(Payload.self, from: line) else {
          continue
        }
        Task { @MainActor [weak self] in self?.apply(payload) }
      }
    }
  }

  private func apply(_ payload: Payload) {
    isPlaying = payload.playing
    title = payload.title
    artist = payload.artist
    if payload.playing { sawPlaybackThisBreak = true }

    // The first report after a break starts is what the auto-pause decision
    // was waiting for. Later reports are just the overlay tracking changes.
    if pendingAutoPause {
      pendingAutoPause = false
      if payload.playing {
        send(.pause)
        didAutoPause = true
      }
    }
  }

  // MARK: - Commands

  /// Each command is its own short-lived helper process. They are rare (a
  /// break boundary, or a click on the overlay button), and the alternative,
  /// keeping a writable channel into the stream process, buys nothing.
  private func send(_ command: Command) {
    guard available, let helper = Self.helper else { return }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: perlPath)
    process.arguments = [helper.script.path, helper.library.path, "send"]
    process.environment = ProcessInfo.processInfo.environment.merging(
      ["CARROT_COMMAND": String(command.rawValue)]
    ) { _, new in new }
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try? process.run()
  }

  /// Toggles playback from the overlay button. Sent as an explicit play or
  /// pause rather than MediaRemote's toggle, so the result matches the state
  /// the button was showing even if the two have drifted apart.
  func togglePlayPause() {
    send(isPlaying ? .pause : .play)
  }

  /// Resumes playback only if this controller paused it for the break. If the
  /// user restarted playback themselves during the break, that counts as
  /// taking over and the resume is dropped.
  ///
  /// Called before the helper is shut down, while `available` is still true,
  /// since `send` needs it.
  private func resumeAfterBreak() {
    defer { didAutoPause = false }
    guard didAutoPause, !isPlaying else { return }
    send(.play)
  }
}
