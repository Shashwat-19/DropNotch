import CoreGraphics

/// Where the notch panel sits on one screen, in global screen coordinates
/// (ARCHITECTURE.md §7). A pure value type: it takes plain numbers instead of an
/// `NSScreen`, so tests can feed it any screen without real hardware.
struct NotchGeometry: Equatable {
    /// Size of the pill drawn on screens without a notch.
    static let pillWidth: CGFloat = 200
    /// Pill height when the menu bar is auto-hidden and has no height to copy.
    static let fallbackPillHeight: CGFloat = 24
    /// How much the shape grows while the open delay runs (peek): 12 pt each side and
    /// 8 pt down, so a pointer resting near the notch stays inside.
    static let peekGrowth = CGSize(width: 24, height: 8)
    /// Minimum size of the open panel. One height for every tab (D16, D29): 190 pt gives Home five calendar rows on
    /// the Air (D46).
    static let openSize = CGSize(width: 480, height: 190)
    /// How far the panel reaches above the screen. A pointer pushed against the top edge
    /// reports y == screen maxY, which a frame ending there counts as outside (D20).
    static let topOverhang: CGFloat = 1
    /// Radius of the inverse curves where the shape meets the menu bar (D36), so it reads as one piece with the
    /// hardware notch. Whole points, so a panel widened by them stays on whole points.
    static let compactShoulder: CGFloat = 6
    static let openShoulder: CGFloat = 10
    /// The open notch's top row sits right of the camera housing (D35): module tabs, then the Settings button.
    static let topRowItemSize = CGSize(width: 28, height: 24)
    /// Space between neighbouring buttons in the row.
    static let topRowSpacing: CGFloat = 2
    /// Clear space between the camera housing and the first button, and after the last.
    static let topRowInset: CGFloat = 8
    /// Four module tabs and the Settings button. A fifth module needs this raised, or the row would overflow.
    static let topRowMaxItems = 5
    /// Width the row needs right of the housing.
    static var topRowWidth: CGFloat {
        CGFloat(topRowMaxItems) * topRowItemSize.width + CGFloat(topRowMaxItems - 1) * topRowSpacing + 2 * topRowInset
    }

    let hasNotch: Bool
    let closedFrame: CGRect
    let peekFrame: CGRect
    let openFrame: CGRect
    /// The closed shape while a module fills the compact slots: one square wing each side, as wide as the
    /// notch is tall (D28).
    let compactFrame: CGRect
    let compactPeekFrame: CGRect

    /// - Parameters:
    ///   - safeAreaTop: `NSScreen.safeAreaInsets.top`; non-zero only under a camera housing.
    ///   - auxLeftWidth, auxRightWidth: widths of `auxiliaryTopLeftArea` and
    ///     `auxiliaryTopRightArea`, the menu-bar space either side of the notch (nil without one).
    ///   - menuBarHeight: `frame.maxY - visibleFrame.maxY`; 0 when the menu bar auto-hides.
    ///   - backingScale: `backingScaleFactor`, used to align edges to whole pixels.
    init(screenFrame: CGRect, safeAreaTop: CGFloat, auxLeftWidth: CGFloat?, auxRightWidth: CGFloat?,
         menuBarHeight: CGFloat, backingScale: CGFloat) {
        let closed: CGRect
        if safeAreaTop > 0, let left = auxLeftWidth, let right = auxRightWidth {
            hasNotch = true
            closed = CGRect(x: screenFrame.minX + left, y: screenFrame.maxY - safeAreaTop,
                            width: screenFrame.width - left - right, height: safeAreaTop)
        } else {
            hasNotch = false
            let height = menuBarHeight > 0 ? menuBarHeight : Self.fallbackPillHeight
            closed = Self.topCentred(midX: screenFrame.midX, top: screenFrame.maxY,
                                     size: CGSize(width: Self.pillWidth, height: height))
        }
        let compact = closed.insetBy(dx: -closed.height, dy: 0)
        let peek = CGSize(width: closed.width + Self.peekGrowth.width,
                          height: closed.height + Self.peekGrowth.height)
        let compactPeek = CGSize(width: compact.width + Self.peekGrowth.width, height: peek.height)
        // At least as large as every other frame, so it can serve as the canvas (D19), and wide enough for the top
        // row right of the housing (D35): centred on the notch, so each side gets `topRowWidth`. A pill is ours to
        // draw over, so only a real notch is kept clear.
        let housing = hasNotch ? closed.width : 0
        let open = CGSize(width: max(Self.openSize.width, compactPeek.width, housing + 2 * Self.topRowWidth),
                          height: max(Self.openSize.height, peek.height))

        closedFrame = Self.pixelAligned(closed, scale: backingScale)
        peekFrame = Self.pixelAligned(Self.topCentred(midX: closed.midX, top: closed.maxY, size: peek),
                                      scale: backingScale)
        compactFrame = Self.pixelAligned(compact, scale: backingScale)
        compactPeekFrame = Self.pixelAligned(Self.topCentred(midX: closed.midX, top: closed.maxY, size: compactPeek),
                                             scale: backingScale)
        openFrame = Self.pixelAligned(Self.topCentred(midX: closed.midX, top: closed.maxY, size: open),
                                      scale: backingScale)
    }

