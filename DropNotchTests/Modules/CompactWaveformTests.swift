import SwiftUI
import XCTest
@testable import DropNotch

/// The bars stop on the same update as a pause (D28): the player's paused notification, or the optimistic flip
/// of a click in the notch, before the player confirms it.
@MainActor
final class CompactWaveformTests: XCTestCase {
    private final class Source: NowPlayingSource {
        let (updates, continuation) = AsyncStream.makeStream(of: NowPlayingInfo?.self)
        /// The reply to the click in flight, held so the player never confirms during the test.
        var reply: CheckedContinuation<AppleEventOutcome, Never>?
        func refresh(_ player: MediaPlayer) {}
        func send(_ command: PlaybackCommand, to player: MediaPlayer) async -> AppleEventOutcome {
            await withCheckedContinuation { reply = $0 }
        }
    }

    private func info(_ state: NowPlayingInfo.State) -> NowPlayingInfo {
        NowPlayingInfo(player: .music, state: state, title: "t", trackID: "T", duration: 200,
                       position: PlaybackPosition(seconds: 10, at: Date()))
    }

    private func animating(_ view: NSView) -> Bool {
        (view.layer?.sublayers ?? []).contains { !($0.animationKeys() ?? []).isEmpty }
    }

    private func waveform(in view: NSView) -> CompactWaveformView? {
        if let found = view as? CompactWaveformView { return found }
        return view.subviews.lazy.compactMap { self.waveform(in: $0) }.first
    }

    /// Lets SwiftUI apply pending changes once: one pass of the main run loop, then layout.
    private func renderOnce(_ hosting: NSView) {
        RunLoop.main.run(mode: .default, before: Date())
        hosting.layoutSubtreeIfNeeded()
    }

    /// The right compact slot, hosted, with its bars moving.
    private func playingBars() async throws -> (NowPlayingModule, Source, NSView, CompactWaveformView, NSWindow) {
        try XCTSkipIf(ProcessInfo.processInfo.isLowPowerModeEnabled, "the bars stay still in Low Power Mode")
        try XCTSkipIf(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, "the bars stay still under Reduce Motion")
        let source = Source()
        let module = NowPlayingModule(source: source)
        module.start()
        // A fixed size, as the wing gives it: alone in a window the hosting view would shrink to its content.
        let hosting = NSHostingView(rootView: NowPlayingCompactView(module: module, slot: .right).frame(width: 20, height: 20))
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 20, height: 20), styleMask: .borderless,
                              backing: .buffered, defer: false)
        // Otherwise `close()` releases it a second time under ARC.
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        source.continuation.yield(info(.playing))
        for _ in 0..<1000 where !module.isPlaying { await Task.yield() }
        var bars: CompactWaveformView?
        for _ in 0..<100 {
            renderOnce(hosting)
            bars = waveform(in: hosting)
            if let bars, animating(bars) { break }
            try await Task.sleep(for: .milliseconds(5))
        }
        let found = try XCTUnwrap(bars, "no bars")
        XCTAssertTrue(animating(found), "the bars never started")
        return (module, source, hosting, found, window)
    }

    func testBarsStopInTheSameCallAsAPause() {
        let view = CompactWaveformView()
        view.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        view.layoutSubtreeIfNeeded()
        view.update(isPlaying: true, reduceMotion: false)
        if !ProcessInfo.processInfo.isLowPowerModeEnabled { XCTAssertTrue(animating(view)) }
        view.update(isPlaying: false, reduceMotion: false)
        XCTAssertFalse(animating(view))
        // Flat at once: the model heights are all the paused height.
        let heights = Set((view.layer?.sublayers ?? []).map(\.bounds.height))
        XCTAssertEqual(heights.count, 1)
    }

    func testBarsStopOnTheUpdateThatReportsAPause() async throws {
        let (module, source, hosting, bars, window) = try await playingBars()
        source.continuation.yield(info(.paused))
        for _ in 0..<1000 where module.isPlaying { await Task.yield() }
        XCTAssertFalse(module.isPlaying, "the update never arrived")
        renderOnce(hosting)
        XCTAssertFalse(animating(bars), "the bars kept moving after the paused update was drawn")
        window.close()
    }

    func testBarsStopOnTheClickBeforeThePlayerConfirms() async throws {
        let (module, source, hosting, bars, window) = try await playingBars()
        let click = Task { await module.perform(.playPause) }
        for _ in 0..<1000 where module.isPlaying { await Task.yield() }
        XCTAssertFalse(module.isPlaying, "the click didn't flip the state")
        XCTAssertEqual(module.info?.state, .playing, "the player must not have confirmed yet")
        renderOnce(hosting)
        XCTAssertFalse(animating(bars), "the bars waited for the player")
        for _ in 0..<1000 where source.reply == nil { await Task.yield() }
        source.reply?.resume(returning: .ok)
        await click.value
        window.close()
    }
}
