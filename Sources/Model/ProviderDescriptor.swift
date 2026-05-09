//
//  ProviderDescriptor.swift
//  AISwitch
//
//  Static metadata that defines a provider (Anthropic, OpenAI, …) and the
//  surfaces it manages. Keeping this declarative makes "add a third provider"
//  a two-file change. See §3 of the plan.
//

import Foundation
import SwiftUI

/// Surface kind. Affects UI hints (e.g. "restart any open `claude` shells").
public enum SurfaceKind: String, Codable, Sendable {
    case cli
    case desktopApp
}

/// One vendor surface (a single CLI binary or a single desktop app).
public struct SurfaceDescriptor: Identifiable, Sendable {
    public let id: String                 // "claude-cli", "chatgpt-desktop", …
    /// Brand display name, NOT localized — vendor product names are proper
    /// nouns ("Claude Code", "ChatGPT") and stay the same across languages.
    public let displayName: String
    public let kind: SurfaceKind
    /// Per-instance switcher factory. Each call returns a fresh instance.
    public let switcherFactory: @Sendable () -> Switcher

    public init(
        id: String,
        displayName: String,
        kind: SurfaceKind,
        switcherFactory: @escaping @Sendable () -> Switcher
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.switcherFactory = switcherFactory
    }
}

/// One vendor (Anthropic, OpenAI, …) with its surfaces.
public struct ProviderDescriptor: Identifiable, Sendable {
    public let id: String                 // "anthropic", "openai"
    public let displayName: String
    public let brandColorAssetName: String // looked up via Color(brandColorAssetName, …)
    public let iconSymbol: String          // SF Symbol
    public let defaultProfileColors: [String] // hex strings for new-profile palette
    public let surfaces: [SurfaceDescriptor]

    public init(
        id: String,
        displayName: String,
        brandColorAssetName: String,
        iconSymbol: String,
        defaultProfileColors: [String],
        surfaces: [SurfaceDescriptor]
    ) {
        self.id = id
        self.displayName = displayName
        self.brandColorAssetName = brandColorAssetName
        self.iconSymbol = iconSymbol
        self.defaultProfileColors = defaultProfileColors
        self.surfaces = surfaces
    }

    /// Find a surface descriptor by ID. Returns nil if the surface ID is not
    /// owned by this provider.
    public func surface(withId surfaceId: String) -> SurfaceDescriptor? {
        surfaces.first { $0.id == surfaceId }
    }
}

/// In-memory registry of all providers known at app launch.
///
/// The list is fixed at startup and never mutated, so this is a plain
/// `Sendable` singleton — no `ObservableObject` needed. Views read it via
/// `ProviderRegistry.shared` directly. Adding a third vendor: append to the
/// list in `init`.
public final class ProviderRegistry: Sendable {
    public static let shared = ProviderRegistry()

    public let providers: [ProviderDescriptor]

    private init() {
        self.providers = [
            AnthropicProvider.descriptor,
            OpenAIProvider.descriptor,
        ]
    }

    public func provider(withId id: String) -> ProviderDescriptor? {
        providers.first { $0.id == id }
    }
}
