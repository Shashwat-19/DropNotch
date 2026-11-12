import CoreGraphics

/// Rounded bottom corners on the display with the notch (D52), to match its rounded top corners. Pure geometry, so
/// it is tested without windows; `ScreenCornersController` puts a `ScreenCornerWindow` at each frame.
enum ScreenCorners {
    /// Settings › General › Round the bottom corners. Off when nothing is saved.
    static let key = "screenCorners.enabled"
    /// Points. [I] Close to the radius of the top corners of the MacBook Air and Pro displays; device check.
    static let radius: CGFloat = 10

    enum Corner: CaseIterable {
        case bottomLeft, bottomRight
    }

    /// A frame for each bottom corner of each screen with a notch, in AppKit's global coordinates (origin at the
    /// bottom left of the main screen, y up). Other screens have square top corners, so they get none.
    static func frames(screens: [(frame: CGRect, hasNotch: Bool)],
                       radius: CGFloat = radius) -> [(corner: Corner, frame: CGRect)] {
        screens.filter(\.hasNotch).flatMap { screen in
            Corner.allCases.map { corner in
                let x = corner == .bottomLeft ? screen.frame.minX : screen.frame.maxX - radius
                return (corner, CGRect(x: x, y: screen.frame.minY, width: radius, height: radius))
            }
        }
    }

    /// The black part of a corner window `radius` points square, in its own coordinates (y up): the square minus a
    /// quarter disc centred on the square's inner corner, so the screen shows through a rounded edge.
    static func maskPath(for corner: Corner, radius: CGFloat = radius) -> CGPath {
        let path = CGMutablePath()
        // Bottom-left: from the screen's corner along the bottom edge, round the arc up to the left edge, and back.
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: radius, y: 0))
        // From straight down (−90°) to straight left (−180°), decreasing angle: clockwise with y up.
        path.addArc(center: CGPoint(x: radius, y: radius), radius: radius,
                    startAngle: -.pi / 2, endAngle: -.pi, clockwise: true)
        path.closeSubpath()
        guard corner == .bottomRight else { return path }
        // The right corner is the left one mirrored across the square's vertical centre line.
        var mirror = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: radius, ty: 0)
        return path.copy(using: &mirror) ?? path
    }
}
