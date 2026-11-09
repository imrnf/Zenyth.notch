//
//  MediaOutputSelectorPopover.swift
//  boringNotch
//
//  Derived from Atoll project.
//  Licensed under GNU General Public License v3.0.
//

import SwiftUI

struct MediaOutputSelectorPopover: View {
    @ObservedObject var routeManager = AudioRouteManager.shared
    @ObservedObject var volumeManager = VolumeManager.shared
    var dismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Volume Section
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Button {
                        volumeManager.toggleMuteAction()
                    } label: {
                        Image(systemName: volumeManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.secondary.opacity(0.18)))
                    }
                    .buttonStyle(.plain)

                    Slider(
                        value: Binding(
                            get: { Double(volumeManager.rawVolume) },
                            set: { newValue in
                                volumeManager.setAbsolute(Float(newValue))
                            }
                        ),
                        in: 0...1
                    )
                    .tint(.accentColor)
                }

                HStack {
                    Text("Output Volume")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(volumeManager.rawVolume * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Devices Section
            VStack(alignment: .leading, spacing: 6) {
                Text("Output Devices")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                if routeManager.devices.isEmpty {
                    Text("No audio devices found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 4) {
                            ForEach(routeManager.devices) { device in
                                let isSelected = (device.id == routeManager.activeDeviceID)

                                Button {
                                    routeManager.select(device: device)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: device.iconName)
                                            .font(.system(size: 13))
                                            .foregroundColor(isSelected ? .accentColor : .primary)
                                            .frame(width: 18)

                                        Text(device.name)
                                            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                                            .foregroundColor(isSelected ? .accentColor : .primary)
                                            .lineLimit(1)

                                        Spacer()

                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                }
            }
        }
        .frame(width: 230)
        .padding(14)
        .onAppear {
            routeManager.refreshDevices()
        }
    }
}
