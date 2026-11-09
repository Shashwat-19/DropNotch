import CoreGraphics

/// Widths of the Home tab's cards in one row (D42). Pure, so tests can check the split without a view.
enum HomeLayout {
    /// Medium and narrow cards take their share of `total`; wide cards split what is left. Without a wide card the
    /// others share the row in proportion to their shares. Whole points that add up to the row exactly.
    static func widths(_ sizes: [HomeCardSize], total: CGFloat, spacing: CGFloat) -> [CGFloat] {
        guard !sizes.isEmpty else { return [] }
        let free = total - spacing * CGFloat(sizes.count - 1)
        let wideCount = CGFloat(sizes.filter { $0 == .wide }.count)
        var widths: [CGFloat]
        if wideCount > 0 {
            let fixed = sizes.map { $0.share.map { (total * $0).rounded() } ?? 0 }
            let wide = ((free - fixed.reduce(0, +)) / wideCount).rounded(.down)
            widths = zip(sizes, fixed).map { $0 == .wide ? wide : $1 }
        } else {
            let shares = sizes.map { $0.share ?? 0 }
            let sum = shares.reduce(0, +)
            widths = shares.map { (free * $0 / sum).rounded(.down) }
        }
        // Rounding leaves a point or two over; the last card takes it, so the row ends flush with the margin.
        widths[widths.count - 1] += free - widths.reduce(0, +)
        return widths
    }
}
