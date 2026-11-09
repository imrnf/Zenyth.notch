//
//  AmazonMusicController.swift
//  Zenyth
//
//  Derived from Zenyth.notch and Atoll projects.
//  Licensed under GNU General Public License v3.0.
//

import AppKit
import Foundation

final class AmazonMusicController: FilteredNowPlayingController {
    static let bundleIdentifier = "com.amazon.music"

    init?() {
        super.init(
            bundleIdentifier: Self.bundleIdentifier,
            controllerName: "AmazonMusicController"
        )
    }
}

