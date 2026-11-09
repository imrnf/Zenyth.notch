//
//  NotchStatsView.swift
//  boringNotch
//
//  Derived from Atoll project.
//  Licensed under GNU General Public License v3.0.
//

import SwiftUI

struct NotchStatsView: View {
    @ObservedObject var stats = StatsManager.shared

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                // CPU Card
                StatCard(
                    title: "CPU",
                    icon: "cpu",
                    value: String(format: "%.0f%%", stats.cpuUsage),
                    color: .blue,
                    history: stats.cpuHistory,
                    maxValue: 100
                )

                // Memory Card
                StatCard(
                    title: "Memory",
                    icon: "memorychip",
                    value: String(format: "%.1f/%.0f GB", stats.memoryUsedGB, stats.memoryTotalGB),
                    color: .green,
                    history: stats.memoryHistory,
                    maxValue: 100
                )

                // GPU Card
                StatCard(
                    title: "GPU",
                    icon: "display",
                    value: String(format: "%.0f%%", stats.gpuUsage),
                    color: .purple,
                    history: stats.gpuHistory,
                    maxValue: 100
                )
            }

            HStack(spacing: 10) {
                // Network Card
                StatCard(
                    title: "Network",
                    icon: "network",
                    value: String(format: "↓%.1f ↑%.1f MB/s", stats.networkDownloadMBs, stats.networkUploadMBs),
                    color: .orange,
                    history: stats.networkHistory,
                    maxValue: max(1.0, (stats.networkHistory.max() ?? 1.0))
                )

                // Disk Storage Card
                DiskStorageCard(
                    freeGB: stats.diskFreeGB,
                    totalGB: stats.diskTotalGB
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear {
            stats.startMonitoring()
        }
        .onDisappear {
            stats.stopMonitoring()
        }
    }
}

// MARK: - Stat Card with Sparkline
struct StatCard: View {
    let title: String
    let icon: String
    let value: String
    let color: Color
    let history: [Double]
    let maxValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }

            // Sparkline Graph
            SparklineView(data: history, maxValue: maxValue, color: color)
                .frame(height: 24)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
        )
    }
}

// MARK: - Disk Storage Card
struct DiskStorageCard: View {
    let freeGB: Double
    let totalGB: Double

    private var usedPercentage: Double {
        guard totalGB > 0 else { return 0 }
        return ((totalGB - freeGB) / totalGB) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.teal)
                Text("Storage")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.0f GB free", freeGB))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }

            // Storage Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.teal)
                        .frame(width: max(4, geo.size.width * CGFloat(usedPercentage / 100.0)), height: 8)
                }
            }
            .frame(height: 24)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
        )
    }
}

// MARK: - Sparkline View
struct SparklineView: View {
    let data: [Double]
    let maxValue: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxV = max(0.01, maxValue)

            if data.count > 1 {
                Path { path in
                    let step = w / CGFloat(data.count - 1)
                    for (i, val) in data.enumerated() {
                        let clamped = min(maxV, max(0, val))
                        let y = h - (CGFloat(clamped / maxV) * h)
                        let x = CGFloat(i) * step
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            } else {
                Color.clear
            }
        }
    }
}
