import SwiftUI

/// Stub Now Playing module (D2, D21): consumes a `NowPlayingSource` and shows a placeholder.
@MainActor
@Observable
final class NowPlayingModule: NotchModule {
    let id = "now-playing"
    let title: LocalizedStringResource = "Now Playing"
    private(set) var info: NowPlayingInfo?

    private let source: any NowPlayingSource
    // Not UI state, so Observation should skip it (`@Observable` only tracks `var`s).
    @ObservationIgnored private var task: Task<Void, Never>?

    init(source: any NowPlayingSource) {
        self.source = source
    }

    var hasCompactContent: Bool { info?.isPlaying == true }

    func compactView(slot: CompactSlot) -> AnyView { AnyView(EmptyView()) }

    func expandedView() -> AnyView {
        AnyView(Text("Nothing playing")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.6)))
    }

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
    }
}
