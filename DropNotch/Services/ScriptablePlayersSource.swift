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
    private let artworkLoader: any ArtworkLoading
    private let runningPID: (MediaPlayer) -> pid_t?
    private var selection = NowPlayingSelection()
    private var continuation: AsyncStream<NowPlayingInfo?>.Continuation?
    private var lastPublished: NowPlayingInfo?
    /// The track id each player was last read for, so Spotify is read once per track (D26).
    private var lastReadTrackID: [MediaPlayer: String] = [:]
    /// The track id each player's artwork was last tried for: one try per track, success or not (D25).
    private var lastArtworkTrackID: [MediaPlayer: String] = [:]
    /// Bumped per subscription, so a late reply or `onTermination` from an old stream can't touch the new one.
    private var generation = 0
    /// false in tests, so a real player's notifications or launch can't reach a test's stream.
    private let observesSystem: Bool

    init(sender: any AppleEventSending = AppleEventSender(),
         artworkLoader: any ArtworkLoading = ArtworkDownloader(),
         runningPID: @escaping (MediaPlayer) -> pid_t? = {
             NSRunningApplication.runningApplications(withBundleIdentifier: $0.bundleID).first?.processIdentifier
         },
         observesSystem: Bool = true) {
        self.sender = sender
        self.artworkLoader = artworkLoader
        self.runningPID = runningPID
        self.observesSystem = observesSystem
    }

    /// Whether a stream is live. Internal for tests.
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
        // A seek by Apple Event sends no notification [V: media probe], so read the new position (D26).
        if case .seek = command, outcome == .ok { refresh(player) }
        Logger.nowPlaying.info("Command to \(player.bundleID, privacy: .public) pid \(pid): \(String(describing: outcome), privacy: .public)")
        return outcome
    }

    /// A parsed player notification. Internal so tests can drive it without posting distributed notifications.
    func receive(_ info: NowPlayingInfo, carriesTrack: Bool) {
        guard isObserving else { return }
        Logger.nowPlaying.debug("\(info.player.bundleID, privacy: .public) reported \(String(describing: info.state), privacy: .public)")
        selection.report(info, carriesTrack: carriesTrack)
        publish()
        // D26: Music's notification has no position, so read after each one that carries a track. Spotify's
        // carries position and duration, so read only for a new track id (for its artwork URL).
        guard carriesTrack else { return }
        // Any change of track, an ad included, resets the once-per-track read and artwork try, so a track
        // that comes back (repeat after an ad) is read and gets its artwork again.
        let isNewTrack = info.trackID != lastReadTrackID[info.player]
        if isNewTrack {
            lastReadTrackID[info.player] = info.trackID
            lastArtworkTrackID[info.player] = nil
        }
        if info.player == .music || (isNewTrack && info.trackID != nil) { refresh(info.player) }
    }

    /// Reads `player`'s position and track by Apple Event and merges it if nothing newer arrived (D26).
    /// Only with a grant the user already gave, so it never prompts (D23).
    func refresh(_ player: MediaPlayer) {
        guard isObserving, let pid = runningPID(player) else { return }
        let stamp = selection.stamp(for: player)
        let generation = generation
        Task {
            guard await sender.permission(for: player, pid: pid, ask: false) == .ok,
                  let read = await sender.readCurrent(of: player, pid: pid),
                  generation == self.generation, isObserving else { return }
            selection.refreshed(read, stamp: stamp)
            publish()
            loadArtwork(player, pid: pid, generation: generation)
        }
    }

    /// Loads the artwork for `player`'s current track once (D25, D26): Music's from Music by Apple Event,
    /// Spotify's from its image server. Called only after a read, so the grant is already there. Any
    /// failure leaves the app icon until the track changes.
    private func loadArtwork(_ player: MediaPlayer, pid: pid_t, generation: Int) {
        guard let info = selection.info(for: player), let trackID = info.trackID, info.artwork == nil,
              lastArtworkTrackID[player] != trackID,
              // Spotify's URL may come from a later read (on open): don't use up the try without one.
              player == .music || info.artworkURL != nil else { return }
        lastArtworkTrackID[player] = trackID
        let url = info.artworkURL
        Task {
            var data: Data?
            if player == .music {
                data = await sender.readArtwork(of: player, pid: pid)
            } else if let url {
                data = await artworkLoader.data(from: url)
            }
            // Decoding can take a while for a large image, so it runs off the main actor.
            let artwork = await Task.detached(priority: .utility) {
                data.flatMap { NowPlayingArtwork(trackID: trackID, data: $0) }
            }.value
            Logger.nowPlaying.debug("Artwork for \(player.bundleID, privacy: .public): \(artwork == nil ? "none" : "loaded", privacy: .public)")
            guard let artwork, generation == self.generation, isObserving else { return }
            selection.setArtwork(artwork, for: player)
            publish()
        }
    }

    /// A player launched or quit. Internal for tests.
    func playerRunningChanged(_ player: MediaPlayer, isRunning: Bool) {
        guard isObserving else { return }
        if isRunning {
            selection.launched(player)
        } else {
            selection.quit(player)
            // A relaunch usually resumes the same track; it must be read, and get artwork, again.
            lastReadTrackID[player] = nil
            lastArtworkTrackID[player] = nil
        }
        publish()
    }

    private func startObserving(generation: Int) {
        selection = NowPlayingSelection()
        lastReadTrackID = [:]
        lastArtworkTrackID = [:]
        if observesSystem { addSystemObservers() }
        for player in MediaPlayer.allCases {
            guard let pid = runningPID(player) else { continue }
            selection.launched(player)
            Task { await fetchCurrent(player, pid: pid, generation: generation) }
        }
        publish()
    }

    private func addSystemObservers() {
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
        Logger.nowPlaying.debug("Start check for \(player.bundleID, privacy: .public) pid \(pid): \(String(describing: permission), privacy: .public)")
        guard permission == .ok, let info = await sender.readCurrent(of: player, pid: pid),
              generation == self.generation, isObserving else { return }
        // When used, the start read already read this track, so its first notification needn't read it again.
        if selection.fetched(info) { lastReadTrackID[player] = info.trackID }
        publish()
        loadArtwork(player, pid: pid, generation: generation)
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
        Task { @MainActor in
            // Any local process can post these names. One for a player that isn't running would show
            // a player that never clears, because no quit notice will come for it.
            guard self.runningPID(player) != nil else { return }
            self.receive(parsed.info, carriesTrack: parsed.carriesTrack)
        }
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
