//
//  CiderController.swift
//  boringNotch
//
//  Derived from Atoll project.
//  Licensed under GNU General Public License v3.0.
//

import AppKit
import Defaults
import Foundation

final class CiderController: FilteredNowPlayingController {
    static let bundleIdentifier = "sh.cider.genten.mac"

    init?() {
        super.init(
            bundleIdentifier: Self.bundleIdentifier,
            controllerName: "CiderController"
        )
    }

    override var supportsFavorite: Bool { CiderFavoriting.isAvailable }

    override func setFavorite(_ favorite: Bool) async {
        await CiderFavoriting.shared.setCurrentTrackFavorited(favorite)
    }
}

// MARK: - Cider Local API Favoriting
protocol CiderHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionCiderHTTPClient: CiderHTTPClient {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}

struct CiderFavoriting: Sendable {
    static let shared = CiderFavoriting()
    static let defaultPort = 10767

    static var defaultBaseURL: URL {
        URL(string: "http://localhost:\(defaultPort)/api/v1/playback")!
    }

    private let httpClient: CiderHTTPClient

    init(httpClient: CiderHTTPClient = URLSessionCiderHTTPClient()) {
        self.httpClient = httpClient
    }

    static var isAvailable: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == CiderController.bundleIdentifier
        }
    }

    func isCurrentTrackFavorited() async -> Bool? {
        guard Self.isAvailable else { return nil }
        guard let request = makeRequest(path: "current-playback-status", method: "GET") else {
            return nil
        }
        do {
            let (data, response) = try await httpClient.data(for: request)
            guard response.statusCode == 200 else { return nil }
            let status = try JSONDecoder().decode(CiderPlaybackStatusResponse.self, from: data)
            return status.inFavorites
        } catch {
            return nil
        }
    }

    @discardableResult
    func setCurrentTrackFavorited(_ favorited: Bool) async -> Bool {
        guard Self.isAvailable else { return false }
        guard let request = makeRequest(path: "set-rating", method: "POST", body: ["rating": favorited ? 1 : 0]) else {
            return false
        }
        do {
            let (_, response) = try await httpClient.data(for: request)
            return response.statusCode == 200
        } catch {
            return false
        }
    }

    private func makeRequest(path: String, method: String, body: [String: Any]? = nil) -> URLRequest? {
        guard let url = URL(string: "\(Self.defaultBaseURL)/\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 2

        let token = CiderTokenStore.shared.token
        if !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "apptoken")
        }

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }
}

private struct CiderPlaybackStatusResponse: Codable {
    let inFavorites: Bool?
}

