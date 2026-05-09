//
//  KeychainHelper.swift
//  AISwitch
//
//  Two responsibilities, intentionally kept in one file:
//
//   1. Read/write generic-password Keychain items owned by *other* apps
//      (Claude.app, Claude CLI, ChatGPT.app, Codex CLI). These are the
//      OAuth refresh-token entries each surface stores. We talk to them via
//      the Security framework's `SecItem*` API.
//
//   2. Read/write our *own* Keychain entry that holds the AES-256-GCM key
//      we use to encrypt profile snapshots at rest (see §5 of the plan).
//
//  Reading another app's Keychain item triggers a one-time access prompt
//  the first time. The user clicks "Always Allow" and AISwitch is added to
//  the item's ACL. From then on it's silent.
//

import Foundation
import Security
import CryptoKit

// MARK: - Vendor-Keychain item identification

/// One Keychain generic-password entry, identified by service+account.
///
/// This is enough to round-trip an item: we read by (service, account),
/// write by (service, account) with a fresh `kSecValueData`.
public struct KeychainItemRef: Codable, Hashable, Sendable {
    public let service: String
    public let account: String

    public init(service: String, account: String) {
        self.service = service
        self.account = account
    }
}

/// Snapshot of one or more Keychain items, ready to be persisted on disk
/// (as encrypted blob) and restored later.
public struct KeychainSnapshot: Codable, Sendable {
    public struct Entry: Codable, Sendable {
        public let ref: KeychainItemRef
        /// Base64-encoded item data.
        public let valueBase64: String

        public init(ref: KeychainItemRef, valueBase64: String) {
            self.ref = ref
            self.valueBase64 = valueBase64
        }
    }

    public var entries: [Entry]

    public init(entries: [Entry] = []) {
        self.entries = entries
    }
}

// MARK: - Keychain I/O

public enum KeychainHelper {
    /// Read the data for a generic-password item. Returns nil if it doesn't
    /// exist. Throws on access errors *other than* not-found.
    public static func readItem(_ ref: KeychainItemRef) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: ref.service,
            kSecAttrAccount as String: ref.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw SwitcherError.keychainOperationFailed(operation: "read",
                                                        status: status)
        }
    }

    /// Insert or replace a generic-password item.
    public static func writeItem(_ ref: KeychainItemRef, data: Data) throws {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: ref.service,
            kSecAttrAccount as String: ref.account,
        ]
        let updateAttrs: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary,
                                         updateAttrs as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus != errSecItemNotFound {
            throw SwitcherError.keychainOperationFailed(operation: "update",
                                                        status: updateStatus)
        }

        // Item didn't exist — add it.
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        // kSecAttrAccessible default is whenUnlocked, which is what every
        // vendor app uses for its OAuth tokens.
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw SwitcherError.keychainOperationFailed(operation: "add",
                                                        status: addStatus)
        }
    }

    /// Delete a generic-password item if it exists. No-op when missing.
    public static func deleteItem(_ ref: KeychainItemRef) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: ref.service,
            kSecAttrAccount as String: ref.account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SwitcherError.keychainOperationFailed(operation: "delete",
                                                        status: status)
        }
    }

    /// Take a snapshot of the given items. Items that don't exist are skipped.
    public static func snapshot(_ refs: [KeychainItemRef]) throws -> KeychainSnapshot {
        var entries: [KeychainSnapshot.Entry] = []
        for ref in refs {
            guard let data = try readItem(ref) else { continue }
            entries.append(.init(ref: ref, valueBase64: data.base64EncodedString()))
        }
        return KeychainSnapshot(entries: entries)
    }

    /// Restore each entry in `snapshot` back into the Keychain. Items not
    /// represented in the snapshot are left alone — we never delete vendor
    /// items as a side effect of restore, because that would log the user
    /// out of every account they have for that surface.
    public static func restore(_ snapshot: KeychainSnapshot) throws {
        for entry in snapshot.entries {
            guard let data = Data(base64Encoded: entry.valueBase64) else {
                throw SwitcherError.decryptionFailed
            }
            try writeItem(entry.ref, data: data)
        }
    }
}

// MARK: - Encryption-at-rest key

/// AES-256-GCM key kept in our own Keychain entry. Encrypts the on-disk
/// snapshot blobs so that a stolen profile folder alone can't impersonate.
public enum SnapshotCrypto {
    /// Service/account pair for our app's encryption key.
    private static let keyRef = KeychainItemRef(
        service: AppConstants.Keychain.encryptionKeyService,
        account: AppConstants.Keychain.encryptionKeyAccount
    )

    /// Get the key, lazily creating it the first time.
    public static func getOrCreateKey() throws -> SymmetricKey {
        if let data = try KeychainHelper.readItem(keyRef) {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        try key.withUnsafeBytes { ptr in
            try KeychainHelper.writeItem(keyRef, data: Data(ptr))
        }
        return key
    }

    /// AES-256-GCM seal. Output is `nonce || ciphertext || tag` packed by
    /// `combined`.
    public static func seal(_ plaintext: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            throw SwitcherError.decryptionFailed
        }
        return combined
    }

    /// AES-256-GCM open. Expects the `combined` representation produced by
    /// `seal`.
    public static func open(_ ciphertext: Data) throws -> Data {
        let key = try getOrCreateKey()
        let box = try AES.GCM.SealedBox(combined: ciphertext)
        return try AES.GCM.open(box, using: key)
    }
}
