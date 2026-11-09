//
//  TimerLiveActivity.swift
//  boringNotch
//
//  Licensed under GNU General Public License v3.0.
//

import SwiftUI

struct TimerLiveActivity: View {
    @ObservedObject var timerManager = TimerManager.shared
    @EnvironmentObject var vm: BoringViewModel

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: timerManager.isPaused ? "pause.circle.fill" : "timer")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(timerManager.timerColor)

            Text(timerManager.formattedRemainingTime)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(timerManager.isFinished ? .red : .white)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.4))
        )
    }
}

