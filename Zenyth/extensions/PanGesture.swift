//
//  PanGesture.swift
//  Zenyth
//
//  Created by Richard Kunkli on 21/08/2024.
//

import AppKit
import SwiftUI

enum PanDirection {
    case left, right, up, down

    var isHorizontal: Bool { self == .left || self == .right }
    var sign: CGFloat { (self == .right || self == .down) ? 1 : -1 }

    func signed(from translation: CGSize) -> CGFloat { (isHorizontal ? translation.width : translation.height) * sign }
    func signed(deltaX: CGFloat, deltaY: CGFloat) -> CGFloat { (isHorizontal ? deltaX : deltaY) * sign }
}

extension View {
    func panGesture(direction: PanDirection, threshold: CGFloat = 4, action: @escaping (CGFloat, NSEvent.Phase) -> Void) -> some View {
        self
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let s = direction.signed(from: value.translation)
                        guard s > 0, s.magnitude >= threshold else { return }
                        action(s.magnitude, .changed)
                    }
                    .onEnded { _ in action(0, .ended) }
            )
            .background(ScrollMonitor(direction: direction, threshold: threshold, action: action))
    }
}

private struct ScrollMonitor: NSViewRepresentable {
    let direction: PanDirection
    let threshold: CGFloat
    let action: (CGFloat, NSEvent.Phase) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.installMonitor(on: view)
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) { coordinator.removeMonitor() }

    func makeCoordinator() -> Coordinator { 
        Coordinator(direction: direction, threshold: threshold, action: action) 
    }

    @MainActor final class Coordinator: NSObject {
        private let direction: PanDirection
        private let threshold: CGFloat
        private let action: (CGFloat, NSEvent.Phase) -> Void
        private var monitor: Any?
        private var accumulated: CGFloat = 0
        private var active = false
            private var endTask: Task<Void, Never>?
        private let noiseThreshold: CGFloat = 0.2

        init(direction: PanDirection, threshold: CGFloat, action: @escaping (CGFloat, NSEvent.Phase) -> Void) {
            self.direction = direction
            self.threshold = threshold
            self.action = action
        }

        private func scheduleEndTimeout() {
            // Cancel any existing scheduled end and schedule a new one.
            endTask?.cancel()
            endTask = Task { @MainActor in
                // If no new scroll event arrives within this window, consider the gesture ended.
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                if active {
                    action(accumulated.magnitude, .ended)
                } else {
                    action(0, .ended)
                }
                active = false
                accumulated = 0
            }
        }

        func installMonitor(on view: NSView) {
            removeMonitor()
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self, weak view] event in
                guard let self = self, event.window === view?.window else { return event }
                self.handleScroll(event)
                return event
            }
        }

        func removeMonitor() {
            if let monitor = monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            accumulated = 0
            active = false
            endTask?.cancel()
            endTask = nil
        }

        private func handleScroll(_ event: NSEvent) {
            if event.phase == .ended || event.momentumPhase == .ended {
                if active {
                    action(accumulated.magnitude, .ended)
                } else {
                    action(0, .ended)
                }
                active = false
                accumulated = 0
                return
            }

            // Only consider scroll events that are primarily along the configured axis.
            let absDX = abs(event.scrollingDeltaX)
            let absDY = abs(event.scrollingDeltaY)
            // Require the movement along the gesture axis to be at least 1.5x the orthogonal axis.
            let axisDominanceFactor: CGFloat = 1.5
            let isAxisDominant: Bool = direction.isHorizontal ? (absDX >= axisDominanceFactor * absDY) : (absDY >= axisDominanceFactor * absDX)
            guard isAxisDominant else { return }

            // Scale non-precise (mouse wheel) scrolling deltas so they feel similar to
            // trackpad gestures.
            let raw = direction.signed(deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY)
            let scale: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 8
            let s = raw * scale
            guard s.magnitude > noiseThreshold else { return }
            accumulated = s > 0 ? accumulated + s : 0

            if !active && accumulated >= threshold {
                active = true
                action(accumulated.magnitude, .began)
            } else if active {
                action(accumulated.magnitude, .changed)
            }
            // Schedule a timeout to end the gesture if no further scroll events arrive.
            scheduleEndTimeout()
        }
    }
}

