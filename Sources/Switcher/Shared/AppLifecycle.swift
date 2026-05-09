//
//  AppLifecycle.swift
//  AISwitch
//
//  Quit/relaunch helpers for desktop apps. Implemented via NSWorkspace +
//  Apple Events (osascript) so we don't need any private API.
//

import Foundation
import AppKit

public enum AppLifecycle {
    /// Quit a running app by bundle identifier. No-op if not running.
    /// Waits up to `timeout` seconds for the app to actually exit.
    public static func quit(bundleIdentifier: String,
                            timeout: TimeInterval = 5.0) async throws {
        let running = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
        guard !running.isEmpty else { return }

        // Polite quit via Apple Event. Apps respond to this much faster than
        // SIGTERM, and they get to flush their own state.
        for app in running {
            _ = app.terminate()
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let stillRunning = NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleIdentifier)
            if stillRunning.isEmpty { return }
            try? await Task.sleep(nanoseconds: 100_000_000) // 100 ms
        }

        // Last resort: force-terminate.
        for app in NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier) {
            _ = app.forceTerminate()
        }
    }

    /// Launch an app by bundle identifier. Returns once the app reports it
    /// has finished launching, or after `timeout`.
    public static func launch(bundleIdentifier: String,
                              timeout: TimeInterval = 10.0) async throws {
        guard let url = NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw SwitcherError.missingLivePath(bundleIdentifier)
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.addsToRecentItems = false

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
                if let error {
                    cont.resume(throwing: SwitcherError.underlying(error))
                } else {
                    cont.resume()
                }
            }
        }

        // Wait for the app to actually be running.
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let running = NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleIdentifier)
            if !running.isEmpty { return }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
}
