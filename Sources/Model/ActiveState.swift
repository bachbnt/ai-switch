//
//  ActiveState.swift
//  AISwitch
//
//  Per-provider active.json. Each provider has its own — switching Anthropic
//  does not touch OpenAI and vice versa. See §4 of the plan.
//

import Foundation

/// Snapshot of which profile is currently "live" for a single provider.
public struct ActiveState: Codable, Equatable, Sendable {
    public var activeProfileId: UUID?
    public var lastSwitchedAt: Date?

    public init(activeProfileId: UUID? = nil, lastSwitchedAt: Date? = nil) {
        self.activeProfileId = activeProfileId
        self.lastSwitchedAt = lastSwitchedAt
    }

    public static let empty = ActiveState()
}
