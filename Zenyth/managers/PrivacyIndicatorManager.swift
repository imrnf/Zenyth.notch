//
//  PrivacyIndicatorManager.swift
//  boringNotch
//
//  Derived from Atoll project.
//  Licensed under GNU General Public License v3.0.
//

import Combine
import Defaults
import Foundation
import SwiftUI

enum PrivacyIndicatorType {
    case camera
    case microphone

    var icon: String {
        switch self {
        case .camera: return "video.fill"
        case .microphone: return "mic.fill"
        }
    }
}

@MainActor
final class PrivacyIndicatorManager: ObservableObject {
    static let shared = PrivacyIndicatorManager()

    @Published var cameraActive: Bool = false
    @Published var microphoneActive: Bool = false
    @Published var screenRecordingActive: Bool = false

    private let cameraMonitor = CameraMonitor()
    private let microphoneMonitor = MicrophoneMonitor()
    private let screenRecordingManager = ScreenRecordingManager.shared
    private var cancellables = Set<AnyCancellable>()

    var hasAnyIndicator: Bool {
        let showCam = cameraActive && Defaults[.enableCameraDetection]
        let showMic = microphoneActive && Defaults[.enableMicrophoneDetection]
        let showRec = screenRecordingActive && Defaults[.enableScreenRecordingDetection]
        return showCam || showMic || showRec
    }

    private init() {
        setupBindings()
        cameraMonitor.startMonitoring()
        microphoneMonitor.startMonitoring()
    }

    private func setupBindings() {
        cameraMonitor.$isCameraActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in
                guard let self else { return }
                if self.cameraActive != active {
                    withAnimation(.smooth(duration: 0.25)) {
                        self.cameraActive = active
                    }
                }
            }
            .store(in: &cancellables)

        microphoneMonitor.$isMicActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in
                guard let self else { return }
                if self.microphoneActive != active {
                    withAnimation(.smooth(duration: 0.25)) {
                        self.microphoneActive = active
                    }
                }
            }
            .store(in: &cancellables)

        screenRecordingManager.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in
                guard let self else { return }
                if self.screenRecordingActive != active {
                    withAnimation(.smooth(duration: 0.25)) {
                        self.screenRecordingActive = active
                    }
                }
            }
            .store(in: &cancellables)
    }
}

