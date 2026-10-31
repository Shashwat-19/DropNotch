import AppKit
import SwiftUI

/// The decorative bars beside the closed notch (D2, D28). Core Animation repeats the motion, so the app does
/// no work between frames, as for the progress bar (D26).
struct CompactWaveform: NSViewRepresentable {
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeNSView(context: Context) -> CompactWaveformView { CompactWaveformView() }

    func updateNSView(_ view: CompactWaveformView, context: Context) {
        view.update(isPlaying: isPlaying, reduceMotion: reduceMotion)
    }
}

final class CompactWaveformView: NSView {
    private let bars = (0..<4).map { _ in CALayer() }
    private var isPlaying = false
    private var reduceMotion = false
    private var screensAsleep = false
    private var laidOutSize = CGSize.zero
    /// Bar heights as a share of the view's height: still while playing, and the range each bar moves through.
    private static let restingHeights: [CGFloat] = [0.5, 0.9, 0.65, 0.8]
    private static let pausedHeight: CGFloat = 0.2
    private static let lowHeight: CGFloat = 0.3
    /// Different periods so the bars never line up into one pulse.
    private static let periods: [CFTimeInterval] = [0.45, 0.6, 0.5, 0.7]

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        bars.forEach { layer?.addSublayer($0) }
        // Selector observers are removed automatically when the view goes away. Sleep and wake are on
        // NSWorkspace's own centre and posted on the main thread.
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self, selector: #selector(screensDidSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(screensDidWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(powerStateChanged),
                                               name: .NSProcessInfoPowerStateDidChange, object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("CompactWaveformView is created in code only")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(isPlaying: Bool, reduceMotion: Bool) {
        guard isPlaying != self.isPlaying || reduceMotion != self.reduceMotion else { return }
        self.isPlaying = isPlaying
        self.reduceMotion = reduceMotion
        restart()
    }

    // Only a new size restarts the bars; any other layout pass would snap them back to the low height.
    override func layout() {
        super.layout()
        guard bounds.size != laidOutSize else { return }
        laidOutSize = bounds.size
        restart()
    }

    @objc private func screensDidSleep() {
        screensAsleep = true
        restart()
    }

    @objc private func screensDidWake() {
        screensAsleep = false
        restart()
    }

    // Apple doesn't say which thread posts this, so hop to the main actor.
    @objc nonisolated private func powerStateChanged() {
        Task { @MainActor [weak self] in self?.restart() }
    }

    private func restart() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let animates = isPlaying && !reduceMotion && !screensAsleep && !ProcessInfo.processInfo.isLowPowerModeEnabled
        let width: CGFloat = 3
        let gap = (bounds.width - width * CGFloat(bars.count)) / CGFloat(bars.count - 1)
        // Our own sublayers animate every change implicitly; these jumps must be instant.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, bar) in bars.enumerated() {
            let share = isPlaying ? Self.restingHeights[index] : Self.pausedHeight
            bar.removeAllAnimations()
            bar.backgroundColor = NSColor.white.cgColor
            bar.cornerRadius = width / 2
            bar.bounds = CGRect(x: 0, y: 0, width: width, height: bounds.height * share)
            bar.position = CGPoint(x: width / 2 + CGFloat(index) * (width + gap), y: bounds.midY)
        }
        CATransaction.commit()
        guard animates else { return }
        for (index, bar) in bars.enumerated() {
            // Height, not a scale, so the rounded ends keep their shape.
            let animation = CABasicAnimation(keyPath: "bounds.size.height")
            animation.fromValue = bounds.height * Self.lowHeight
            // The square root lifts each peak above its resting height (0.5 → 0.71, 0.9 → 0.95), so the bars
            // move between low and nearly full while keeping their uneven order.
            animation.toValue = bounds.height * Self.restingHeights[index].squareRoot()
            animation.duration = Self.periods[index]
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            // shortcut: 15 fps is a guess at smooth enough at this size, raise it if the device check says choppy.
            animation.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 15, preferred: 15)
            bar.add(animation, forKey: "wave")
        }
    }
}
