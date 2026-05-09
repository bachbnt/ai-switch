//
//  EncryptedSnapshotStore.swift
//  AISwitch
//
//  Helper used by every concrete Switcher: serialize a `KeychainSnapshot`,
//  encrypt with `SnapshotCrypto`, write to `<profileDir>/keychain.bin`.
//

import Foundation

public enum EncryptedSnapshotStore {
    public static func writeKeychainSnapshot(_ snapshot: KeychainSnapshot,
                                             toSurfaceDir dir: URL) throws {
        let json = try JSONEncoder().encode(snapshot)
        let cipher = try SnapshotCrypto.seal(json)
        try FileSnapshot.ensureDirectory(dir)
        let url = dir.appendingPathComponent(AppConstants.Storage.keychainBlob)
        try cipher.write(to: url, options: [.atomic])
    }

    public static func readKeychainSnapshot(fromSurfaceDir dir: URL) throws -> KeychainSnapshot? {
        let url = dir.appendingPathComponent(AppConstants.Storage.keychainBlob)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let cipher = try Data(contentsOf: url)
        let plaintext = try SnapshotCrypto.open(cipher)
        return try JSONDecoder().decode(KeychainSnapshot.self, from: plaintext)
    }
}
