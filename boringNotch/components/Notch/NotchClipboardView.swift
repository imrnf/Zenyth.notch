//
//  NotchClipboardView.swift
//  boringNotch
//
//  Licensed under GNU General Public License v3.0.
//

import SwiftUI

struct NotchClipboardView: View {
    @ObservedObject var clipboard = ClipboardManager.shared
    @State private var searchText: String = ""
    @State private var selectedFilter: ClipboardFilter = .all
    @State private var copiedItemId: UUID?

    enum ClipboardFilter: String, CaseIterable {
        case all = "All"
        case text = "Text"
        case links = "Links"
        case pinned = "Pinned"
    }

    private var filteredItems: [ClipboardItem] {
        clipboard.items.filter { item in
            let matchesFilter: Bool
            switch selectedFilter {
            case .all: matchesFilter = true
            case .text: matchesFilter = (item.type == .text)
            case .links: matchesFilter = (item.type == .url)
            case .pinned: matchesFilter = item.isPinned
            }

            guard matchesFilter else { return false }

            if searchText.isEmpty {
                return true
            } else {
                return item.content.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header: Filter Chips, Search, & Clear
            HStack(spacing: 8) {
                // Filter Chips
                HStack(spacing: 4) {
                    ForEach(ClipboardFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            withAnimation(.smooth) {
                                selectedFilter = filter
                            }
                        }) {
                            Text(filter.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectedFilter == filter ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
                                .foregroundColor(selectedFilter == filter ? .white : .secondary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                Spacer()

                // Search Bar
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    TextField("Search clipboard...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 11))
                        .frame(width: 140)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())

                // Clear History Button
                if !clipboard.items.isEmpty {
                    Button(action: {
                        withAnimation {
                            clipboard.clearHistory()
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Clear History (retains pinned)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Content: Item Cards
            if filteredItems.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "clipboard")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(searchText.isEmpty ? "Clipboard is empty" : "No matching items")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxHeight: 120)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(filteredItems) { item in
                            ClipboardCard(
                                item: item,
                                isJustCopied: copiedItemId == item.id,
                                onCopy: {
                                    clipboard.copyToPasteboard(item: item)
                                    withAnimation {
                                        copiedItemId = item.id
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                        if copiedItemId == item.id {
                                            copiedItemId = nil
                                        }
                                    }
                                },
                                onTogglePin: {
                                    withAnimation {
                                        clipboard.togglePin(item: item)
                                    }
                                },
                                onDelete: {
                                    withAnimation {
                                        clipboard.deleteItem(item: item)
                                    }
                                }
                            )
                            .frame(width: 175, height: 115)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
            }
        }
        .onAppear {
            clipboard.startMonitoring()
        }
    }
}

// MARK: - Clipboard Card Component
struct ClipboardCard: View {
    let item: ClipboardItem
    let isJustCopied: Bool
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Type Icon + Pinned Status + Delete
            HStack(spacing: 4) {
                Image(systemName: item.type.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(item.type.color)

                Text(item.type.rawValue.capitalized)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(item.type.color)

                Spacer()

                Button(action: onTogglePin) {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 9))
                        .foregroundColor(item.isPinned ? .orange : .secondary.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Preview Text
            Text(item.preview)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            Spacer(minLength: 0)

            // Bottom: Copy button & Timestamp
            HStack {
                Text(item.timestamp, style: .time)
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: onCopy) {
                    HStack(spacing: 3) {
                        Image(systemName: isJustCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9))
                        Text(isJustCopied ? "Copied" : "Copy")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(isJustCopied ? .green : .white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isJustCopied ? Color.green.opacity(0.2) : Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(item.isPinned ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        )
    }
}

