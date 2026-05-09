//
//  ClaudeDesktopSwitcher.swift
//  AISwitch
//
//  Snapshots `~/Library/Application Support/Claude/` plus the Claude.app
//  Keychain entries into a profile folder, and restores them. Quits and
//  relaunches Claude.app on switch.
//
//  TODO(Phase0): Verify bundle identifier and Keychain entries on a real Mac.
//

import Foundation

public struct ClaudeDesktopSwitcher: Switcher {
    public let surfaceId = AppConstants.SurfaceID.claudeDesktop

    public static let bundleIdentifier = AppConstants.VendorBundleID.claudeDesktop

    /// Live Application Support directory.
    private var liveDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(AppConstants.LivePath.claudeAppSupport,
                                    isDirectory: true)
    }

    /// TODO(Phase0): Replace with values from `security dump-keychain`.
    private static let keychainItems: [KeychainItemRef] = [
        // KeychainItemRef(service: "Claude", account: "<email>"),
    ]

    public init() {}

    public func snapshotOut(into profileDir: URL) async throws {
        let dirSnapshot = profileDir
            .appendingPathComponent(AppConstants.LivePath.dirSnapshotAppSupport,
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
            .appendingPathComponent(AppConstants.LivePath.dirSnapshotAppSupport,
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

    public func quitRunningInstance() async throws {
        try await AppLifecycle.quit(bundleIdentifier: Self.bundleIdentifier)
    }

    public func relaunch() async throws {
        try await AppLifecycle.launch(bundleIdentifier: Self.bundleIdentifier)
    }
}
