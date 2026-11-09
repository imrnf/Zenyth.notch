//
//  DoNotDisturbManager.swift
//  Zenyth
//
//  Derived from Atoll project.
//  Licensed under GNU General Public License v3.0.
//

import AppKit
import Combine
import Defaults
import Foundation
import SwiftUI

@MainActor
final class DoNotDisturbManager: ObservableObject {
    static let shared = DoNotDisturbManager()

    @Published var isDoNotDisturbActive: Bool = false
    @Published var focusModeName: String = "Do Not Disturb"

    private let assertionsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/DoNotDisturb/DB/Assertions.json")
    private var fileTimer: Timer?

    private init() {
        checkDNDStatus()
        startMonitoring()
    }

    deinit {
        fileTimer?.invalidate()
    }

    func startMonitoring() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleNotification),
            name: NSNotification.Name("com.apple.notificationcenter.donotdisturb.modechanged"),
            object: nil
        )

        fileTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkDNDStatus()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        fileTimer = timer
    }

    @objc private func handleNotification() {
        checkDNDStatus()
    }

    func checkDNDStatus() {
        guard FileManager.default.fileExists(atPath: assertionsURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: assertionsURL)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let assertions = json["data"] as? [[String: Any]] {
                let active = !assertions.isEmpty
                if isDoNotDisturbActive != active {
                    withAnimation(.smooth(duration: 0.3)) {
                        self.isDoNotDisturbActive = active
                    }
                }
            }
        } catch {
            // fallback
        }
    }
}