// MARK: - Tab Navigation (Trackpad Swipe & Keyboard Arrow Keys)

extension View {
    func tabNavigation(
        isEnabled: Bool,
        onSwipe: @escaping (PanDirection) -> Void,
        onArrowKey: @escaping (Bool) -> Void
    ) -> some View {
        self.background(
            TabNavigationMonitor(
                isEnabled: isEnabled,
                onSwipe: onSwipe,
                onArrowKey: onArrowKey
            )
        )
    }
}

private struct TabNavigationMonitor: NSViewRepresentable {
    let isEnabled: Bool
    let onSwipe: (PanDirection) -> Void
    let onArrowKey: (Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.installMonitor(on: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isEnabled = isEnabled
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isEnabled: isEnabled, onSwipe: onSwipe, onArrowKey: onArrowKey)
    }

    @MainActor
    final class Coordinator: NSObject {
        var isEnabled: Bool
        let onSwipe: (PanDirection) -> Void
        let onArrowKey: (Bool) -> Void

        private var scrollMonitor: Any?
        private var keyMonitor: Any?
        private var accumulatedX: CGFloat = 0
        private var hasTriggeredInSwipe = false
        private var resetTask: Task<Void, Never>?

        init(isEnabled: Bool, onSwipe: @escaping (PanDirection) -> Void, onArrowKey: @escaping (Bool) -> Void) {
            self.isEnabled = isEnabled
            self.onSwipe = onSwipe
            self.onArrowKey = onArrowKey
        }

        func installMonitor(on view: NSView) {
            removeMonitor()

            // Trackpad two-finger horizontal scroll/swipe
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self, weak view] event in
                guard let self = self, self.isEnabled, event.window === view?.window else {
                    return event
                }

                if event.phase == .ended || event.phase == .cancelled || event.momentumPhase == .ended {
                    self.accumulatedX = 0
                    self.hasTriggeredInSwipe = false
                    self.resetTask?.cancel()
                    return event
                }

                let absX = abs(event.scrollingDeltaX)
                let absY = abs(event.scrollingDeltaY)
                guard absX >= 1.4 * absY, absX > 0.3 else {
                    return event
                }

                let scale: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 4
                self.accumulatedX += (event.scrollingDeltaX * scale)

                self.scheduleResetTimeout()

                let threshold: CGFloat = 26.0
                if !self.hasTriggeredInSwipe && abs(self.accumulatedX) >= threshold {
                    self.hasTriggeredInSwipe = true
                    if self.accumulatedX < 0 {
                        // Swiped left (fingers move right-to-left) -> Next Tab
                        self.onSwipe(.left)
                    } else {
                        // Swiped right (fingers move left-to-right) -> Previous Tab
                        self.onSwipe(.right)
                    }
                }

                return event
            }

            // Keyboard arrow keys (Left Arrow & Right Arrow)
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self, weak view] event in
                guard let self = self, self.isEnabled, event.window === view?.window else {
                    return event
                }

                // Don't intercept if user is typing in a text field or text view
                if let responder = event.window?.firstResponder,
                   responder is NSTextView || responder is NSTextField {
                    return event
                }

                if event.keyCode == 123 { // Left Arrow
                    self.onArrowKey(false) // Previous
                    return nil
                } else if event.keyCode == 124 { // Right Arrow
                    self.onArrowKey(true) // Next
                    return nil
                }

                return event
            }
        }

        private func scheduleResetTimeout() {
            resetTask?.cancel()
            resetTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(300))
                guard let self = self, !Task.isCancelled else { return }
                self.accumulatedX = 0
                self.hasTriggeredInSwipe = false
            }
        }

        func removeMonitor() {
            if let m = scrollMonitor {
                NSEvent.removeMonitor(m)
                scrollMonitor = nil
            }
            if let m = keyMonitor {
                NSEvent.removeMonitor(m)
                keyMonitor = nil
            }
            resetTask?.cancel()
            resetTask = nil
            accumulatedX = 0
            hasTriggeredInSwipe = false
        }
    }
}
