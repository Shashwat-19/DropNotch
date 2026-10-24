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
    /// Minimum size of the open panel.
    static let openSize = CGSize(width: 480, height: 150)

    let hasNotch: Bool
    let closedFrame: CGRect
    let peekFrame: CGRect
    let openFrame: CGRect

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
        let peek = CGSize(width: closed.width + Self.peekGrowth.width,
                          height: closed.height + Self.peekGrowth.height)
        let open = CGSize(width: max(Self.openSize.width, peek.width),
                          height: max(Self.openSize.height, peek.height))

        closedFrame = Self.pixelAligned(closed, scale: backingScale)
        peekFrame = Self.pixelAligned(Self.topCentred(midX: closed.midX, top: closed.maxY, size: peek),
                                      scale: backingScale)
        openFrame = Self.pixelAligned(Self.topCentred(midX: closed.midX, top: closed.maxY, size: open),
                                      scale: backingScale)
    }

    func frame(for phase: NotchHoverStateMachine.Phase) -> CGRect {
        switch phase {
        case .closed: closedFrame
        case .peek: peekFrame
        case .open: openFrame
        }
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
