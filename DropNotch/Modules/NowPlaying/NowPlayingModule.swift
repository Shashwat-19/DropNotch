import SwiftUI

/// Now Playing (D2, D22–D24): shows what a `NowPlayingSource` reports and sends its commands.
@MainActor
@Observable
final class NowPlayingModule: NotchModule {
    let id = "now-playing"
    let title: LocalizedStringResource = "Now Playing"
    private(set) var info: NowPlayingInfo?
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

    /// `settleDelay` is internal for tests.
    init(source: any NowPlayingSource, settleDelay: Duration = .seconds(1)) {
        self.source = source
        self.settleDelay = settleDelay
    }

    var hasCompactContent: Bool { info?.isPlaying == true }

    /// What the play/pause button shows: the click's result straight away, the player's state otherwise.
    var isPlaying: Bool { pendingIsPlaying ?? info?.isPlaying ?? false }

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
        isSending = false
        deniedPlayer = nil
        pendingIsPlaying = nil
        settleTask?.cancel()
        currentClick += 1
    }

    private func receive(_ info: NowPlayingInfo?) {
        if let pending = pendingIsPlaying {
            // Music sends bursts (D24), before or after the reply: only an update that agrees confirms the click.
            let agrees = info?.isPlaying == pending
            let playerChanged = info?.player != self.info?.player
            if agrees || playerChanged { pendingIsPlaying = nil }
        }
        self.info = info
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
        if command == .playPause, info.state != .unknown {
            settleTask?.cancel()
            pendingIsPlaying = !isPlaying
        }
        let outcome = await source.send(command, to: player)
        guard click == currentClick else { return }
        isSending = false
        if command == .playPause, pendingIsPlaying != nil {
            if outcome == .ok {
                // A command that changed nothing sends no notification: show the player's state again after a
                // moment. One wake per click, never repeating (ARCHITECTURE §9).
                settleTask = Task { [weak self, settleDelay] in
                    try? await Task.sleep(for: settleDelay)
                    guard let self, !Task.isCancelled, click == self.currentClick else { return }
                    self.pendingIsPlaying = nil
                }
            } else {
                pendingIsPlaying = nil
            }
        }
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
