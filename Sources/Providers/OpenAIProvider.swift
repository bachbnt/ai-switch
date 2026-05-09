//
//  OpenAIProvider.swift
//  AISwitch
//
//  ProviderDescriptor for OpenAI. Owns two surfaces: the Codex CLI and the
//  ChatGPT desktop app.
//

import Foundation

public enum OpenAIProvider {
    public static let descriptor = ProviderDescriptor(
        id: AppConstants.ProviderID.openai,
        displayName: "OpenAI",
        brandColorAssetName: AppConstants.Asset.openaiBrandColor,
        iconSymbol: "circle.hexagongrid.fill",
        defaultProfileColors: [
            "#10A88D", // OpenAI brand teal
            "#2962FF", // electric blue
            "#7B1FA2", // violet
            "#EF6C00", // amber
            "#455A64", // slate
            "#AD1457", // rose
        ],
        surfaces: [
            SurfaceDescriptor(
                id: AppConstants.SurfaceID.codexCLI,
                displayName: "Codex (CLI)",
                kind: .cli,
                switcherFactory: { CodexCLISwitcher() }
            ),
            SurfaceDescriptor(
                id: AppConstants.SurfaceID.chatgptDesktop,
                displayName: "ChatGPT (Desktop)",
                kind: .desktopApp,
                switcherFactory: { ChatGPTDesktopSwitcher() }
            ),
        ]
    )
}
