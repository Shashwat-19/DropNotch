import AppKit
import Observation
import SwiftUI
import os

/// Shows Now Playing above the lock screen while the Mac is locked and something is loaded in Music or Spotify (D55).
/// Not a module: no tab or card. Off by default, since anyone at the locked Mac can see the track and use the controls.
/// Event-driven: lock and unlock notifications, and Observation on the Now Playing module; no timer, no poll.
@MainActor
final class LockScreenPlayer {
    /// Settings › General › Show the player on the lock screen. Off when nothing is saved (D55).
    static let key = "lockScreenPlayer.enabled"

    private let nowPlaying: NowPlayingModule
    private let locks: any LockStateSource
    private let surface: any LockScreenSurface
    private let defaults: UserDefaults
    let isAvailable: Bool
    private var task: Task<Void, Never>?
    private(set) var isLocked = false
    /// Bumped by `stop()`, so a pending Observation callback from before it doesn't start following again.
    private var generation = 0

    init(nowPlaying: NowPlayingModule, locks: any LockStateSource, surface: any LockScreenSurface, isAvailable: Bool,
         defaults: UserDefaults = .standard) {
        self.nowPlaying = nowPlaying
        self.locks = locks
        self.surface = surface
        self.isAvailable = isAvailable
        self.defaults = defaults
    }

    /// The app's player: SkyLight space, the system's lock notifications, the Now Playing card.
    convenience init(nowPlaying: NowPlayingModule) {
        let space = SkyLightLockScreenSpace()
        self.init(nowPlaying: nowPlaying, locks: DistributedLockStateSource(),
                  surface: LockScreenPlayerWindow(space: space,
                                                  compact: { AnyView(CompactLockPlayerView(module: nowPlaying, expand: $0.expand)
                                                      .environment(\.colorScheme, .dark)) },
                                                  expanded: { AnyView(FullScreenPlayerView(module: nowPlaying, collapse: $0.collapse)
                                                      .environment(\.colorScheme, .dark)) }),
                  isAvailable: space.isAvailable)
    }

    var isEnabled: Bool { defaults.bool(forKey: Self.key) }
    var isRunning: Bool { task != nil }

    func refresh() {
        if isEnabled, isAvailable { start() } else { stop() }
    }

    func start() {
        guard task == nil else { return }
        generation += 1
        followTrack(generation)
        task = Task { [weak self, locks] in
            for await locked in locks.changes {
                self?.isLocked = locked
                self?.update()
                Logger.lockScreen.debug("Screen \(locked ? "locked" : "unlocked", privacy: .public)")
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        generation += 1
        isLocked = false
        surface.hide()
    }

    /// Shown only while locked, on, and with a track loaded: an empty card on the lock screen helps no one.
    private func update() {
        let wanted = isRunning && isLocked && nowPlaying.shown != nil
        if wanted, !surface.isShown {
            // The blurred background ready before the first frame (D56), so it doesn't arrive late.
            if let artwork = nowPlaying.shown?.artwork { _ = BlurredArtwork.cached(for: artwork) }
            if !surface.show() { Logger.lockScreen.error("Lock-screen player couldn't be placed") }
        } else if !wanted, surface.isShown {
            surface.hide()
        }
    }

    /// Re-checks when a track loads or goes while locked. Observation reports one change, then has to be asked again.
    private func followTrack(_ generation: Int) {
        guard generation == self.generation else { return }
        _ = withObservationTracking { nowPlaying.shown == nil } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, generation == self.generation else { return }
                self.update()
                self.followTrack(generation)
            }
        }
    }
}
