import CoreGraphics

/// Widths of the Home tab's cards in one row (D42). Pure, so tests can check the split without a view.
enum HomeLayout {
    /// A wide card never gets less than this share of the row: with Calendar, Battery and Weather all on, the fixed
    /// cards would otherwise leave Now Playing about 69 pt (D53). They shrink in proportion instead.
    static let minimumWideShare: CGFloat = 0.3

    /// Medium and narrow cards take their share of `total`; wide cards split what is left. Without a wide card the
    /// others share the row in proportion to their shares. Whole points that add up to the row exactly.
    static func widths(_ sizes: [HomeCardSize], total: CGFloat, spacing: CGFloat) -> [CGFloat] {
        // `total` is never below 432 pt (the open frame's minimum, D35), far wider than the gaps, so no width is negative.
        guard !sizes.isEmpty else { return [] }
        let free = total - spacing * CGFloat(sizes.count - 1)
        let wideCount = CGFloat(sizes.filter { $0 == .wide }.count)
        var widths: [CGFloat]
        if wideCount > 0 {
            var fixed = sizes.map { $0.share.map { (total * $0).rounded() } ?? 0 }
            let minimumWide = (total * minimumWideShare).rounded()
            let fixedSum = fixed.reduce(0, +)
            if fixedSum > 0, (free - fixedSum) / wideCount < minimumWide {
                let scale = max(0, free - minimumWide * wideCount) / fixedSum
                fixed = fixed.map { ($0 * scale).rounded(.down) }
            }
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
