/// Where the Battery card gets the Mac's battery (D43). `@MainActor`: its only consumer is the module.
@MainActor
protocol BatterySource {
    /// The current status at once, then each change. Nil when no internal battery can be read. Not polled.
    var updates: AsyncStream<BatteryStatus?> { get }
}
