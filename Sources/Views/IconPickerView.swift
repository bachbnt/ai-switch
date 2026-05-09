//
//  IconPickerView.swift
//  AISwitch
//
//  Tiny SF Symbol picker. We don't need every symbol — just a curated set
//  that maps well to "company / team / project" semantics for profile rows.
//

import SwiftUI

struct IconPickerView: View {
    @Binding var selection: String?
    @EnvironmentObject var settings: AppSettings

    private let symbols: [String] = [
        "building.2.fill", "briefcase.fill", "person.fill", "person.2.fill",
        "house.fill", "graduationcap.fill", "globe", "circle.grid.2x2.fill",
        "star.fill", "bolt.fill", "leaf.fill", "flame.fill",
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 6),
                                  count: 6), spacing: 6) {
            // Default-icon (provider's chosen symbol).
            Button {
                selection = nil
            } label: {
                Image(systemName: "questionmark")
                    .frame(width: 26, height: 26)
                    .background(swatchBackground(isSelected: selection == nil))
            }
            .buttonStyle(.plain)
            .help(settings.t(.iconUseProviderDefault))

            ForEach(symbols, id: \.self) { symbol in
                Button {
                    selection = symbol
                } label: {
                    Image(systemName: symbol)
                        .frame(width: 26, height: 26)
                        .background(swatchBackground(isSelected: selection == symbol))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func swatchBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isSelected ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isSelected ? Color.accentColor
                                              : Color.primary.opacity(0.1),
                                  lineWidth: isSelected ? 1.5 : 1)
            )
    }
}
