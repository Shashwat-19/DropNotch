import SwiftUI

/// The notch's outline (D36): flat along the top, an inverse "shoulder" curve on each side where the shape meets the
/// menu bar, and rounded bottom corners. The body is `shoulder` narrower than the rect on each side; the shoulders
/// fill the corners between it and the menu bar, so the shape flows out of the screen edge like the hardware notch.
struct NotchShape: Shape {
    var shoulder: CGFloat
    var bottomRadius: CGFloat

    // Both radii animate with the shape's size, so the shoulders grow and shrink with it instead of jumping.
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(shoulder, bottomRadius) }
        set { (shoulder, bottomRadius) = (newValue.first, newValue.second) }
    }

    func path(in rect: CGRect) -> Path {
        let shoulder = max(0, min(shoulder, rect.width / 4, rect.height / 2))
        let left = rect.minX + shoulder, right = rect.maxX - shoulder
        let radius = max(0, min(bottomRadius, (right - left) / 2, rect.height - shoulder))
        // Each `addArc(tangent1End:tangent2End:)` rounds the corner at its first point. At the top the arc's centre
        // lies outside the shape, which is what makes a shoulder curve inwards.
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: right, y: rect.minY), tangent2End: CGPoint(x: right, y: rect.maxY), radius: shoulder)
        path.addArc(tangent1End: CGPoint(x: right, y: rect.maxY), tangent2End: CGPoint(x: left, y: rect.maxY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: left, y: rect.maxY), tangent2End: CGPoint(x: left, y: rect.minY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: left, y: rect.minY), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: shoulder)
        path.closeSubpath()
        return path
    }
}
