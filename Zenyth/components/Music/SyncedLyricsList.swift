//
//  SyncedLyricsList.swift
//  boringNotch
//
//  Derived from Atoll and Zenyth.notch projects.
//  Licensed under GNU General Public License v3.0.
//

import SwiftUI
import Defaults

struct SyncedLyricsList: View {
    @ObservedObject var musicManager = MusicManager.shared
    var textColor: Color = .white
    var artistLineColor: Color = .gray

    @State private var autoScroll = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.2)) { timeline in
            let currentElapsed: Double = {
                guard musicManager.isPlaying else { return musicManager.elapsedTime }
                let delta = timeline.date.timeIntervalSince(musicManager.timestampDate)
                let progressed = musicManager.elapsedTime + (delta * musicManager.playbackRate)
                return min(max(progressed, 0), musicManager.songDuration)
            }()

            let currentIndex = activeIndex(for: currentElapsed)

            VStack(alignment: .leading, spacing: 0) {
                if musicManager.syncedLyrics.isEmpty {
                    VStack(alignment: .center, spacing: 8) {
                        Spacer()
                        Image(systemName: "quote.bubble")
                            .font(.system(size: 24))
                            .foregroundColor(.gray.opacity(0.6))
                        Text(musicManager.isFetchingLyrics ? "Fetching lyrics…" : "No synced lyrics available")
                            .font(.callout)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(alignment: .leading, spacing: 14) {
                                ForEach(0..<musicManager.syncedLyrics.count, id: \.self) { idx in
                                    let line = musicManager.syncedLyrics[idx]
                                    let isCurrent = (idx == currentIndex)

                                    Text(line.text)
                                        .font(.system(size: isCurrent ? 16 : 14, weight: isCurrent ? .bold : .medium, design: .rounded))
                                        .foregroundColor(isCurrent ? textColor : artistLineColor.opacity(0.6))
                                        .scaleEffect(isCurrent ? 1.05 : 1.0, anchor: .leading)
                                        .animation(.easeInOut(duration: 0.2), value: isCurrent)
                                        .id(idx)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            Task {
                                                await musicManager.seek(to: line.time)
                                            }
                                        }
                                }
                            }
                            .padding(.vertical, 20)
                            .padding(.horizontal, 12)
                        }
                        .onChange(of: currentIndex) { _, newIndex in
                            if autoScroll, newIndex >= 0 {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    proxy.scrollTo(newIndex, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func activeIndex(for elapsed: Double) -> Int {
        guard !musicManager.syncedLyrics.isEmpty else { return -1 }
        var active = -1
        for (index, item) in musicManager.syncedLyrics.enumerated() {
            if item.time <= elapsed {
                active = index
            } else {
                break
            }
        }
        return active
    }
}

