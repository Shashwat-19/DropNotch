import SwiftUI

/// Now Playing (D2, D22–D24): shows what a `NowPlayingSource` reports and sends its commands.
@MainActor
@Observable
final class NowPlayingModule: NotchModule {
    let id = "now-playing"
    let title: LocalizedStringResource = "Now Playing"
    /// What the source last reported.
    private(set) var info: NowPlayingInfo?
    /// What the view draws (D27): `info`, with a pending click's play/pause and the position it froze or
    /// resumed from, a position steadied against Music's read jitter, and the last track's artwork kept until
    /// the new track's loads or turns out missing.
    private(set) var shown: NowPlayingInfo?
    /// A command is in flight, or the Automation prompt is up. `perform` drops clicks meanwhile (D23, D27).
    private(set) var isSending = false
    /// The player that refused Automation on the last click (D23). A click that gets through clears it.
    private(set) var deniedPlayer: MediaPlayer?
    /// Play/pause as clicked, shown before the player confirms it (D27). Cleared by an update that agrees,
    /// a player change, a failed command, or `settleDelay` after an `.ok` reply the player never confirms.
    private(set) var pendingIsPlaying: Bool?

    private let source: any NowPlayingSource
    // Not UI state, so Observation should skip it (`@Observable` only tracks `var`s).
    @ObservationIgnored private var task: Task<Void, Never>?
    /// Numbers each click. `stop()` and newer clicks move it on, so a reply that arrives late (the
    /// Automation prompt can stay up indefinitely) can't undo what happened since.
    @ObservationIgnored private var currentClick = 0
    @ObservationIgnored private let settleDelay: Duration
    @ObservationIgnored private var settleTask: Task<Void, Never>?
    /// The previous track's artwork, shown on the new track until its own arrives, it is known to have none,
    /// or `artworkHold` passes (a read that failed never says either).
    @ObservationIgnored private var heldArtwork: NowPlayingArtwork?
    @ObservationIgnored private let artworkHold: Duration
    @ObservationIgnored private var artworkHoldTask: Task<Void, Never>?

    /// `settleDelay` and `artworkHold` are internal for tests.
    init(source: any NowPlayingSource, settleDelay: Duration = .seconds(1), artworkHold: Duration = .seconds(2)) {
        self.source = source
        self.settleDelay = settleDelay
        self.artworkHold = artworkHold
    }

    var hasCompactContent: Bool { info?.isPlaying == true }

    /// What the play/pause button shows: the click's result straight away, the player's state otherwise.
    var isPlaying: Bool { shown?.isPlaying ?? false }

    func compactView(slot: CompactSlot) -> AnyView { AnyView(EmptyView()) }

    func expandedView() -> AnyView { AnyView(NowPlayingExpandedView(module: self)) }

    func settingsView() -> AnyView { AnyView(EmptyView()) }

    func start() {
        guard task == nil else { return }
        // Inherits the main actor, so `info` is only touched on the main thread.
        task = Task { [weak self, source] in
            for await info in source.updates { self?.receive(info) }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        info = nil
        shown = nil
        isSending = false
        deniedPlayer = nil
        pendingIsPlaying = nil
        settleTask?.cancel()
        heldArtwork = nil
        artworkHoldTask?.cancel()
        currentClick += 1
    }

    private func receive(_ info: NowPlayingInfo?) {
        if let pending = pendingIsPlaying {
            // Music sends bursts (D24), before or after the reply: only an update that agrees confirms the click.
            let agrees = info?.isPlaying == pending
            let otherTrack = info?.player != self.info?.player || info?.trackID != self.info?.trackID
            if agrees || otherTrack { pendingIsPlaying = nil }
        }
        self.info = info
        updateShown()
    }

    /// Rebuilds `shown` from `info`. `allowsBackward` takes the reported position as it is: after a failed
    /// command or a settle, the player's own word wins.
    private func updateShown(allowsBackward: Bool = false) {
        guard var next = info else {
            shown = nil
            return
        }
        let previous = shown
        let samePlayer = previous?.player == next.player
        let sameTrack = samePlayer && previous?.trackID == next.trackID
        if let pending = pendingIsPlaying, sameTrack {
            next.state = pending ? .playing : .paused
            next.position = previous?.position
        } else if !allowsBackward {
            next = next.steadied(after: previous, at: Date())
        }
        if next.artwork != nil || next.artworkMissing || next.trackID == nil || !samePlayer {
            heldArtwork = nil
            artworkHoldTask?.cancel()
        } else if !sameTrack, let old = previous?.artwork {
            heldArtwork = old
            artworkHoldTask?.cancel()
            // One wake per track change while a hold is on, never repeating (ARCHITECTURE §9).
            artworkHoldTask = Task { [weak self, artworkHold] in
                try? await Task.sleep(for: artworkHold)
                guard let self, !Task.isCancelled else { return }
                self.heldArtwork = nil
                self.updateShown()
            }
        }
        if let heldArtwork { next.artwork = heldArtwork }
        shown = next
    }

    /// The notch opened: re-read the position, because a seek made in the player may not have sent a
    /// notification (D26).
    func didOpen() {
        guard let player = info?.player else { return }
        source.refresh(player)
    }

    /// Sends `command` to the player on screen. Play/pause flips `isPlaying` at once; everything else waits
    /// for the player's notification.
    func perform(_ command: PlaybackCommand) async {
        guard let info, !isSending else { return }
        let player = info.player
        isSending = true
        currentClick += 1
        let click = currentClick
        // With the state unknown (no notification, no grant yet) a flip would only be a guess.
        if command == .playPause, info.state != .unknown, var next = shown {
            settleTask?.cancel()
            // Pause freezes, and play resumes, at the position on screen.
            let now = Date()
            next.position = next.elapsed(at: now).map { PlaybackPosition(seconds: $0, at: now) }
            next.state = next.isPlaying ? .paused : .playing
            pendingIsPlaying = next.isPlaying
            shown = next
        }
        // The bar goes to the target at once; the read after the seek (D26) confirms it.
        if case .seek(let seconds) = command { shown?.position = PlaybackPosition(seconds: seconds, at: Date()) }
        let outcome = await source.send(command, to: player)
        guard click == currentClick else { return }
        isSending = false
        if command == .playPause, pendingIsPlaying != nil {
            if outcome == .ok {
                // A command that changed nothing sends no notification: show the player's state again after a
                // moment. One wake per click, never repeating (ARCHITECTURE §9).
                settleTask = Task { [weak self, settleDelay] in
                    try? await Task.sleep(for: settleDelay)
                    // Not tied to `currentClick`: a skip or seek straight after must not keep the guess forever.
                    // `stop()` and the next play/pause cancel this instead.
                    // A click the player has confirmed since is settled already; rebuilding here would skip
                    // the steadying and step the time back to the raw read.
                    guard let self, !Task.isCancelled, self.pendingIsPlaying != nil else { return }
                    self.pendingIsPlaying = nil
                    self.updateShown(allowsBackward: true)
                }
            } else {
                pendingIsPlaying = nil
                updateShown(allowsBackward: true)
            }
        }
        if case .seek = command, outcome != .ok { updateShown(allowsBackward: true) }
        switch outcome {
        case .denied:
            deniedPlayer = player
            // The artist line silently becomes the System Settings link; say so to VoiceOver (WCAG 4.1.3).
            AccessibilityNotification.Announcement(
                String(localized: "Allow control of \(player.displayName) in System Settings")).post()
        case .ok: deniedPlayer = nil
        default: break
        }
    }
}
