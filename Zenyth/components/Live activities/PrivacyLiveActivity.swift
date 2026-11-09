//
//  PrivacyLiveActivity.swift
//  boringNotch
//
//  Derived from Atoll project.
//  Licensed under GNU General Public License v3.0.
//

import Defaults
import SwiftUI

struct PrivacyLiveActivity: View {
    @EnvironmentObject var vm: ZenythViewModel
    @ObservedObject var privacyManager = PrivacyIndicatorManager.shared
    @ObservedObject var recordingManager = ScreenRecordingManager.shared

    var body: some View {
        HStack(spacing: 6) {
            if recordingManager.isRecording && Defaults[.enableScreenRecordingDetection] {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 14, height: 14)
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
            }

            if privacyManager.microphoneActive && Defaults[.enableMicrophoneDetection] {
                Circle()
                    .fill(Color(red: 1.0, green: 0.584, blue: 0.01))
                    .frame(width: 8, height: 8)
            }

            if privacyManager.cameraActive && Defaults[.enableCameraDetection] {
                Circle()
                    .fill(Color(red: 0.152, green: 0.804, blue: 0.256))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 4)
    }
}

