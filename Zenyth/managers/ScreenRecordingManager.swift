//
//  ScreenRecordingManager.swift
//  boringNotch
//
//  Derived from Atoll project.
//  Licensed under GNU General Public License v3.0.
//

import AppKit
import Foundation
import SwiftUI

@_silgen_name("CGSIsScreenWatcherPresent")
private func CGSIsScreenWatcherPresent() -> Bool

@MainActor
final class ScreenRecordingManager: ObservableObject {
    static let shared = ScreenRecordingManager()

    @Published private(set) var isRecording: Bool = false
    private var checkTimer: Timer?

    private init() {
        startMonitoring()
    }

    deinit {
        checkTimer?.invalidate()
    }

    func startMonitoring() {
        updateRecordingStatus()
        checkTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateRecordingStatus()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        checkTimer = timer
    }

    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
        isRecording = false
    }

    func updateRecordingStatus() {
        let active = CGSIsScreenWatcherPresent()
        if isRecording != active {
            withAnimation(.smooth(duration: 0.3)) {
                self.isRecording = active
            }
        }
    }
}

