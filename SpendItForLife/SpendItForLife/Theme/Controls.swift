import SwiftUI

// MARK: - Chip

/// A capsule toggle, e.g. a category filter or a weather condition.
struct Chip: View {
    var title: String
    var isOn: Bool
    /// The Wardrobe filter row uses 36pt chips, the forms 40pt.
    var height: CGFloat = 40
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.rowDetail.weight(.medium))
                .foregroundStyle(isOn ? .textPrimary : .textSecondary)
                .padding(.horizontal, 14)
                .frame(minHeight: height)
                .background(isOn ? AnyShapeStyle(.fillSelected) : AnyShapeStyle(.clear), in: .capsule)
                .overlay { Capsule().strokeBorder(.stroke, lineWidth: 1) }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Segmented control

/// The design's two- or three-way switch: a dark track with a lighter
/// selected segment.
struct SegmentedControl<Value: Hashable>: View {
    var options: [(value: Value, title: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let isOn = option.value == selection
                Button {
                    withAnimation(.snappy(duration: 0.2)) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(.rowDetail.weight(.semibold))
                        .foregroundStyle(isOn ? .textPrimary : .textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(isOn ? AnyShapeStyle(.fillSelected) : AnyShapeStyle(.clear), in: .capsule)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(2)
        .background(.surfaceRaised, in: .capsule)
    }
}

// MARK: - Search field

struct SearchField: View {
    var prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.textSecondary)
            TextField(prompt, text: $text, prompt: Text(prompt).foregroundStyle(.textSecondary))
                .foregroundStyle(.textPrimary)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(.surfaceRaised, in: .capsule)
    }
}

// MARK: - Adaptive stack

/// Side by side, or stacked at accessibility text sizes where a row won't fit.
struct AdaptiveStack<Content: View>: View {
    var alignment: VerticalAlignment = .center
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: alignment, spacing: spacing))
        layout { content }
    }
}

// MARK: - Flow layout

/// Lays out children left to right, wrapping onto new lines. Used for chip
/// groups.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews: subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let proposal = fitting(bounds.width)
                let size = subviews[index].sizeThatFits(proposal)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: proposal)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    /// Children keep their ideal width, up to the full line.
    private func fitting(_ width: CGFloat) -> ProposedViewSize {
        ProposedViewSize(width: width.isFinite ? width : nil, height: nil)
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(fitting(width))
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - Form rows

/// A row inside a form card: label on the left, control on the right, 52pt tall.
struct FormRow<Control: View>: View {
    var label: String
    var detail: String?
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body)
                    .foregroundStyle(.textPrimary)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.textSecondary)
                }
            }
            .frame(minWidth: 96, alignment: .leading)
            Spacer(minLength: 0)
            control
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 52)
    }
}

/// A hairline between rows in a card.
struct RowDivider: View {
    var body: some View {
        Rectangle().fill(.stroke).frame(height: 1)
    }
}

// MARK: - Sheets

/// Cancel / title / Save sheet scaffold.
struct EditSheet<Content: View>: View {
    var title: String
    var canSave: Bool
    var onSave: () -> Void
    @ViewBuilder var content: Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) { content }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.appBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!canSave)
                }
            }
        }
        .presentationBackground(.appBackground)
    }
}
