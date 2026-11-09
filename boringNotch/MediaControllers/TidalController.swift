//
//  TidalController.swift
//  boringNotch
//
//  Derived from Atoll project.
//  Licensed under GNU General Public License v3.0.
//

import AppKit
import ApplicationServices
import Foundation

final class TidalController: FilteredNowPlayingController {
    static let bundleIdentifier = "com.tidal.desktop"

    init?() {
        super.init(
            bundleIdentifier: Self.bundleIdentifier,
            controllerName: "TidalController"
        )
    }

    override var supportsFavorite: Bool { TidalAccessibility.isAvailable }

    override func setFavorite(_ favorite: Bool) async {
        // Tidal favorites are read-only via accessibility in macOS
    }

    override func toggleShuffle() async {
        let current = await TidalAccessibility.isShuffled() ?? playbackState.isShuffled
        guard await TidalAccessibility.setShuffled(!current) else { return }
        await MainActor.run { [weak self] in
            self?.playbackState.isShuffled = !current
        }
    }

    override func toggleRepeat() async {
        let current = await TidalAccessibility.repeatMode() ?? playbackState.repeatMode
        let next: RepeatMode
        switch current {
        case .off: next = .all
        case .all: next = .one
        case .one: next = .off
        }
        guard await TidalAccessibility.setRepeatMode(next) else { return }
        await MainActor.run { [weak self] in
            self?.playbackState.repeatMode = next
        }
    }
}

// MARK: - Tidal Accessibility Helper
struct TidalAccessibility {
    static var isAvailable: Bool {
        guard let app = runningApp else { return false }
        return !app.isTerminated
    }

    static func isShuffled() async -> Bool? {
        await onAccessibilityQueue {
            guard let item = playbackMenuItem(titled: shuffleTitle) else { return nil }
            return isChecked(item)
        }
    }

    static func setShuffled(_ wanted: Bool) async -> Bool {
        await onAccessibilityQueue {
            guard let item = playbackMenuItem(titled: shuffleTitle) else { return false }
            guard isChecked(item) != wanted else { return true }
            return press(item)
        }
    }

    static func repeatMode() async -> RepeatMode? {
        await onAccessibilityQueue {
            guard let items = repeatItems() else { return nil }
            for (index, mode) in repeatModeOrder.enumerated() {
                if isChecked(items[index]) { return mode }
            }
            return nil
        }
    }

    static func setRepeatMode(_ mode: RepeatMode) async -> Bool {
        await onAccessibilityQueue {
            guard let items = repeatItems(),
                  let wanted = repeatModeOrder.firstIndex(of: mode) else { return false }
            guard !isChecked(items[wanted]) else { return true }
            return press(items[wanted])
        }
    }

    private static let repeatModeOrder: [RepeatMode] = [.off, .all, .one]

    private static func repeatItems() -> [AXUIElement]? {
        guard let parent = playbackMenuItem(titled: repeatTitle),
              let submenu = (attribute(parent, kAXChildrenAttribute) as? [AXUIElement])?.first,
              let items = attribute(submenu, kAXChildrenAttribute) as? [AXUIElement],
              items.count == repeatModeOrder.count else { return nil }
        return items
    }

    private static let playbackMenuTitle = "Playback"
    private static let shuffleTitle = "Shuffle"
    private static let repeatTitle = "Repeat"

    private static func playbackMenuItem(titled title: String) -> AXUIElement? {
        guard let root = applicationElement(),
              let menuBar = attribute(root, kAXMenuBarAttribute) else { return nil }

        let bar = menuBar as! AXUIElement
        guard let menus = attribute(bar, kAXChildrenAttribute) as? [AXUIElement],
              let playback = menus.first(where: {
                  attribute($0, kAXTitleAttribute) as? String == playbackMenuTitle
              }),
              let menu = (attribute(playback, kAXChildrenAttribute) as? [AXUIElement])?.first,
              let items = attribute(menu, kAXChildrenAttribute) as? [AXUIElement] else { return nil }

        return items.first { attribute($0, kAXTitleAttribute) as? String == title }
    }

    private static func isChecked(_ item: AXUIElement) -> Bool {
        let mark = attribute(item, kAXMenuItemMarkCharAttribute) as? String
        return !(mark ?? "").isEmpty
    }

    private static let accessibilityQueue = DispatchQueue(
        label: "com.boringNotch.tidal.accessibility",
        qos: .userInitiated
    )

    private static var runningApp: NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == TidalController.bundleIdentifier }
    }

    private static func applicationElement() -> AXUIElement? {
        guard let app = runningApp else { return nil }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 1)
        return element
    }

    private static func press(_ element: AXUIElement) -> Bool {
        AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> Any? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private static func onAccessibilityQueue<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            accessibilityQueue.async { continuation.resume(returning: work()) }
        }
    }
}

