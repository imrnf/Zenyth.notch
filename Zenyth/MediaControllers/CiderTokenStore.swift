//
//  CiderTokenStore.swift
//  Zenyth
//
//  Keychain storage for Cider app token.
//  Derived from Atoll project.
//  Licensed under GNU General Public License v3.0.
//

import Foundation
import Security
import Defaults

final class CiderTokenStore: @unchecked Sendable {
    static let shared = CiderTokenStore()

    private static let service = "com.zenyth.notch.Cider"
    private static let account = "appToken"

    private let lock = NSLock()
    private var cached: String?

    private init() {
        cached = Self.readFromKeychain()
    }

    var token: String {
        lock.lock()
        defer { lock.unlock() }
        return cached ?? ""
    }

    func setToken(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        lock.lock()
        cached = trimmed.isEmpty ? nil : trimmed
        lock.unlock()

        if trimmed.isEmpty {
            Self.deleteFromKeychain()
        } else {
            Self.writeToKeychain(trimmed)
        }
    }

    // MARK: - Keychain
    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func readFromKeychain() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else { return nil }
        return value
    }

    @discardableResult
    private static func writeToKeychain(_ value: String) -> OSStatus {
        let data = Data(value.utf8)
        let update = [kSecValueData as String: data]

        let status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        guard status == errSecItemNotFound else { return status }

        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(attributes as CFDictionary, nil)
    }

    @discardableResult
    private static func deleteFromKeychain() -> OSStatus {
        let status = SecItemDelete(baseQuery as CFDictionary)
        return status == errSecItemNotFound ? errSecSuccess : status
    }
}

