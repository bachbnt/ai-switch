//
//  ProfileRowView.swift
//  AISwitch
//
//  One row inside a provider section: color dot, alias, dimmed email,
//  active-checkmark on the right. Click to switch. Right-click for context
//  menu (Edit / Delete).
//

import SwiftUI

struct ProfileRowView: View {
    let profile: Profile
    let isActive: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject var settings: AppSettings
    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Circle()
                    .fill(profile.color)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 1) {
                    Text(profile.alias)
                        .font(.system(size: 13,
                                      weight: isActive ? .semibold : .regular))
                        .foregroundStyle(.primary)
                    if let email = profile.email, !email.isEmpty {
                        Text(email)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer(minLength: 4)

                if isActive {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(hovering ? Color.primary.opacity(0.06) : Color.clear)
                    .padding(.horizontal, 6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .contextMenu {
            Button(settings.t(.edit), action: onEdit)
            Divider()
            Button(settings.t(.delete), role: .destructive, action: onDelete)
        }
        .accessibilityLabel("\(profile.alias)\(isActive ? ", active" : "")")
    }
}