    /// Where the free strip right of the camera housing starts, from the open shape's leading edge (D35). The housing
    /// is the closed frame, which comes from the screen's `auxiliaryTopLeftArea` and `auxiliaryTopRightArea`. Without
    /// a notch, the middle of the shape. Both edges are pixel-aligned, so the row's padding lands on whole pixels.
    var openTopRowLeading: CGFloat {
        (hasNotch ? closedFrame.maxX : openFrame.midX) - openFrame.minX
    }

    /// Width of one compact wing (D28).
    var wingWidth: CGFloat { (compactFrame.width - closedFrame.width) / 2 }

    /// Where the shape's body is drawn in each phase; `wings` are the compact slots with something to show (D28).
    /// Only those sides widen, so a slot set to Nothing leaves no empty wing (D36).
    func frame(for phase: NotchHoverStateMachine.Phase, wings: Set<CompactSlot> = []) -> CGRect {
        switch phase {
        case .closed: wings.isEmpty ? closedFrame : trimmed(compactFrame, to: wings)
        case .peek: wings.isEmpty ? peekFrame : trimmed(compactPeekFrame, to: wings)
        case .open: openFrame
        }
    }

    /// The shoulder radius for a phase (D36). The closed shape without wings sits inside the hardware notch, so it
    /// has none; everything that reaches over the menu bar has them.
    static func shoulder(for phase: NotchHoverStateMachine.Phase, wings: Set<CompactSlot> = []) -> CGFloat {
        switch phase {
        case .closed: wings.isEmpty ? 0 : compactShoulder
        case .peek: compactShoulder
        case .open: openShoulder
        }
    }

    /// The panel's frame: the body plus the shoulders either side and `topOverhang` above the screen.
    func panelFrame(for phase: NotchHoverStateMachine.Phase, wings: Set<CompactSlot> = []) -> CGRect {
        let frame = frame(for: phase, wings: wings), shoulder = Self.shoulder(for: phase, wings: wings)
        return CGRect(x: frame.minX - shoulder, y: frame.minY, width: frame.width + 2 * shoulder,
                      height: frame.height + Self.topOverhang)
    }

    /// Takes the wing off each side not in `wings`. Each side by its own snapped width, not `wingWidth`: at 1x a
    /// 33.5 pt wing snaps to 33 on one side and 34 on the other, and the average would land on a half point.
    private func trimmed(_ frame: CGRect, to wings: Set<CompactSlot>) -> CGRect {
        let minX = frame.minX + (wings.contains(.left) ? 0 : closedFrame.minX - compactFrame.minX)
        let maxX = frame.maxX - (wings.contains(.right) ? 0 : compactFrame.maxX - closedFrame.maxX)
        return CGRect(x: minX, y: frame.minY, width: maxX - minX, height: frame.height)
    }

    /// AppKit's y axis points up, so a frame hanging from the top edge has `maxY == top`.
    private static func topCentred(midX: CGFloat, top: CGFloat, size: CGSize) -> CGRect {
        CGRect(x: midX - size.width / 2, y: top - size.height, width: size.width, height: size.height)
    }

    /// The top inset can be fractional (33.5 pt), so round each edge to the nearest
    /// device pixel rather than the nearest point. Halves always round up, so a
    /// display at a negative origin rounds the same way as one at a positive origin.
    private static func pixelAligned(_ rect: CGRect, scale: CGFloat) -> CGRect {
        let snap = { (value: CGFloat) in (value * scale + 0.5).rounded(.down) / scale }
        let minX = snap(rect.minX), minY = snap(rect.minY)
        return CGRect(x: minX, y: minY, width: snap(rect.maxX) - minX, height: snap(rect.maxY) - minY)
    }
}
