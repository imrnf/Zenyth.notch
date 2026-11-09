//
//  ClipboardItem.swift
//  Zenyth
//
//  Licensed under GNU General Public License v3.0.
//

import Foundation
import SwiftUI
import AppKit

public enum ClipboardItemType: String, Codable, CaseIterable {
    case text
    case url
    case file
    case image

    public var icon: String {
        switch self {
        case .text: return "doc.text"
        case .url: return "link"
        case .file: return "doc"
        case .image: return "photo"
        }
    }

    public var color: Color {
        switch self {
        case .text: return .blue
        case .url: return .purple
        case .file: return .orange
        case .image: return .green
        }
    }
}

public struct ClipboardItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let type: ClipboardItemType
    public let content: String
    public let preview: String
    public let timestamp: Date
    public var isPinned: Bool

    public init(id: UUID = UUID(), type: ClipboardItemType, content: String, preview: String? = nil, timestamp: Date = Date(), isPinned: Bool = false) {
        self.id = id
        self.type = type
        self.content = content
        self.preview = preview ?? String(content.prefix(120)).trimmingCharacters(in: .whitespacesAndNewlines)
        self.timestamp = timestamp
        self.isPinned = isPinned
    }

    public static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        return lhs.id == rhs.id
    }
}

