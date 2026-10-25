import SwiftUI

/// Now Playing (D2, D22–D24): shows what a `NowPlayingSource` reports and sends its commands.
@MainActor
@Observable
final class NowPlayingModule: NotchModule {
    let id = "now-playing"
    let title: LocalizedStringResource = "Now Playing"
    private(set) var info: NowPlayingInfo?
    /// A command is in flight, or the Automation prompt is up. The controls are disabled meanwhile.
    private(set) var isSending = false
    /// The player that refused Automation on the last click (D23). A click that gets through clears it.
    private(set) var deniedPlayer: MediaPlayer?

    private let source: any NowPlayingSource
    // Not UI state, so Observation should skip it (`@Observable` only tracks `var`s).
    @ObservationIgnored private var task: Task<Void, Never>?

    init(source: any NowPlayingSource) {
        self.source = source
    }

    var hasCompactContent: Bool { info?.isPlaying == true }

    func compactView(slot: CompactSlot) -> AnyView { AnyView(EmptyView()) }

    func expandedView() -> AnyView { AnyView(NowPlayingExpandedView(module: self)) }

    func settingsView() -> AnyView { AnyView(EmptyView()) }

    func start() {
        guard task == nil else { return }
        // Inherits the main actor, so `info` is only touched on the main thread.
        task = Task { [weak self, source] in
            for await info in source.updates { self?.info = info }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        info = nil
        isSending = false
        deniedPlayer = nil
    }

    /// Sends `command` to the player on screen. The state change comes back as a notification, so
    /// nothing here guesses the new state.
    func perform(_ command: PlaybackCommand) async {
        guard let player = info?.player, !isSending else { return }
        isSending = true
        let outcome = await source.send(command, to: player)
        isSending = false
        switch outcome {
        case .denied: deniedPlayer = player
        case .ok: deniedPlayer = nil
        default: break
        }
    }
}
