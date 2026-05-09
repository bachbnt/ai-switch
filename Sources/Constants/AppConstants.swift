//
//  AppConstants.swift
//  AISwitch
//
//  Centralized non-UI string constants. UI strings live in
//  Localization/LocalizationKey.swift + the .strings files.
//
//  Anything that's an *identifier* (provider ID, surface ID, bundle ID,
//  asset name, notification category) goes here. The goal is one place
//  to grep when a vendor renames something.
//

import Foundation

public enum AppConstants {
    // MARK: - App identity

    public enum App {
        public static let bundleIdentifier  = "com.bachbnt.AISwitch"
        public static let displayName       = "AISwitch"
        public static let appSupportFolder  = "AISwitch"
    }

    // MARK: - Provider IDs

    public enum ProviderID {
        public static let anthropic = "anthropic"
        public static let openai    = "openai"
    }

    // MARK: - Surface IDs

    public enum SurfaceID {
        public static let claudeCLI       = "claude-cli"
        public static let claudeDesktop   = "claude-desktop"
        public static let codexCLI        = "codex-cli"
        public static let chatgptDesktop  = "chatgpt-desktop"
    }

    // MARK: - Vendor app bundle IDs (verify in Phase 0)

    public enum VendorBundleID {
        /// TODO(Phase0): Verify in /Applications/Claude.app/Contents/Info.plist.
        public static let claudeDesktop  = "com.anthropic.claudefordesktop"
        /// TODO(Phase0): Verify in /Applications/ChatGPT.app/Contents/Info.plist.
        public static let chatgptDesktop = "com.openai.chat"
    }

    // MARK: - Asset names (in Resources/Assets.xcassets)

    public enum Asset {
        public static let anthropicBrandColor = "AnthropicBrand"
        public static let openaiBrandColor    = "OpenAIBrand"
        public static let menuBarIcon         = "MenuBarIcon"
    }

    // MARK: - Storage paths (rooted at App Support / AISwitch / …)

    public enum Storage {
        public static let providersFolder = "providers"
        public static let profilesFolder  = "profiles"
        public static let metaFile        = "meta.json"
        public static let activeFile      = "active.json"
        public static let configFile      = "config.json"
        public static let keychainBlob    = "keychain.bin"
    }

    // MARK: - Keychain

    public enum Keychain {
        /// Service/account for OUR app's AES-256-GCM master key.
        public static let encryptionKeyService = App.bundleIdentifier
        public static let encryptionKeyAccount = "encryption-key"
    }

    // MARK: - Notifications

    public enum Notifications {
        public static let categoryReminder = "\(App.bundleIdentifier).reminder"
        public static let actionOpenSwitcher = "OPEN_SWITCHER"
        public static let reminderRequestPrefix = "reminder."
    }

    // MARK: - Live config paths inside HOME

    public enum LivePath {
        public static let claudeCLI    = ".claude"
        public static let codexCLI     = ".codex"
        public static let claudeAppSupport  = "Library/Application Support/Claude"
        /// ChatGPT desktop varies by version; we probe both.
        public static let chatgptAppSupport  = "Library/Application Support/ChatGPT"
        /// Surface-folder names inside a profile.
        public static let dirSnapshotLive       = "live"
        public static let dirSnapshotAppSupport = "app-support"
    }
}
