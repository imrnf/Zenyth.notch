//
//  TimerManager.swift
//  boringNotch
//
//  Licensed under GNU General Public License v3.0.
//

import SwiftUI
import AppKit
import Combine

public final class TimerManager: ObservableObject {
    public static let shared = TimerManager()

    @Published public var isTimerActive: Bool = false
    @Published public var timerName: String = "Timer"
    @Published public var totalDuration: TimeInterval = 0
    @Published public var remainingTime: TimeInterval = 0
    @Published public var elapsedTime: TimeInterval = 0
    @Published public var isPaused: Bool = false
    @Published public var isFinished: Bool = false
    @Published public var activePreset: TimerPreset?

    private var timerInstance: Timer?

    public var progress: Double {
        guard totalDuration > 0 else { return 0.0 }
        return min(1.0, max(0.0, elapsedTime / totalDuration))
    }

    public var timerColor: Color {
        if isFinished {
            return .red
        }
        if let preset = activePreset {
            return preset.color
        }
        let p = progress
        if p < 0.6 {
            return .green
        } else if p < 0.85 {
            return .orange
        } else {
            return .red
        }
    }

    public var formattedRemainingTime: String {
        let totalSecs = max(0, Int(remainingTime))
        let hours = totalSecs / 3600
        let minutes = (totalSecs % 3600) / 60
        let seconds = totalSecs % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private init() {}

    deinit {
        timerInstance?.invalidate()
    }

    // MARK: - Actions

    public func startTimer(duration: TimeInterval, name: String = "Timer", preset: TimerPreset? = nil) {
        timerInstance?.invalidate()

        totalDuration = duration
        remainingTime = duration
        elapsedTime = 0
        timerName = name
        activePreset = preset
        isPaused = false
        isFinished = false
        isTimerActive = true

        startInternalTimer()
    }

    public func pauseTimer() {
        guard isTimerActive && !isPaused else { return }
        isPaused = true
        timerInstance?.invalidate()
        timerInstance = nil
    }

    public func resumeTimer() {
        guard isTimerActive && isPaused else { return }
        isPaused = false
        startInternalTimer()
    }

    public func stopTimer() {
        timerInstance?.invalidate()
        timerInstance = nil
        isTimerActive = false
        isPaused = false
        isFinished = false
        remainingTime = 0
        elapsedTime = 0
        activePreset = nil
    }

    public func addTime(seconds: TimeInterval) {
        guard isTimerActive else { return }
        totalDuration += seconds
        remainingTime += seconds
        if isFinished {
            isFinished = false
            startInternalTimer()
        }
    }

    private func startInternalTimer() {
        timerInstance?.invalidate()
        timerInstance = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, !self.isPaused, self.isTimerActive else { return }

                if self.remainingTime > 1 {
                    self.remainingTime -= 1
                    self.elapsedTime = self.totalDuration - self.remainingTime
                } else if self.remainingTime <= 1 {
                    self.remainingTime = 0
                    self.elapsedTime = self.totalDuration
                    self.isFinished = true
                    self.timerInstance?.invalidate()
                    self.timerInstance = nil
                    self.playChime()
                }
            }
        }
    }

    private func playChime() {
        if let sound = NSSound(named: "Glass") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}

