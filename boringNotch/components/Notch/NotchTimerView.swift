//
//  NotchTimerView.swift
//  boringNotch
//
//  Licensed under GNU General Public License v3.0.
//

import SwiftUI

struct NotchTimerView: View {
    @ObservedObject var timerManager = TimerManager.shared
    @State private var customMinutes: Int = 10
    @State private var customSeconds: Int = 0

    var body: some View {
        HStack(spacing: 20) {
            if timerManager.isTimerActive {
                activeTimerContent
            } else {
                idleTimerContent
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Idle State
    private var idleTimerContent: some View {
        HStack(spacing: 24) {
            // Left: Custom Duration Picker
            VStack(alignment: .leading, spacing: 10) {
                Text("Custom Timer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    VStack {
                        Text("\(customMinutes)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("min")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 50)

                    Stepper("", value: $customMinutes, in: 1...120)
                        .labelsHidden()

                    VStack {
                        Text(String(format: "%02d", customSeconds))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("sec")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 50)

                    Stepper("", value: $customSeconds, in: 0...59, step: 15)
                        .labelsHidden()
                }

                Button(action: {
                    let total = Double(customMinutes * 60 + customSeconds)
                    if total > 0 {
                        timerManager.startTimer(duration: total, name: "Timer")
                    }
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Timer")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(width: 220)

            Divider()
                .frame(height: 100)
                .opacity(0.3)

            // Right: Presets Grid
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Presets")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                    ForEach(TimerPreset.standardPresets) { preset in
                        Button(action: {
                            timerManager.startTimer(duration: preset.duration, name: preset.title, preset: preset)
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: preset.icon)
                                    .font(.system(size: 11))
                                    .foregroundColor(preset.color)
                                Text(preset.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 8)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Active State
    private var activeTimerContent: some View {
        HStack(spacing: 24) {
            // Circular Progress on Left
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 90, height: 90)

                Circle()
                    .trim(from: 0, to: CGFloat(timerManager.progress))
                    .stroke(timerManager.timerColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 90, height: 90)
                    .animation(.linear(duration: 0.5), value: timerManager.progress)

                VStack(spacing: 2) {
                    Image(systemName: timerManager.activePreset?.icon ?? "timer")
                        .font(.system(size: 18))
                        .foregroundColor(timerManager.timerColor)
                    if timerManager.isPaused {
                        Text("PAUSED")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.orange)
                    } else if timerManager.isFinished {
                        Text("DONE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
            }
            .frame(width: 100)

            // Middle: Digits & Name
            VStack(alignment: .leading, spacing: 4) {
                Text(timerManager.timerName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)

                Text(timerManager.formattedRemainingTime)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(timerManager.isFinished ? .red : .primary)
                    .monospacedDigit()
            }

            Spacer()

            // Right: Controls
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Button(action: {
                        if timerManager.isPaused {
                            timerManager.resumeTimer()
                        } else {
                            timerManager.pauseTimer()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: timerManager.isPaused ? "play.fill" : "pause.fill")
                            Text(timerManager.isPaused ? "Resume" : "Pause")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        timerManager.stopTimer()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                            Text("Cancel")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                HStack(spacing: 8) {
                    Button(action: {
                        timerManager.addTime(seconds: 60)
                    }) {
                        Text("+1 min")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        timerManager.addTime(seconds: 300)
                    }) {
                        Text("+5 min")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

