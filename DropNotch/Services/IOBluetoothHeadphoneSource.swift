import Foundation
import IOBluetooth
import os

/// `HeadphoneBatterySource` from IOBluetooth (D54): the documented connect notification, then one read of the device's
/// private per-bud battery keys. A key the system doesn't have is skipped, so a macOS update loses the reading
/// instead of raising an exception. No polling, no subprocesses.
@MainActor
final class IOBluetoothHeadphoneSource: NSObject, HeadphoneBatterySource {
    /// After connecting, the levels take a moment to arrive [I: device check 134].
    static let readDelay: Duration = .seconds(2)
    /// `kBluetoothDeviceClassMajorAudio`: headphones and speakers.
    static let audioClass: BluetoothDeviceClassMajor = 0x04

    private var continuation: AsyncStream<HeadphoneBattery>.Continuation?
    private var notification: IOBluetoothUserNotification?
    /// Connected when the stream started: the system reports these at once, and they aren't new connections.
    private var alreadyConnected: Set<String> = []
    private var pendingReads: [Task<Void, Never>] = []

    var connections: AsyncStream<HeadphoneBattery> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            self.stopObserving()
            self.continuation = continuation
            // The first IOBluetooth call; macOS asks for Bluetooth permission here the first time (D54).
            let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
            self.alreadyConnected = Set(paired.filter { $0.isConnected() }.compactMap { $0.addressString })
            self.notification = IOBluetoothDevice.register(forConnectNotifications: self,
                                                           selector: #selector(self.deviceConnected(_:device:)))
            if self.notification == nil { Logger.battery.error("Bluetooth connect notifications unavailable") }
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.stopObserving() }
            }
        }
    }

    private func stopObserving() {
        notification?.unregister()
        notification = nil
        pendingReads.forEach { $0.cancel() }
        pendingReads = []
        continuation?.finish()
        continuation = nil
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard device.deviceClassMajor == Self.audioClass else { return }
        if let address = device.addressString, alreadyConnected.remove(address) != nil { return }
        // One-shot, per connection (ARCHITECTURE.md §9).
        let read = Task { [weak self] in
            try? await Task.sleep(for: Self.readDelay)
            guard !Task.isCancelled, let self, device.isConnected() else { return }
            let battery = Self.read(device)
            if !battery.isEmpty { self.continuation?.yield(battery) }
        }
        pendingReads.removeAll { $0.isCancelled }
        pendingReads.append(read)
    }

    /// Private keys (D54), each read only if the device answers to it.
    static func read(_ device: NSObject) -> HeadphoneBattery {
        func value(_ key: String) -> Int? {
            guard device.responds(to: NSSelectorFromString(key)) else { return nil }
            return (device.value(forKey: key) as? NSNumber)?.intValue
        }
        return HeadphoneBattery(left: value("batteryPercentLeft"), right: value("batteryPercentRight"),
                                caseLevel: value("batteryPercentCase"), single: value("batteryPercentSingle"))
    }
}
