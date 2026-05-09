//
//  ColorSwatchPicker.swift
//  AISwitch
//
//  Compact horizontal palette picker. Used by AddEditProfileSheet.
//

import SwiftUI

struct ColorSwatchPicker: View {
    let palette: [String]
    @Binding var selection: String
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        HStack(spacing: 6) {
            ForEach(palette, id: \.self) { hex in
                Button {
                    selection = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex) ?? .gray)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    selection.lowercased() == hex.lowercased()
                                        ? Color.primary
                                        : Color.primary.opacity(0.15),
                                    lineWidth: selection.lowercased() == hex.lowercased() ? 2 : 1
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(settings.t(.a11yColorFormat, hex))
            }
        }
    }
}
