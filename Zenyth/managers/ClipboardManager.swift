//
//  ClipboardManager.swift
//  Zenyth
//
//  Licensed under GNU General Public License v3.0.
//

import AppKit
import SwiftUI
import Combine

public final class ClipboardManager: ObservableObject {
    public static let shared = ClipboardManager()

    @Published public var items: [ClipboardItem] = []
    @Published public var isMonitoring: Bool = false

    private var changeCount: Int = 0
    private var timer: Timer?
    private let maxItems: Int = 30
    private var ignoreNextChange: Bool = false

    private init() {
        self.changeCount = NSPasteboard.general.changeCount
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        self.changeCount = NSPasteboard.general.changeCount

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount != self.changeCount else { return }
        self.changeCount = currentChangeCount

        if ignoreNextChange {
            ignoreNextChange = false
            return
        }

        // Check for URLs
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let firstURL = urls.first {
            if firstURL.isFileURL {
                addItem(type: .file, content: firstURL.path)
            } else {
                addItem(type: .url, content: firstURL.absoluteString)
            }
            return
        }

        // Check for Plain Text
        if let string = pasteboard.string(forType: .string), !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                addItem(type: .url, content: string)
            } else {
                addItem(type: .text, content: string)
            }
            return
        }
    }

    private func addItem(type: ClipboardItemType, content: String) {
        // Prevent duplicate consecutive entries
        if let first = items.first, first.content == content {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let newItem = ClipboardItem(type: type, content: content)

            // Remove existing duplicate if present
            self.items.removeAll { $0.content == content && !$0.isPinned }

            // Insert at top
            self.items.insert(newItem, at: 0)

            // Prune unpinned items exceeding maxItems
            let pinned = self.items.filter { $0.isPinned }
            let unpinned = self.items.filter { !$0.isPinned }
            if unpinned.count > self.maxItems {
                let trimmed = Array(unpinned.prefix(self.maxItems))
                self.items = (pinned + trimmed).sorted { $0.timestamp > $1.timestamp }
            }
        }
    }

    public func copyToPasteboard(item: ClipboardItem) {
        ignoreNextChange = true
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .text, .url:
            pasteboard.setString(item.content, forType: .string)
        case .file:
            let fileURL = URL(fileURLWithPath: item.content)
            pasteboard.writeObjects([fileURL as NSURL])
        case .image:
            pasteboard.setString(item.content, forType: .string)
        }
    }

    public func deleteItem(item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
    }

    public func togglePin(item: ClipboardItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isPinned.toggle()
        }
    }

    public func clearHistory() {
        // Retain pinned items
        items = items.filter { $0.isPinned }
    }
}

