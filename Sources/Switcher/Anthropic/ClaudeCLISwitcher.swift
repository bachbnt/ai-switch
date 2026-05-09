//
//  ClaudeCLISwitcher.swift
//  AISwitch
//
//  Snapshots `~/.claude/` plus the Claude Code CLI's Keychain entries into
//  a profile folder, and restores them.
//
//  TODO(Phase0): The Keychain service/account names below MUST be verified
//  against a real Mac. Run `bash scripts/phase0_discovery.sh` and update
//  `keychainItems` to match. The placeholder strings here will *not* match
//  any real entry until you do.
//

import Foundation

public struct ClaudeCLISwitcher: Switcher {
    public let surfaceId = AppConstants.SurfaceID.claudeCLI

    /// Live config directory — `~/.claude/` per the plan.
    private var liveDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(AppConstants.LivePath.claudeCLI, isDirectory: true)
    }

    /// TODO(Phase0): Replace with values from `security dump-keychain`.
    /// On most installs Claude Code stores its OAuth tokens under a service
    /// like "Claude Code-credentials" with the user's email as the account.
    /// Discover the exact strings on your Mac before relying on this.
    private static let keychainItems: [KeychainItemRef] = [
        // KeychainItemRef(service: "Claude Code-credentials", account: "<email>"),
    ]

    public init() {}

    public func snapshotOut(into profileDir: URL) async throws {
        let dirSnapshot = profileDir
            .appendingPathComponent(AppConstants.LivePath.dirSnapshotLive,
                                    isDirectory: true)

        // 1. Copy ~/.claude into the profile.
        if FileManager.default.fileExists(atPath: liveDirectory.path) {
            try FileSnapshot.copyDirectory(from: liveDirectory, to: dirSnapshot)
        } else {
            // First-run before the user has logged in to Claude Code at all.
            // We still create an empty marker directory so restoreIn has
            // something to work with.
            try FileSnapshot.ensureDirectory(dirSnapshot)
        }

        // 2. Snapshot Keychain entries (if any are configured).
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

        // 1. Restore ~/.claude.
        try FileSnapshot.copyDirectory(from: dirSnapshot, to: liveDirectory)

        // 2. Restore Keychain entries.
        if let snapshot = try EncryptedSnapshotStore
            .readKeychainSnapshot(fromSurfaceDir: profileDir) {
            try KeychainHelper.restore(snapshot)
        }
    }
}
