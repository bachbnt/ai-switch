//
//  Profile.swift
//  AISwitch
//
//  Per-provider profile metadata. Mirrors the meta.json layout from §4 of the plan.
//

import Foundation
import SwiftUI

/// One authenticated session within a provider's namespace.
///
/// Profiles are uniquely identified by `id` (a UUID, also the on-disk folder
/// name). `alias` must be unique within a provider but may collide across
/// providers — Anthropic "Enterprise A" and OpenAI "Enterprise A" are distinct.
public struct Profile: Codable, Identifiable, Hashable, Sendable {
    /// Immutable UUID. Used as the folder name on disk and never changes after
    /// creation; renaming `alias` is a metadata edit.
    public let id: UUID

    /// Which provider this profile belongs to (e.g. "anthropic", "openai").
    public let providerId: String

    /// User-editable display name. Unique within the provider.
    public var alias: String

    /// Optional email shown in dimmed text under the alias.
    public var email: String?

    /// Hex color used for the row dot. Stored as `#RRGGBB`.
    public var colorHex: String

    /// SF Symbol name for the row icon, or nil to use the provider default.
    public var iconSymbol: String?

    /// Surface IDs this profile manages. Subset of the provider's surfaces.
    public var surfaces: [String]

    /// Sort order within the provider section. Lower values render first.
    public var order: Int

    public var createdAt: Date
    public var lastUsedAt: Date?

    public init(
        id: UUID = UUID(),
        providerId: String,
        alias: String,
        email: String? = nil,
        colorHex: String,
        iconSymbol: String? = nil,
        surfaces: [String],
        order: Int = 0,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.providerId = providerId
        self.alias = alias
        self.email = email
        self.colorHex = colorHex
        self.iconSymbol = iconSymbol
        self.surfaces = surfaces
        self.order = order
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}

extension Profile {
    /// SwiftUI Color decoded from `colorHex`. Falls back to gray if malformed.
    public var color: Color {
        Color(hex: colorHex) ?? .gray
    }
}

// MARK: - Color hex helpers

extension Color {
    /// Parses `#RRGGBB` or `#RRGGBBAA`. Returns nil for malformed strings.
    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8,
              let value = UInt64(s, radix: 16) else { return nil }

        let r, g, b, a: Double
        if s.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8)  & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
            a = 1.0
        } else {
            r = Double((value >> 24) & 0xFF) / 255.0
            g = Double((value >> 16) & 0xFF) / 255.0
            b = Double((value >> 8)  & 0xFF) / 255.0
            a = Double(value & 0xFF) / 255.0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
