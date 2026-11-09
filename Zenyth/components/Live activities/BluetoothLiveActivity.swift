//
//  BluetoothLiveActivity.swift
//  Zenyth
//
//  Derived from Atoll project.
//  Licensed under GNU General Public License v3.0.
//

import SwiftUI
import Defaults

/// Displays a live activity in the notch when a Bluetooth device connects or disconnects
struct BluetoothLiveActivity: View {
    let device: BluetoothConnectedDevice?
    let isConnecting: Bool
    @EnvironmentObject var vm: ZenythViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Left side: Device Icon & Name
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isConnecting ? Color.blue.opacity(0.2) : Color.white.opacity(0.1))
                        .frame(width: 24, height: 24)

                    Image(systemName: device?.iconName ?? (isConnecting ? "bluetooth" : "bluetooth.slash"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isConnecting ? Color.blue : Color.secondary)
                }

                Text(device?.name ?? "Bluetooth Device")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)

            // Center Notch Mask
            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width + 10)

            // Right side: Battery & Status
            HStack(spacing: 8) {
                if isConnecting {
                    if let battery = device?.batteryLevel, battery > 0 {
                        HStack(spacing: 5) {
                            CircularBatteryGauge(
                                level: Float(battery),
                                size: 16,
                                lineWidth: 2.2,
                                color: battery > 20 ? (battery <= 50 ? .yellow : .green) : .red
                            )
                            Text("\(battery)%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .monospacedDigit()
                        }
                    }

                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Connected")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                    }
                } else {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.secondary.opacity(0.8))
                            .frame(width: 6, height: 6)
                        Text("Disconnected")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 12)
        }
        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
    }
}

/// Circular gauge for battery level rendering
struct CircularBatteryGauge: View {
    var level: Float
    var size: CGFloat = 16
    var lineWidth: CGFloat = 2
    var color: Color = .green

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(level / 100.0, 0.0), 1.0)))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

/// 4-Slot Circular Battery Widget (matching Apple's Batteries widget)
struct ConnectedDevicesRingWidgetView: View {
    var macBatteryLevel: Float
    var macIsCharging: Bool
    var macIsInLowPowerMode: Bool
    var devices: [BluetoothConnectedDevice]

    private var macRingColor: Color {
        if macIsInLowPowerMode {
            return .yellow
        } else if macBatteryLevel <= 20 && !macIsCharging {
            return .red
        } else if macIsCharging || macBatteryLevel == 100 {
            return .green
        } else {
            return .yellow
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Slot 1: MacBook / Mac internal battery
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 3.5)
                        .frame(width: 44, height: 44)

                    Circle()
                        .trim(from: 0, to: CGFloat(min(max(macBatteryLevel / 100.0, 0.0), 1.0)))
                        .stroke(
                            macRingColor,
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 44, height: 44)

                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.white)
                }

                Text("\(Int(macBatteryLevel))%")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
            }

            // Slots 2, 3, 4: Connected devices or empty placeholder circles
            ForEach(0..<3, id: \.self) { index in
                if index < devices.count {
                    let dev = devices[index]
                    let battery = dev.batteryLevel ?? 100
                    let ringColor: Color = battery <= 20 ? .red : (battery <= 50 ? .yellow : .green)

                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.15), lineWidth: 3.5)
                                .frame(width: 44, height: 44)

                            Circle()
                                .trim(from: 0, to: CGFloat(min(max(Float(battery) / 100.0, 0.0), 1.0)))
                                .stroke(
                                    ringColor,
                                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 44, height: 44)

                            Image(systemName: dev.iconName)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundStyle(.white)
                        }

                        if let b = dev.batteryLevel {
                            Text("\(b)%")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                        } else {
                            Text("On")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    // Empty circular slot
                    VStack(spacing: 6) {
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 3.5)
                            .frame(width: 44, height: 44)

                        Text(" ")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.06))
        )
    }
}
