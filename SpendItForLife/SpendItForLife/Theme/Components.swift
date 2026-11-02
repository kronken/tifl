import SwiftUI

/// Room under a tab's scrolling content, so its end clears the floating tab bar.
let tabBarClearance: CGFloat = 88

/// Corner radii from the design system.
enum Radius {
    /// Cards and grouped lists.
    static let card: CGFloat = 26
    /// Nested elements.
    static let tile: CGFloat = 16
    /// Fields and small icon tiles.
    static let thumb: CGFloat = 10
}

// MARK: - Card

private struct CardModifier: ViewModifier {
    var padding: CGFloat?

    func body(content: Content) -> some View {
        content
            .padding(padding ?? 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.surface, in: .rect(cornerRadius: Radius.card))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card).strokeBorder(.stroke, lineWidth: 1)
            }
            .clipShape(.rect(cornerRadius: Radius.card))
            .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
    }
}

extension View {
    /// The design's card: dark surface, hairline border, 26pt corners.
    /// Pass `padding: nil` for lists whose rows bring their own padding.
    func card(padding: CGFloat? = 16) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

// MARK: - Section label

/// Uppercase label above a card, e.g. "TODAY" with the day's total on the right.
struct SectionLabel: View {
    var title: String
    var trailing: String?

    init(_ title: String, trailing: String? = nil) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased()).tracking(0.3)
            Spacer()
            if let trailing {
                Text(trailing.uppercased())
            }
        }
        .font(.label)
        .foregroundStyle(.textSecondary)
        .padding(.horizontal, 4)
    }
}

// MARK: - Screen header

/// Top-of-screen header: a small line above a large title, with optional
/// buttons aligned to the title's bottom edge.
struct ScreenHeader<Trailing: View>: View {
    var subtitle: String?
    var title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let subtitle {
                    Text(subtitle)
                        .font(.rowDetail)
                        .foregroundStyle(.textSecondary)
                }
                Text(title)
                    .font(.screenTitle)
                    .foregroundStyle(.textPrimary)
            }
            Spacer(minLength: 0)
            trailing
        }
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(subtitle: String? = nil, title: String) {
        self.init(subtitle: subtitle, title: title) { EmptyView() }
    }
}

// MARK: - Buttons

/// Full-width gold capsule, 56pt tall. The main action on a screen.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rowTitle)
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(isEnabled ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.textTertiary))
            .background(isEnabled ? AnyShapeStyle(.accentGold) : AnyShapeStyle(.surfaceRaised), in: .capsule)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Full-width dark capsule with a hairline border, e.g. "Show all".
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rowTitle)
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(.textPrimary)
            .background(.surfaceRaised, in: .capsule)
            .overlay { Capsule().strokeBorder(.stroke, lineWidth: 1) }
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// Round 44pt Liquid Glass button for a header icon.
struct GlassIconButton: View {
    var systemImage: String
    var accessibilityLabel: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.textPrimary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Screen scaffold

/// A tab's root screen: dark background, scrolling content with the design's
/// 16pt side margins and 16pt spacing between blocks.
struct TabScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .contentMargins(.bottom, tabBarClearance, for: .scrollContent)
        .scrollIndicators(.hidden)
        .background(.appBackground)
        .toolbarVisibility(.hidden, for: .navigationBar)
        // The bar is hidden, but in large-title mode iOS still reserves room
        // for a large title when you pull past the top, leaving a gap that
        // only snaps back after a moment. Inline mode reserves nothing.
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Glass

private struct PatinaGlassModifier<S: InsettableShape>: ViewModifier {
    var shape: S
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(.surface, in: shape)
                .overlay { shape.strokeBorder(.stroke, lineWidth: 1) }
        } else {
            content.glassEffect(.regular.interactive(), in: shape)
        }
    }
}

extension View {
    /// Liquid Glass, or a solid surface with a hairline when Reduce
    /// Transparency is on.
    func patinaGlass<S: InsettableShape>(in shape: S) -> some View {
        modifier(PatinaGlassModifier(shape: shape))
    }
}

// MARK: - Hero figure

/// 48/52 bold rounded, in ink. Scales with Dynamic Type and shrinks to fit.
struct HeroFigure: View {
    var text: String
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 48

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .contentTransition(.numericText())
    }
}

// MARK: - List styling

extension View {
    /// A list screen on the app background, with the bar hidden like `TabScreen`.
    func listScreen() -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .listSectionSpacing(16)
            .contentMargins(.bottom, tabBarClearance, for: .scrollContent)
            .background(.appBackground)
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
    }

    /// A row that sits directly on the background, e.g. a header or a card.
    func plainListRow() -> some View {
        self
            .listRowInsets(.init())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    /// A row inside a grouped card.
    func cardListRow() -> some View {
        self
            .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color(hex: 0x141417))
            .listRowSeparatorTint(.stroke)
    }
}
