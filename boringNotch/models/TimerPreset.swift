//
//  TimerPreset.swift
//  boringNotch
//
//  Licensed under GNU General Public License v3.0.
//

import SwiftUI

public struct TimerPreset: Identifiable, Hashable {
    public let id: UUID
    public let title: String
    public let duration: TimeInterval
    public let icon: String
    public let color: Color

    public init(id: UUID = UUID(), title: String, duration: TimeInterval, icon: String = "timer", color: Color = .blue) {
        self.id = id
        self.title = title
        self.duration = duration
        self.icon = icon
        self.color = color
    }

    public static let standardPresets: [TimerPreset] = [
        TimerPreset(title: "1m", duration: 60, icon: "bolt.fill", color: .yellow),
        TimerPreset(title: "5m", duration: 300, icon: "cup.and.saucer.fill", color: .orange),
        TimerPreset(title: "10m", duration: 600, icon: "timer", color: .blue),
        TimerPreset(title: "15m", duration: 900, icon: "brain.head.profile", color: .purple),
        TimerPreset(title: "25m Pomodoro", duration: 1500, icon: "flame.fill", color: .red),
        TimerPreset(title: "30m", duration: 1800, icon: "book.fill", color: .indigo),
        TimerPreset(title: "1h", duration: 3600, icon: "hourglass", color: .green)
    ]
}

