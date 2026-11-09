//
//  MicrophoneMonitor.swift
//  boringNotch
//
//  Derived from Atoll project.
//  Licensed under GNU General Public License v3.0.
//

import Foundation
import CoreAudio
import SwiftUI
import Combine

private func microphonePropertyListener(
    inObjectID: AudioObjectID,
    inNumberAddresses: UInt32,
    inAddresses: UnsafePointer<AudioObjectPropertyAddress>,
    inClientData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let context = inClientData else { return noErr }
    let monitor = Unmanaged<MicrophoneMonitor>.fromOpaque(context).takeUnretainedValue()

    DispatchQueue.main.async {
        monitor.checkMicrophoneStatus()
    }

    return noErr
}

@MainActor
class MicrophoneMonitor: ObservableObject {
    @Published var isMicActive: Bool = false
    @Published var isMonitoring: Bool = false

    private var defaultInputDevice: AudioDeviceID = 0
    private var isListenerRegistered: Bool = false

    init() {}

    deinit {
        if isListenerRegistered, defaultInputDevice != 0 {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            let context = Unmanaged.passUnretained(self).toOpaque()

            AudioObjectRemovePropertyListener(
                defaultInputDevice,
                &address,
                microphonePropertyListener,
                context
            )
        }
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        defaultInputDevice = getDefaultInputDevice()
        guard defaultInputDevice != 0 else { return }

        setupPropertyListener()
        checkMicrophoneStatus()
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        if isListenerRegistered {
            removePropertyListener()
        }

        if isMicActive {
            isMicActive = false
        }
    }

    private func getDefaultInputDevice() -> AudioDeviceID {
        var deviceID = AudioDeviceID(0)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceID
        )

        return status == noErr ? deviceID : 0
    }

    private func setupPropertyListener() {
        guard !isListenerRegistered, defaultInputDevice != 0 else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let context = Unmanaged.passUnretained(self).toOpaque()

        let status = AudioObjectAddPropertyListener(
            defaultInputDevice,
            &address,
            microphonePropertyListener,
            context
        )

        if status == noErr {
            isListenerRegistered = true
        }
    }

    private func removePropertyListener() {
        guard isListenerRegistered, defaultInputDevice != 0 else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let context = Unmanaged.passUnretained(self).toOpaque()

        AudioObjectRemovePropertyListener(
            defaultInputDevice,
            &address,
            microphonePropertyListener,
            context
        )

        isListenerRegistered = false
    }

    func checkMicrophoneStatus() {
        guard defaultInputDevice != 0 else {
            isMicActive = false
            return
        }

        var isRunning: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            defaultInputDevice,
            &address,
            0,
            nil,
            &dataSize,
            &isRunning
        )

        let active = (status == noErr && isRunning != 0)
        if isMicActive != active {
            withAnimation(.smooth) {
                self.isMicActive = active
            }
        }
    }
}

