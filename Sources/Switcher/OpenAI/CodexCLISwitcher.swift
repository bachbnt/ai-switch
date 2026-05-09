//
//  CodexCLISwitcher.swift
//  AISwitch
//
//  Snapshots `~/.codex/` plus the Codex CLI's Keychain entries into a
//  profile folder, and restores them.
//
//  TODO(Phase0): The Keychain service/account names below MUST be verified
//  against a real Mac. Codex CLI is newer than Claude Code; both the file
//  layout under ~/.codex and the Keychain service strings may shift between
//  minor versions, so the switcher should tolerate missing files and surface
//  a clear error.
//

import Foundation

public struct CodexCLISwitcher: Switcher {
    public let surfaceId = AppConstants.SurfaceID.codexCLI

    private var liveDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(AppConstants.LivePath.codexCLI, isDirectory: true)
    }

    /// TODO(Phase0): Replace with values from `security dump-keychain`.
    private static let keychainItems: [KeychainItemRef] = [
        // KeychainItemRef(service: "Codex CLI", account: "<email>"),
    ]

    public init() {}

    public func snapshotOut(into profileDir: URL) async throws {
        let dirSnapshot = profileDir
            .appendingPathComponent(AppConstants.LivePath.dirSnapshotLive,
                                    isDirectory: true)
        if FileManager.default.fileExists(atPath: liveDirectory.path) {
            try FileSnapshot.copyDirectory(from: liveDirectory, to: dirSnapshot)
        } else {
            try FileSnapshot.ensureDirectory(dirSnapshot)
        }

        let snapshot = try KeychainHelper.snapshot(Self.keychainItems)
        try EncryptedSnapshotStore.writeKeychainSnapshot(snapshot,
                                                         toSurfaceDir: profileDir)
    }

    public func restoreIn(from profileDir: URL) async throws {
        let dirSnapshot = profileDir
            .appendingPathComponent(AppConstants.LivePath.dirSnapshotLive,
                                    isDirectory: true)
        guard FileManager.default.fileExists(atPath: dirSnapshot.path) else {
            throw SwitcherError.missingLivePath(dirSnapshot.path)
        }
        try FileSnapshot.copyDirectory(from: dirSnapshot, to: liveDirectory)
        if let snapshot = try EncryptedSnapshotStore
            .readKeychainSnapshot(fromSurfaceDir: profileDir) {
            try KeychainHelper.restore(snapshot)
        }
    }
}
