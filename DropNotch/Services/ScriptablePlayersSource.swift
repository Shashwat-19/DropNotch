import AppKit
import os

/// Now Playing for Music and Spotify (D22–D24). Track info comes from the players' distributed
/// notifications and needs no permission; commands go through `AppleEventSending`. No timers: everything
/// here runs because a player or `NSWorkspace` said something.
///
/// Swift/AppKit notes:
/// - `NSObject` because the selector-based `addObserver` is the only one that can set
///   `.deliverImmediately` (D24).
/// - The `@objc` handlers are `nonisolated`: AppKit calls them directly, so the compiler can't vouch for
///   the thread. They parse there and hop to the main actor for the state.
@MainActor
final class ScriptablePlayersSource: NSObject, NowPlayingSource {
    private let sender: any AppleEventSending
    private let runningPID: (MediaPlayer) -> pid_t?
    private var selection = NowPlayingSelection()
    private var continuation: AsyncStream<NowPlayingInfo?>.Continuation?
    private var lastPublished: NowPlayingInfo?
    /// Bumped per subscription, so a late reply or `onTermination` from an old stream can't touch the new one.
    private var generation = 0

    init(sender: any AppleEventSending = AppleEventSender(),
         runningPID: @escaping (MediaPlayer) -> pid_t? = {
             NSRunningApplication.runningApplications(withBundleIdentifier: $0.bundleID).first?.processIdentifier
         }) {
        self.sender = sender
        self.runningPID = runningPID
    }

    /// Whether observers are installed. Internal for tests.
    var isObserving: Bool { continuation != nil }

    /// Each read starts observing for a new stream (ending the previous one); the observers go when it ends.
    var updates: AsyncStream<NowPlayingInfo?> {
        stopObserving()
        generation += 1
        let generation = generation
        let (stream, continuation) = AsyncStream.makeStream(of: NowPlayingInfo?.self)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                if self?.generation == generation { self?.stopObserving() }
            }
        }
        self.continuation = continuation
        startObserving(generation: generation)
        return stream
    }

    func send(_ command: PlaybackCommand, to player: MediaPlayer) async -> AppleEventOutcome {
        // Never launch a player: only a running one gets events, addressed by pid (D22).
        guard let pid = runningPID(player) else { return .notRunning }
        // Shows the system prompt the first time; after the user has answered it returns at once (D23).
        var outcome = await sender.permission(for: player, pid: pid, ask: true)
        if outcome == .ok { outcome = await sender.send(command, to: player, pid: pid) }
        Logger.nowPlaying.info("Command to \(player.bundleID, privacy: .public): \(String(describing: outcome), privacy: .public)")
        return outcome
    }

    /// A parsed player notification. Internal so tests can drive it without posting distributed notifications.
    func receive(_ info: NowPlayingInfo, carriesTrack: Bool) {
        guard isObserving else { return }
        Logger.nowPlaying.debug("\(info.player.bundleID, privacy: .public) reported \(String(describing: info.state), privacy: .public)")
        selection.report(info, carriesTrack: carriesTrack)
        publish()
    }

    /// A player launched or quit. Internal for tests.
    func playerRunningChanged(_ player: MediaPlayer, isRunning: Bool) {
        guard isObserving else { return }
        if isRunning { selection.launched(player) } else { selection.quit(player) }
        publish()
    }

    private func startObserving(generation: Int) {
        selection = NowPlayingSelection()
        for player in MediaPlayer.allCases {
            // `.deliverImmediately`: AppKit may hold distributed notifications back while the app is
            // inactive, and DropNotch almost always is (D24).
            DistributedNotificationCenter.default().addObserver(
                self, selector: #selector(playerChanged(_:)), name: player.notificationName,
                object: nil, suspensionBehavior: .deliverImmediately)
        }
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(appLaunched(_:)),
                              name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        workspace.addObserver(self, selector: #selector(appQuit(_:)),
                              name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        for player in MediaPlayer.allCases {
            guard let pid = runningPID(player) else { continue }
            selection.launched(player)
            Task { await fetchCurrent(player, pid: pid, generation: generation) }
        }
        publish()
    }

    private func stopObserving() {
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        continuation?.finish()
        continuation = nil
        lastPublished = nil
    }

    /// The one-off read at start, so a player that is already playing shows its track (D23).
    private func fetchCurrent(_ player: MediaPlayer, pid: pid_t, generation: Int) async {
        // `ask: false`: never a prompt at start; read only if the user allowed it before.
        let permission = await sender.permission(for: player, pid: pid, ask: false)
        Logger.nowPlaying.debug("Start check for \(player.bundleID, privacy: .public): \(String(describing: permission), privacy: .public)")
        guard permission == .ok, let info = await sender.readCurrent(of: player, pid: pid),
              generation == self.generation, isObserving else { return }
        selection.fetched(info)
        publish()
    }

    /// Yields only real changes: Music repeats the same state within milliseconds (D24).
    private func publish() {
        let current = selection.current
        guard current != lastPublished else { return }
        lastPublished = current
        continuation?.yield(current)
    }

    @objc nonisolated private func playerChanged(_ notification: Notification) {
        guard let player = MediaPlayer.allCases.first(where: { $0.notificationName == notification.name }),
              let parsed = PlayerNotificationParser.parse(notification.userInfo, from: player) else { return }
        Task { @MainActor in self.receive(parsed.info, carriesTrack: parsed.carriesTrack) }
    }

    @objc nonisolated private func appLaunched(_ notification: Notification) {
        guard let player = Self.player(in: notification) else { return }
        Task { @MainActor in self.playerRunningChanged(player, isRunning: true) }
    }

    @objc nonisolated private func appQuit(_ notification: Notification) {
        guard let player = Self.player(in: notification) else { return }
        Task { @MainActor in self.playerRunningChanged(player, isRunning: false) }
    }

    nonisolated private static func player(in notification: Notification) -> MediaPlayer? {
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        return MediaPlayer.allCases.first { $0.bundleID == app?.bundleIdentifier }
    }
}
