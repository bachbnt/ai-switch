//
//  FileSnapshot.swift
//  AISwitch
//
//  Atomic directory copy with a backup-on-failure pattern, used by every
//  switcher that snapshots a live config directory (~/.claude, ~/.codex,
//  Application Support/<vendor>) into a profile folder and back.
//
//  The "atomic" guarantee here is best-effort at the directory level: if
//  the copy fails partway, we restore the destination from a sibling
//  backup so the user never ends up with a half-written live state.
//

import Foundation

public enum FileSnapshot {
    /// Recursively copy `source` to `destination`, replacing whatever was
    /// there. If the copy fails, the prior contents of `destination` are
    /// restored from a sibling backup directory before throwing.
    ///
    /// `source` must exist; `destination` may or may not exist.
    public static func copyDirectory(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: source.path) else {
            throw SwitcherError.missingLivePath(source.path)
        }

        // 1. Ensure parent of destination exists.
        let parent = destination.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)

        // 2. If destination exists, move it aside as a backup.
        let backup = destination.appendingPathExtension("backup-\(UUID().uuidString)")
        let hadDestination = fm.fileExists(atPath: destination.path)
        if hadDestination {
            try fm.moveItem(at: destination, to: backup)
        }

        // 3. Copy. On failure, restore the backup and rethrow.
        do {
            try fm.copyItem(at: source, to: destination)
        } catch {
            if hadDestination {
                _ = try? fm.removeItem(at: destination)
                _ = try? fm.moveItem(at: backup, to: destination)
            }
            throw SwitcherError.underlying(error)
        }

        // 4. Success — delete the backup.
        if hadDestination {
            _ = try? fm.removeItem(at: backup)
        }
    }

    /// Remove a directory if it exists. No-op when missing.
    public static func removeDirectoryIfExists(at url: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        try fm.removeItem(at: url)
    }

    /// Make sure a directory exists. Returns its URL.
    @discardableResult
    public static func ensureDirectory(_ url: URL) throws -> URL {
        try FileManager.default.createDirectory(at: url,
                                                withIntermediateDirectories: true)
        return url
    }
}
