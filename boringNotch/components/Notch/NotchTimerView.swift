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
        HStack(spacing: 16) {
            if timerManager.isTimerActive {
                activeTimerContent
            } else {
                idleTimerContent
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    // MARK: - Idle State
    private var idleTimerContent: some View {
        HStack(spacing: 16) {
            // Left: Custom Duration Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Custom Timer")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    VStack(spacing: 1) {
                        Text("\(customMinutes)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("min")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 40)

                    Stepper("", value: $customMinutes, in: 1...120)
                        .labelsHidden()

                    VStack(spacing: 1) {
                        Text(String(format: "%02d", customSeconds))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("sec")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 40)

                    Stepper("", value: $customSeconds, in: 0...59, step: 15)
                        .labelsHidden()
                }

                Button(action: {
                    let total = Double(customMinutes * 60 + customSeconds)
                    if total > 0 {
                        timerManager.startTimer(duration: total, name: "Timer")
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                        Text("Start Timer")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .frame(width: 190)

            Divider()
                .frame(height: 75)
                .opacity(0.3)

            // Right: Presets in 2 rows
            VStack(alignment: .leading, spacing: 6) {
                Text("Quick Presets")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)

                // Row 1: 1m, 5m, 10m, 15m
                HStack(spacing: 6) {
                    ForEach(TimerPreset.standardPresets.prefix(4)) { preset in
                        presetButton(preset)
                    }
                }

                // Row 2: 25m Pomodoro, 30m, 1h
                HStack(spacing: 6) {
                    ForEach(TimerPreset.standardPresets.suffix(3)) { preset in
                        presetButton(preset)
                    }
                }
            }
        }
    }

    private func presetButton(_ preset: TimerPreset) -> some View {
        Button(action: {
            timerManager.startTimer(duration: preset.duration, name: preset.title, preset: preset)
        }) {
            HStack(spacing: 4) {
                Image(systemName: preset.icon)
                    .font(.system(size: 10))
                    .foregroundColor(preset.color)
                Text(preset.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 7)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Active State
    private var activeTimerContent: some View {
        HStack(spacing: 20) {
            // Circular Progress on Left
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 6)
                    .frame(width: 72, height: 72)

                Circle()
                    .trim(from: 0, to: CGFloat(timerManager.progress))
                    .stroke(timerManager.timerColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 72, height: 72)
                    .animation(.linear(duration: 0.5), value: timerManager.progress)

                VStack(spacing: 2) {
                    Image(systemName: timerManager.activePreset?.icon ?? "timer")
                        .font(.system(size: 16))
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
            .frame(width: 80)

            // Middle: Digits & Name
            VStack(alignment: .leading, spacing: 2) {
                Text(timerManager.timerName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Text(timerManager.formattedRemainingTime)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(timerManager.isFinished ? .red : .primary)
                    .monospacedDigit()
            }

            Spacer()

            // Right: Controls
            VStack(spacing: 6) {
                HStack(spacing: 6) {
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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                HStack(spacing: 6) {
                    Button(action: {
                        timerManager.addTime(seconds: 60)
                    }) {
                        Text("+1 min")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: {
                        timerManager.addTime(seconds: 300)
                    }) {
                        Text("+5 min")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

