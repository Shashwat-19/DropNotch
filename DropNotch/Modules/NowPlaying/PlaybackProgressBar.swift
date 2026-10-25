import AppKit
import SwiftUI

/// The thin progress bar (D26). Core Animation moves it from the current position to the end while
/// playing, so the app does no work between updates; each update restarts it from the new position.
///
/// AppKit note: SwiftUI can't hand an animation to the render server like this, so the bar is a
/// layer-backed `NSView` wrapped for SwiftUI. It animates the width, not a scale, so the rounded ends
/// keep their shape.
struct PlaybackProgressBar: NSViewRepresentable {
    let elapsed: TimeInterval
    let duration: TimeInterval
    let isPlaying: Bool

    func makeNSView(context: Context) -> ProgressBarView { ProgressBarView() }

    func updateNSView(_ view: ProgressBarView, context: Context) {
        view.update(elapsed: elapsed, duration: duration, isPlaying: isPlaying)
    }
}

final class ProgressBarView: NSView {
    private let track = CALayer()
    private let fill = CALayer()
    private var state: (elapsed: TimeInterval, duration: TimeInterval, isPlaying: Bool, at: Date)?

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        layer?.addSublayer(track)
        layer?.addSublayer(fill)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ProgressBarView is created in code only")
    }

    // Clicks go to the SwiftUI view around the bar, which handles seeking.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(elapsed: TimeInterval, duration: TimeInterval, isPlaying: Bool) {
        state = (elapsed, duration, isPlaying, Date())
        restart()
    }

    override func layout() {
        super.layout()
        restart()
    }

    private func restart() {
        guard let state, state.duration > 0, bounds.width > 0 else { return }
        let height: CGFloat = 4
        let elapsed = min(state.duration, state.elapsed + (state.isPlaying ? Date().timeIntervalSince(state.at) : 0))
        let width = bounds.width * elapsed / state.duration
        let endWidth = state.isPlaying ? bounds.width : width
        // Our own sublayers animate every change implicitly; these jumps must be instant.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // The notch is always black (L5); Increase Contrast gets a brighter track (L6).
        let trackAlpha = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast ? 0.5 : 0.25
        track.backgroundColor = NSColor.white.withAlphaComponent(trackAlpha).cgColor
        fill.backgroundColor = NSColor.white.cgColor
        track.frame = CGRect(x: 0, y: (bounds.height - height) / 2, width: bounds.width, height: height)
        track.cornerRadius = height / 2
        fill.cornerRadius = height / 2
        fill.removeAllAnimations()
        fill.position = CGPoint(x: 0, y: track.frame.midY)
        // The model value is where the bar ends up; the animation below runs from where it is now.
        fill.bounds = CGRect(x: 0, y: 0, width: endWidth, height: height)
        CATransaction.commit()
        guard state.isPlaying, elapsed < state.duration else { return }
        let animation = CABasicAnimation(keyPath: "bounds.size.width")
        animation.fromValue = width
        animation.toValue = endWidth
        animation.duration = state.duration - elapsed
        fill.add(animation, forKey: "progress")
    }
}
