//
//  ChatGPTDesktopSwitcher.swift
//  AISwitch
//
//  Snapshots `~/Library/Application Support/<chatgpt bundle>/` plus the
//  ChatGPT.app Keychain entries into a profile folder, and restores them.
//  Quits and relaunches ChatGPT.app on switch.
//
//  TODO(Phase0): Verify bundle identifier (likely "com.openai.chat") and
//  Keychain entries on a real Mac. ChatGPT desktop's auth has historically
//  been the most likely candidate for hardware-bound binding (Secure Enclave,
//  DPoP); if snapshot/restore fails on this surface, fall back to the
//  cloned-bundle approach noted in §12 of the plan.
//

import Foundation

public struct ChatGPTDesktopSwitcher: Switcher {
    public let surfaceId = AppConstants.SurfaceID.chatgptDesktop

    public static let bundleIdentifier = AppConstants.VendorBundleID.chatgptDesktop

    /// Live Application Support directory. The folder name uses the bundle ID
    /// in some installs and "ChatGPT" in others; we try both.
    private var candidateLiveDirectories: [URL] {
        let appSupport = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support",
                                    isDirectory: true)
        return [
            appSupport.appendingPathComponent(Self.bundleIdentifier, isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(AppConstants.LivePath.chatgptAppSupport,
                                        isDirectory: true),
        ]
    }

    private var resolvedLiveDirectory: URL {
        candidateLiveDirectories.first {
            FileManager.default.fileExists(atPath: $0.path)
        } ?? candidateLiveDirectories[0]
    }

    /// TODO(Phase0): Replace with values from `security dump-keychain`.
    private static let keychainItems: [KeychainItemRef] = [
        // KeychainItemRef(service: "ChatGPT", account: "<email>"),
    ]

    public init() {}

    public func snapshotOut(into profileDir: URL) async throws {
        let dirSnapshot = profileDir
            .appendingPathComponent(AppConstants.LivePath.dirSnapshotAppSupport,
                                    isDirectory: true)
        let live = resolvedLiveDirectory
        if FileManager.default.fileExists(atPath: live.path) {
            try FileSnapshot.copyDirectory(from: live, to: dirSnapshot)
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
        try FileSnapshot.copyDirectory(from: dirSnapshot, to: resolvedLiveDirectory)
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
