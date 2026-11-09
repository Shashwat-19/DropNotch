import SwiftUI

/// The Battery card (D43): a ring with the percentage in it, and the power state under it. The state is always in
/// words and symbols as well as colour (L6).
struct BatteryCardView: View {
    let module: BatteryModule

    var body: some View {
        if let status = module.status {
            VStack(spacing: NotchStyle.tightSpacing) {
                ring(status)
                state(status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // One element: "Battery, 82%, Charging", rather than the ring and the label read separately.
            .accessibilityElement(children: .combine)
        } else {
            NotchEmptyState("No battery reading", systemImage: "battery.0percent")
        }
    }

    private func ring(_ status: BatteryStatus) -> some View {
        let lineWidth: CGFloat = 7
        return ZStack {
            Circle().stroke(.white.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(status.percent) / 100)
                .stroke(status.isLow ? Color.red : Color.green, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                // Starts at 12 o'clock, like the system's battery widget.
                .rotationEffect(.degrees(-90))
            Text(Double(status.percent) / 100, format: .percent)
                .font(.title3.weight(.semibold).monospacedDigit())
        }
        .padding(lineWidth / 2)
        .frame(width: 60, height: 60)
    }

    @ViewBuilder
    private func state(_ status: BatteryStatus) -> some View {
        if status.isCharging {
            Label("Charging", systemImage: "bolt.fill")
        } else if status.isOnPower {
            Label("On power", systemImage: "powerplug.fill")
        } else {
            Text("Mac")
        }
    }
}
