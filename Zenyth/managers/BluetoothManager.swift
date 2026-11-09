//
//  BluetoothManager.swift
//  Zenyth
//
//  Derived from Atoll project.
//  Licensed under GNU General Public License v3.0.
//

import AppKit
import Defaults
import Foundation
import IOBluetooth
import IOKit

public enum BluetoothConnectionStatus: Equatable {
    case connected
    case disconnected
}

public struct BluetoothConnectedDevice: Identifiable, Equatable {
    public var id: String { address }
    public let address: String
    public let name: String
    public let iconName: String
    public var batteryLevel: Int?
    public var isConnected: Bool
    public var lastUpdated: Date

    public init(
        address: String,
        name: String,
        iconName: String,
        batteryLevel: Int? = nil,
        isConnected: Bool = true,
        lastUpdated: Date = Date()
    ) {
        self.address = address
        self.name = name
        self.iconName = iconName
        self.batteryLevel = batteryLevel
        self.isConnected = isConnected
        self.lastUpdated = lastUpdated
    }
}

@MainActor
public class BluetoothManager: ObservableObject {
    public static let shared = BluetoothManager()

    @Published public private(set) var connectedDevices: [BluetoothConnectedDevice] = []
    @Published public private(set) var lastEventDevice: BluetoothConnectedDevice?
    @Published public private(set) var lastEventStatus: BluetoothConnectionStatus = .connected

    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]
    private var isInitialized = false
    private var batteryTimer: Timer?

    private init() {
        startMonitoring()
    }

    public func startMonitoring() {
        guard connectNotification == nil else { return }

        // Initial scan of already connected paired devices
        scanConnectedDevices()

        // Register for connect notifications
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnectedNotification(_:device:))
        )

        // Periodic battery level refresh (every 30 seconds)
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshBatteries()
            }
        }

        isInitialized = true
    }

    public func scanConnectedDevices() {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return }
        var current: [BluetoothConnectedDevice] = []

        for device in paired {
            if device.isConnected() {
                let dev = createDeviceModel(from: device, isConnected: true)
                current.append(dev)
                registerDisconnectNotification(for: device)
            }
        }
        self.connectedDevices = current
    }

    private func registerDisconnectNotification(for device: IOBluetoothDevice) {
        guard let addr = device.addressString else { return }
        if disconnectNotifications[addr] != nil { return }

        if let notif = device.register(
            forDisconnectNotification: self,
            selector: #selector(deviceDisconnectedNotification(_:device:))
        ) {
            disconnectNotifications[addr] = notif
        }
    }

    @objc private func deviceConnectedNotification(
        _ notification: IOBluetoothUserNotification,
        device: IOBluetoothDevice
    ) {
        Task { @MainActor in
            self.handleDeviceConnected(device)
        }
    }

    @objc private func deviceDisconnectedNotification(
        _ notification: IOBluetoothUserNotification,
        device: IOBluetoothDevice
    ) {
        Task { @MainActor in
            self.handleDeviceDisconnected(device)
        }
    }

    private func handleDeviceConnected(_ device: IOBluetoothDevice) {
        let model = createDeviceModel(from: device, isConnected: true)
        registerDisconnectNotification(for: device)

        if let index = connectedDevices.firstIndex(where: { $0.address == model.address }) {
            connectedDevices[index] = model
        } else {
            connectedDevices.append(model)
        }

        // Trigger Live Activity if initialized and enabled
        if isInitialized {
            triggerLiveActivity(device: model, status: .connected)
        }

        // Secondary battery probe after 1.5s as peripherals often expose battery right after connect
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            if let updatedBattery = Self.queryBattery(for: device) {
                if let idx = self.connectedDevices.firstIndex(where: { $0.address == model.address }) {
                    self.connectedDevices[idx].batteryLevel = updatedBattery
                }
                if self.lastEventDevice?.address == model.address {
                    self.lastEventDevice?.batteryLevel = updatedBattery
                }
            }
        }
    }

    private func handleDeviceDisconnected(_ device: IOBluetoothDevice) {
        let addr = device.addressString ?? ""
        if let notif = disconnectNotifications[addr] {
            notif.unregister()
            disconnectNotifications.removeValue(forKey: addr)
        }

        let existing = connectedDevices.first(where: { $0.address == addr })
        let model = existing ?? createDeviceModel(from: device, isConnected: false)

        connectedDevices.removeAll(where: { $0.address == addr })

        if isInitialized {
            triggerLiveActivity(device: model, status: .disconnected)
        }
    }

    public func triggerLiveActivity(device: BluetoothConnectedDevice, status: BluetoothConnectionStatus) {
        guard Defaults[.showBluetoothNotifications] else { return }

        self.lastEventDevice = device
        self.lastEventStatus = status

        ZenythViewCoordinator.shared.toggleExpandingView(status: true, type: .bluetooth)
    }

    public func refreshBatteries() {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return }
        for i in 0..<connectedDevices.count {
            let addr = connectedDevices[i].address
            if let dev = paired.first(where: { $0.addressString == addr }) {
                if let battery = Self.queryBattery(for: dev) {
                    connectedDevices[i].batteryLevel = battery
                }
            }
        }
    }

    public func simulateNotification(connected: Bool = true) {
        let simulated = BluetoothConnectedDevice(
            address: "00:11:22:33:44:55",
            name: connected ? "AirPods Pro" : "Magic Mouse",
            iconName: connected ? "airpodspro" : "magicmouse",
            batteryLevel: connected ? 85 : nil,
            isConnected: connected
        )
        triggerLiveActivity(device: simulated, status: connected ? .connected : .disconnected)
    }

    private func createDeviceModel(from device: IOBluetoothDevice, isConnected: Bool) -> BluetoothConnectedDevice {
        let name = device.name ?? device.nameOrAddress ?? "Bluetooth Device"
        let addr = device.addressString ?? UUID().uuidString
        let icon = Self.iconForDevice(name: name, majorClass: device.deviceClassMajor, minorClass: device.deviceClassMinor)
        let battery = isConnected ? Self.queryBattery(for: device) : nil

        return BluetoothConnectedDevice(
            address: addr,
            name: name,
            iconName: icon,
            batteryLevel: battery,
            isConnected: isConnected
        )
    }

    // Maps name & classes to SF Symbols
    public static func iconForDevice(name: String, majorClass: BluetoothDeviceClassMajor, minorClass: BluetoothDeviceClassMinor) -> String {
        let lower = name.lowercased()

        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpods pro") { return "airpodspro" }
        if lower.contains("airpods") { return "airpods" }
        if lower.contains("beats") || lower.contains("bose") || lower.contains("sony") || lower.contains("headphone") || lower.contains("wh-1000") || lower.contains("qc35") || lower.contains("qc45") {
            return "headphones"
        }
        if lower.contains("magic mouse") { return "magicmouse" }
        if lower.contains("mouse") || lower.contains("trackball") || lower.contains("mx master") || lower.contains("g11") {
            return "computermouse"
        }
        if lower.contains("keyboard") || lower.contains("keychron") || lower.contains("nuphy") {
            return "keyboard"
        }
        if lower.contains("trackpad") { return "magictrackpad" }
        if lower.contains("dualsense") || lower.contains("xbox") || lower.contains("controller") || lower.contains("gamepad") {
            return "gamecontroller"
        }
        if lower.contains("speaker") || lower.contains("homepod") || lower.contains("soundbar") || lower.contains("jbl") {
            return "speaker.wave.2"
        }

        // Check device classes
        if majorClass == kBluetoothDeviceClassMajorAudio {
            if minorClass == kBluetoothDeviceClassMinorAudioLoudspeaker {
                return "speaker.wave.2"
            }
            return "headphones"
        } else if majorClass == kBluetoothDeviceClassMajorPeripheral {
            if (minorClass & kBluetoothDeviceClassMinorPeripheral1Keyboard) != 0 {
                return "keyboard"
            }
            if (minorClass & kBluetoothDeviceClassMinorPeripheral1Pointing) != 0 {
                return "computermouse"
            }
            if minorClass == kBluetoothDeviceClassMinorPeripheral2Gamepad || minorClass == kBluetoothDeviceClassMinorPeripheral2Joystick {
                return "gamecontroller"
            }
            return "computermouse"
        } else if majorClass == kBluetoothDeviceClassMajorPhone {
            return "iphone"
        }

        return "bluetooth"
    }

    // Query battery from KVC & IORegistry
    public static func queryBattery(for device: IOBluetoothDevice) -> Int? {
        // 1. Check KVC / selectors if supported
        if device.responds(to: Selector(("batteryPercentSingle"))) {
            if let val = device.value(forKey: "batteryPercentSingle") as? Int, val > 0 && val <= 100 {
                return val
            }
        }
        if device.responds(to: Selector(("batteryPercentCombined"))) {
            if let val = device.value(forKey: "batteryPercentCombined") as? Int, val > 0 && val <= 100 {
                return val
            }
        }
        var left = 0
        var right = 0
        if device.responds(to: Selector(("batteryPercentLeft"))), let val = device.value(forKey: "batteryPercentLeft") as? Int, val > 0 && val <= 100 {
            left = val
        }
        if device.responds(to: Selector(("batteryPercentRight"))), let val = device.value(forKey: "batteryPercentRight") as? Int, val > 0 && val <= 100 {
            right = val
        }
        if left > 0 || right > 0 {
            return max(left, right)
        }

        // 2. Query IORegistry
        return queryBatteryFromIORegistry(deviceName: device.name ?? "", address: device.addressString)
    }

    private static func queryBatteryFromIORegistry(deviceName: String, address: String?) -> Int? {
        let serviceClasses = ["AppleDeviceManagementHIDEventService", "AppleBluetoothHIDDevice", "IOHIDDevice"]
        for sc in serviceClasses {
            if let level = queryServiceClassForBattery(serviceClass: sc, deviceName: deviceName, address: address) {
                return level
            }
        }
        return nil
    }

    private static func queryServiceClassForBattery(serviceClass: String, deviceName: String, address: String?) -> Int? {
        let matching = IOServiceMatching(serviceClass)
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        let targetAddr = (address ?? "").replacingOccurrences(of: ":", with: "-").lowercased()
        let targetName = deviceName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            var properties: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = properties?.takeRetainedValue() as? [String: Any] else {
                continue
            }

            var isMatch = false
            if let devAddr = dict["DeviceAddress"] as? String {
                let cleanAddr = devAddr.replacingOccurrences(of: ":", with: "-").lowercased()
                if !targetAddr.isEmpty && cleanAddr == targetAddr {
                    isMatch = true
                }
            }
            if !isMatch, let product = dict["Product"] as? String {
                let cleanProduct = product.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if !targetName.isEmpty && (cleanProduct == targetName || targetName.contains(cleanProduct) || cleanProduct.contains(targetName)) {
                    isMatch = true
                }
            }

            if isMatch {
                if let battery = dict["BatteryPercent"] as? Int, battery >= 0 && battery <= 100 {
                    return battery
                }
                if let battery = dict["BatteryStatus"] as? Int, battery >= 0 && battery <= 100 {
                    return battery
                }
            }
        }
        return nil
    }

    deinit {
        connectNotification?.unregister()
        for (_, notif) in disconnectNotifications {
            notif.unregister()
        }
        batteryTimer?.invalidate()
    }
}
