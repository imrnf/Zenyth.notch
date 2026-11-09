//
//  FilteredNowPlayingController.swift
//  boringNotch
//
//  Derived from boring.notch and Atoll projects.
//  Licensed under GNU General Public License v3.0.
//

import AppKit
import Combine
import Foundation

/// Media Remote stream filtered to one application. When another app owns Now
/// Playing, state idles so stale metadata from the selected player is not shown.
class FilteredNowPlayingController: ObservableObject, MediaControllerProtocol {

    func updatePlaybackInfo() async {}

    @Published private(set) var playbackState: PlaybackState

    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        $playbackState.eraseToAnyPublisher()
    }

    var supportsVolumeControl: Bool { false }
    var supportsFavorite: Bool { false }

    func setFavorite(_ favorite: Bool) async {}

    var isWorking: Bool {
        process != nil && process?.isRunning == true
    }

    private let mediaRemoteBundle: CFBundle
    private let MRMediaRemoteSendCommandFunction: @convention(c) (Int, AnyObject?) -> Void
    private let MRMediaRemoteSetElapsedTimeFunction: @convention(c) (Double) -> Void
    private let MRMediaRemoteSetShuffleModeFunction: @convention(c) (Int) -> Void
    private let MRMediaRemoteSetRepeatModeFunction: @convention(c) (Int) -> Void

    private var process: Process?
    private var pipeHandler: JSONLinesPipeHandler?
    private var streamTask: Task<Void, Never>?
    let targetBundleIdentifier: String
    private let controllerName: String

    /// True only after a stream line explicitly identified the selected app as the now playing source.
    private var targetSessionActive = false
    /// Diff lines omit the source. Remember when they belong to another app so
    /// they cannot overwrite a preserved target snapshot.
    private var competingSessionActive = false
    private var competingSessionSource: String?

    init?(bundleIdentifier: String, controllerName: String) {
        self.targetBundleIdentifier = bundleIdentifier
        self.controllerName = controllerName
        self.playbackState = Self.makeIdlePlaybackState(bundleIdentifier: bundleIdentifier)

        guard
            let bundle = CFBundleCreate(
                kCFAllocatorDefault,
                NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")),
            let MRMediaRemoteSendCommandPointer = CFBundleGetFunctionPointerForName(
                bundle, "MRMediaRemoteSendCommand" as CFString),
            let MRMediaRemoteSetElapsedTimePointer = CFBundleGetFunctionPointerForName(
                bundle, "MRMediaRemoteSetElapsedTime" as CFString),
            let MRMediaRemoteSetShuffleModePointer = CFBundleGetFunctionPointerForName(
                bundle, "MRMediaRemoteSetShuffleMode" as CFString),
            let MRMediaRemoteSetRepeatModePointer = CFBundleGetFunctionPointerForName(
                bundle, "MRMediaRemoteSetRepeatMode" as CFString)
        else { return nil }

        self.mediaRemoteBundle = bundle
        MRMediaRemoteSendCommandFunction = unsafeBitCast(
            MRMediaRemoteSendCommandPointer, to: (@convention(c) (Int, AnyObject?) -> Void).self)
        MRMediaRemoteSetElapsedTimeFunction = unsafeBitCast(
            MRMediaRemoteSetElapsedTimePointer, to: (@convention(c) (Double) -> Void).self)
        MRMediaRemoteSetShuffleModeFunction = unsafeBitCast(
            MRMediaRemoteSetShuffleModePointer, to: (@convention(c) (Int) -> Void).self)
        MRMediaRemoteSetRepeatModeFunction = unsafeBitCast(
            MRMediaRemoteSetRepeatModePointer, to: (@convention(c) (Int) -> Void).self)

        Task { await setupNowPlayingObserver() }
    }

    deinit {
        streamTask?.cancel()

        if let pipeHandler = self.pipeHandler {
            Task { await pipeHandler.close() }
        }

        if let process = self.process {
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
        }

        self.process = nil
        self.pipeHandler = nil
    }

    func play() async {
        MRMediaRemoteSendCommandFunction(0, nil)
    }

    func pause() async {
        MRMediaRemoteSendCommandFunction(1, nil)
    }

    func togglePlay() async {
        MRMediaRemoteSendCommandFunction(2, nil)
    }

    func nextTrack() async {
        MRMediaRemoteSendCommandFunction(4, nil)
    }

    func previousTrack() async {
        MRMediaRemoteSendCommandFunction(5, nil)
    }

    func toggleShuffle() async {
        let newShuffleMode = !playbackState.isShuffled
        MRMediaRemoteSetShuffleModeFunction(newShuffleMode ? 3 : 1)
        await MainActor.run {
            self.playbackState.isShuffled = newShuffleMode
        }
    }

    func toggleRepeat() async {
        let newRepeatMode: RepeatMode
        let newRepeatModeInt: Int

        switch playbackState.repeatMode {
        case .off:
            newRepeatMode = .all
            newRepeatModeInt = 3
        case .all:
            newRepeatMode = .one
            newRepeatModeInt = 2
        case .one:
            newRepeatMode = .off
            newRepeatModeInt = 1
        }

        MRMediaRemoteSetRepeatModeFunction(newRepeatModeInt)
        await MainActor.run {
            self.playbackState.repeatMode = newRepeatMode
        }
    }

    func seek(to time: Double) async {
        MRMediaRemoteSetElapsedTimeFunction(time)
        await MainActor.run {
            self.playbackState.currentTime = time
            self.playbackState.lastUpdated = Date()
        }
    }

    func setVolume(_ level: Double) async {}

    func isActive() -> Bool {
        isTargetAppRunning() && targetSessionActive && playbackState.isPlaying
    }

    func isTargetAppRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == targetBundleIdentifier
        }
    }

    static func makeIdlePlaybackState(bundleIdentifier: String) -> PlaybackState {
        var state = PlaybackState(bundleIdentifier: bundleIdentifier)
        state.title = ""
        state.artist = ""
        state.album = ""
        state.duration = 0
        state.currentTime = 0
        state.isPlaying = false
        state.isShuffled = false
        state.repeatMode = .off
        state.artwork = nil
        state.playbackRate = 1.0
        state.lastUpdated = Date()
        return state
    }

    private func setupNowPlayingObserver() async {
        let process = Process()
        guard
            let helperPath = Bundle.main.path(
                forResource: "MediaRemoteAdapterTestClient",
                ofType: nil,
                inDirectory: "mediaremote-adapter"
            )
        else {
            return
        }

        process.executableURL = URL(fileURLWithPath: helperPath)
        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        let pipeHandler = JSONLinesPipeHandler()
        self.pipeHandler = pipeHandler

        streamTask = Task { [weak self] in
            guard let self = self else { return }
            for await update in await pipeHandler.updates() {
                if Task.isCancelled { break }
                await self.handleAdapterUpdate(update)
            }
        }

        outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty else { return }
            Task {
                await pipeHandler.appendData(data)
            }
        }

        do {
            try process.run()
            self.process = process
        } catch {
            return
        }
    }

    func applyIdleBecauseDifferentSource() {
        targetSessionActive = false
        competingSessionActive = true
        competingSessionSource = nil
        playbackState = Self.makeIdlePlaybackState(bundleIdentifier: targetBundleIdentifier)
    }

    func shouldPreservePlaybackState(whenCompetingWith source: String) -> Bool {
        false
    }

    private func handleAdapterUpdate(_ update: NowPlayingUpdate) async {
        let payload = update.payload
        let diff = update.diff ?? false

        let explicitParent = payload.parentApplicationBundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        let explicitBundle = payload.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        let explicitSource: String? = {
            if let p = explicitParent, !p.isEmpty { return p }
            if let b = explicitBundle, !b.isEmpty { return b }
            return nil
        }()

        if let source = explicitSource {
            if source != targetBundleIdentifier {
                if shouldPreservePlaybackState(whenCompetingWith: source) {
                    competingSessionActive = true
                    competingSessionSource = source
                    return
                }
                applyIdleBecauseDifferentSource()
                return
            }
            targetSessionActive = true
            competingSessionActive = false
            competingSessionSource = nil
        } else if competingSessionActive {
            if let source = competingSessionSource,
               !shouldPreservePlaybackState(whenCompetingWith: source) {
                applyIdleBecauseDifferentSource()
            }
            return
        } else if !diff {
            applyIdleBecauseDifferentSource()
            return
        } else if !targetSessionActive {
            return
        }

        var newPlaybackState = PlaybackState(bundleIdentifier: targetBundleIdentifier)

        newPlaybackState.title = payload.title ?? (diff ? self.playbackState.title : "")
        newPlaybackState.artist = payload.artist ?? (diff ? self.playbackState.artist : "")
        newPlaybackState.album = payload.album ?? (diff ? self.playbackState.album : "")
        newPlaybackState.duration = payload.duration ?? (diff ? self.playbackState.duration : 0)
        newPlaybackState.currentTime = payload.elapsedTime ?? (diff ? self.playbackState.currentTime : 0)

        if let shuffleMode = payload.shuffleMode {
            newPlaybackState.isShuffled = shuffleMode != 1
        } else if !diff {
            newPlaybackState.isShuffled = false
        } else {
            newPlaybackState.isShuffled = self.playbackState.isShuffled
        }
        if let repeatModeValue = payload.repeatMode {
            newPlaybackState.repeatMode = RepeatMode(rawValue: repeatModeValue) ?? .off
        } else if !diff {
            newPlaybackState.repeatMode = .off
        } else {
            newPlaybackState.repeatMode = self.playbackState.repeatMode
        }

        if let artworkDataString = payload.artworkData {
            newPlaybackState.artwork = Data(
                base64Encoded: artworkDataString.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } else if !diff {
            newPlaybackState.artwork = nil
        }

        if let dateString = payload.timestamp,
           let date = ISO8601DateFormatter().date(from: dateString) {
            newPlaybackState.lastUpdated = date
        } else if !diff {
            newPlaybackState.lastUpdated = Date()
        } else {
            newPlaybackState.lastUpdated = self.playbackState.lastUpdated
        }

        newPlaybackState.playbackRate = payload.playbackRate ?? (diff ? self.playbackState.playbackRate : 1.0)
        newPlaybackState.isPlaying = payload.playing ?? (diff ? self.playbackState.isPlaying : false)
        newPlaybackState.bundleIdentifier = targetBundleIdentifier

        self.playbackState = newPlaybackState
    }
}

