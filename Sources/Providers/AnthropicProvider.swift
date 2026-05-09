//
//  AnthropicProvider.swift
//  AISwitch
//
//  ProviderDescriptor for Anthropic. Owns two surfaces: the Claude Code CLI
//  and the Claude desktop app. Adding more Anthropic surfaces later (e.g.
//  the Workbench web app's local cache) would just be one more entry in
//  `surfaces` plus a new Switcher implementation.
//
//  Vendor product names ("Anthropic", "Claude Code", "Claude") are proper
//  nouns — they stay the same in every language, so they're not pulled
//  from the localization tables.
//

import Foundation

public enum AnthropicProvider {
    public static let descriptor = ProviderDescriptor(
        id: AppConstants.ProviderID.anthropic,
        displayName: "Anthropic",
        brandColorAssetName: AppConstants.Asset.anthropicBrandColor,
        iconSymbol: "sparkles",
        defaultProfileColors: [
            "#D47D4A", // warm orange (matches Anthropic brand family)
            "#2E7D32", // forest
            "#1565C0", // royal blue
            "#6A1B9A", // grape
            "#C62828", // crimson
            "#00838F", // teal
        ],
        surfaces: [
            SurfaceDescriptor(
                id: AppConstants.SurfaceID.claudeCLI,
                displayName: "Claude Code (CLI)",
                kind: .cli,
                switcherFactory: { ClaudeCLISwitcher() }
            ),
            SurfaceDescriptor(
                id: AppConstants.SurfaceID.claudeDesktop,
                displayName: "Claude (Desktop)",
                kind: .desktopApp,
                switcherFactory: { ClaudeDesktopSwitcher() }
            ),
        ]
    )
}
