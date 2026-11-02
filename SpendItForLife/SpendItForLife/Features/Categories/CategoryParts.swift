import SwiftUI

/// A rounded icon tile: the colour at 16% behind the symbol in the full colour.
struct CategoryTile: View {
    var symbol: String
    var color: Color
    var size: CGFloat = 40
    var cornerRadius: CGFloat = 12

    var body: some View {
        Image(systemName: CategoryIcon.symbol(for: symbol))
            .font(.system(size: size * 0.45, weight: .medium))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.16), in: .rect(cornerRadius: cornerRadius))
            .accessibilityHidden(true)
    }
}

/// A category as a capsule: round icon and name. Selectable in Add purchase,
/// static in onboarding.
struct CategoryChipLabel: View {
    var info: CategoryInfo
    var isOn = false

    var body: some View {
        HStack(spacing: 8) {
            CategoryTile(symbol: info.symbolName, color: info.color, size: 32, cornerRadius: 16)
            Text(info.name)
                .font(.rowDetail.weight(.semibold))
                .foregroundStyle(.textPrimary)
        }
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .frame(minHeight: 44)
        .background(isOn ? AnyShapeStyle(.fillSelected) : AnyShapeStyle(.surface), in: .capsule)
        .overlay { Capsule().strokeBorder(isOn ? AnyShapeStyle(info.color) : AnyShapeStyle(.stroke), lineWidth: 1) }
    }
}

/// The eight colour swatches, with a ring on the chosen one.
struct ColorSwatchRow: View {
    @Binding var selection: CategoryColor

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: CategoryColor.allCases.count)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(CategoryColor.allCases) { option in
                let isOn = option == selection
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selection = option }
                } label: {
                    Circle()
                        .fill(option.color)
                        .frame(width: 26, height: 26)
                        .frame(width: 40, height: 44)
                        .overlay {
                            Circle().strokeBorder(isOn ? AnyShapeStyle(.textPrimary) : AnyShapeStyle(.clear), lineWidth: 2)
                                .frame(width: 38, height: 38)
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.name)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Color")
    }
}

/// The icon grid, six across. The chosen one gets a tint and stroke.
struct IconGrid: View {
    var icons: [CategoryIcon]
    var color: Color
    @Binding var selection: CategoryIcon

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(icons) { icon in
                let isOn = icon == selection
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selection = icon }
                } label: {
                    Image(systemName: icon.symbolName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isOn ? color : .textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(isOn ? color.opacity(0.16) : .clear, in: .rect(cornerRadius: Radius.tile))
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.tile)
                                .strokeBorder(isOn ? color : .clear, lineWidth: 1)
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(icon.name)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Icon")
    }
}
