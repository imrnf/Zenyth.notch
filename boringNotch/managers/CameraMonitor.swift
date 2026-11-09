//
//  CameraMonitor.swift
//  boringNotch
//
//  Derived from Atoll project.
//  Licensed under GNU General Public License v3.0.
//

import Foundation
import CoreMediaIO
import AVFoundation
import SwiftUI
import Combine

private func cameraPropertyListener(
    objectID: CMIOObjectID,
    numberAddresses: UInt32,
    addresses: UnsafePointer<CMIOObjectPropertyAddress>?,
    clientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let context = clientData else { return OSStatus(kCMIOHardwareNoError) }
    let monitor = Unmanaged<CameraMonitor>.fromOpaque(context).takeUnretainedValue()

    DispatchQueue.main.async {
        monitor.checkCameraStatus()
    }

    return OSStatus(kCMIOHardwareNoError)
}

@MainActor
class CameraMonitor: ObservableObject {
    @Published var isCameraActive: Bool = false
    @Published var isMonitoring: Bool = false

    private var isListenerRegistered: Bool = false
    private var cameraDeviceIDs: [CMIOObjectID] = []

    init() {}

    deinit {
        if isListenerRegistered, !cameraDeviceIDs.isEmpty {
            var propertyAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
            )

            let context = Unmanaged.passUnretained(self).toOpaque()

            for deviceID in cameraDeviceIDs {
                CMIOObjectRemovePropertyListener(
                    deviceID,
                    &propertyAddress,
                    cameraPropertyListener,
                    context
                )
            }
        }
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        cameraDeviceIDs = getCameraDeviceIDs()
        guard !cameraDeviceIDs.isEmpty else { return }

        setupPropertyListeners()
        checkCameraStatus()
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        if isListenerRegistered {
            removePropertyListeners()
        }

        if isCameraActive {
            isCameraActive = false
        }
    }

    private func getCameraDeviceIDs() -> [CMIOObjectID] {
        var propertyAddress = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )

        var dataSize: UInt32 = 0
        let status = CMIOObjectGetPropertyDataSize(
            CMIOObjectID(kCMIOObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == OSStatus(kCMIOHardwareNoError), dataSize > 0 else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        var deviceIDs = [CMIOObjectID](repeating: 0, count: deviceCount)

        let getStatus = CMIOObjectGetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            dataSize,
            &dataSize,
            &deviceIDs
        )

        guard getStatus == OSStatus(kCMIOHardwareNoError) else { return [] }
        return deviceIDs
    }

    private func setupPropertyListeners() {
        guard !isListenerRegistered else { return }

        var propertyAddress = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
        )

        let context = Unmanaged.passUnretained(self).toOpaque()

        for deviceID in cameraDeviceIDs {
            let status = CMIOObjectAddPropertyListener(
                deviceID,
                &propertyAddress,
                cameraPropertyListener,
                context
            )
            if status == OSStatus(kCMIOHardwareNoError) {
                isListenerRegistered = true
            }
        }
    }

    private func removePropertyListeners() {
        guard isListenerRegistered else { return }

        var propertyAddress = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
        )

        let context = Unmanaged.passUnretained(self).toOpaque()

        for deviceID in cameraDeviceIDs {
            CMIOObjectRemovePropertyListener(
                deviceID,
                &propertyAddress,
                cameraPropertyListener,
                context
            )
        }

        isListenerRegistered = false
    }

    func checkCameraStatus() {
        var isAnyCameraRunning = false

        for deviceID in cameraDeviceIDs {
            var isRunning: UInt32 = 0
            var dataSize = UInt32(MemoryLayout<UInt32>.size)
            var propertyAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
            )

            let status = CMIOObjectGetPropertyData(
                deviceID,
                &propertyAddress,
                0,
                nil,
                dataSize,
                &dataSize,
                &isRunning
            )

            if status == OSStatus(kCMIOHardwareNoError) && isRunning != 0 {
                isAnyCameraRunning = true
                break
            }
        }

        if isCameraActive != isAnyCameraRunning {
            withAnimation(.smooth) {
                self.isCameraActive = isAnyCameraRunning
            }
        }
    }
}
