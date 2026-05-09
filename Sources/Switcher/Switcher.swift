//
//  Switcher.swift
//  AISwitch
//
//  The provider-agnostic surface-switching protocol from §3.
//
//  Per surface (Claude CLI, Claude Desktop, Codex CLI, ChatGPT Desktop), one
//  Switcher instance knows how to:
//    - snapshot the live state of that surface back into a profile folder
//      (this is what keeps each profile's stored OAuth refresh tokens fresh —
//       see the snapshot-out-on-switch rule in §5)
//    - restore a profile's saved state into the live paths
//    - quit and relaunch a desktop app, where applicable
//
//  Concrete implementations live in Switcher/Anthropic/ and Switcher/OpenAI/.
//

import Foundation

/// Errors raised by switchers. The UI surfaces `localizedDescription`.
public enum SwitcherError: LocalizedError {
    case missingLivePath(String)
    case keychainOperationFailed(operation: String, status: Int32)
    case shellCommandFailed(command: String, exitCode: Int32, stderr: String)
    case decryptionFailed
    case unknownSurface(String)
    case underlying(Error)

    public var errorDescription: String? {
        switch self {
        case .missingLivePath(let path):
            return "Live path not found: \(path)"
        case .keychainOperationFailed(let op, let status):
            return "Keychain \(op) failed (OSStatus \(status))."
        case .shellCommandFailed(let cmd, let code, let err):
            return "`\(cmd)` exited \(code): \(err)"
        case .decryptionFailed:
            return "Failed to decrypt profile snapshot. The profile folder may be corrupt."
        case .unknownSurface(let id):
            return "No switcher registered for surface \(id)."
        case .underlying(let err):
            return err.localizedDescription
        }
    }
}

/// One `Switcher` per surface (CLI binary or desktop app).
///
/// The four lifecycle methods are called in this order during a switch:
///
/// ```text
///     switching from A to B for some surface S:
///       1. S.snapshotOut(into: profileDir(A))   // freshen A's stored state
///       2. S.quitRunningInstance()              // desktop apps only
///       3. S.restoreIn(from: profileDir(B))     // copy B's snapshot into live paths
///       4. S.relaunch()                         // desktop apps only
/// ```
///
/// Implementations should be idempotent: calling `quitRunningInstance` when
/// the app isn't running, or `relaunch` when it's already running, must not
/// throw.
public protocol Switcher: Sendable {
    /// Stable identifier of the surface this switcher manages
    /// ("claude-cli", "claude-desktop", "codex-cli", "chatgpt-desktop").
    var surfaceId: String { get }

    /// Copy the live state of this surface into `profileDir`. This is what
    /// keeps each profile's stored OAuth refresh tokens fresh. Call on the
    /// **outgoing** profile every time we switch away.
    func snapshotOut(into profileDir: URL) async throws

    /// Restore a profile's saved state into the live paths used by this
    /// surface. Call on the **incoming** profile.
    func restoreIn(from profileDir: URL) async throws

    /// Quit the running instance (desktop apps only). No-op for CLI surfaces.
    func quitRunningInstance() async throws

    /// Relaunch the desktop app (desktop apps only). No-op for CLI surfaces.
    func relaunch() async throws
}

public extension Switcher {
    /// Default no-op for CLI surfaces.
    func quitRunningInstance() async throws {}
    /// Default no-op for CLI surfaces.
    func relaunch() async throws {}
}
