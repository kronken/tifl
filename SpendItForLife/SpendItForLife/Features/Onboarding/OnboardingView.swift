import SwiftData
import SwiftUI

/// First-launch flow: what the app does, the currency, and the first
/// categories. Nothing is saved until it finishes, so leaving halfway leaves
/// nothing behind and any category that turns up meanwhile came from iCloud.
struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome, currency, categories
    }

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [Category]

    @State private var step: Step = .welcome
    @State private var currency = ""
    @State private var drafts: [CategoryDraft] = []

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome {
                HStack {
                    GlassIconButton(systemImage: "chevron.left", accessibilityLabel: "Back") {
                        go(to: Step(rawValue: step.rawValue - 1) ?? .welcome)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            Group {
                switch step {
                case .welcome:
                    WelcomeStep(dots: dots) { go(to: .currency) }
                case .currency:
                    CurrencyStep(code: $currency, dots: dots) {
                        settings.currencyCode = currency
                        go(to: .categories)
                    }
                case .categories:
                    CategoriesStep(drafts: $drafts, dots: dots, onFinish: finish)
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
        }
        .background(.appBackground)
        .onAppear {
            currency = settings.currencyCode
            #if DEBUG
            // `-onboardingStep 0…2` with `-demoNew YES`, for screenshots.
            if let raw = UserDefaults.standard.string(forKey: "onboardingStep"),
               let index = Int(raw), let debugStep = Step(rawValue: index) {
                step = debugStep
            }
            #endif
        }
        .onChange(of: categories.count) {
            // iCloud delivered categories: keep what was added here and move on.
            if !categories.isEmpty { finish() }
        }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.self) { dot in
                Capsule()
                    .fill(dot == step ? AnyShapeStyle(.textPrimary) : AnyShapeStyle(.textTertiary))
                    .frame(width: dot == step ? 18 : 6, height: 6)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
    }

    private func go(to next: Step) {
        withAnimation(.snappy) { step = next }
    }

    private func finish() {
        let existing = categories.map(\.name)
        for draft in drafts where !CategoryRules.isTaken(draft.name, among: existing) {
            Category.create(name: draft.name, color: draft.color, icon: draft.icon, in: modelContext)
        }
        drafts = []
        try? modelContext.save()
        settings.hasCompletedOnboarding = true
    }
}

/// A category that's been added but not saved yet.
struct CategoryDraft: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var color: CategoryColor
    var icon: CategoryIcon

    var info: CategoryInfo {
        CategoryInfo(id: id, name: name, colorKey: color.rawValue, symbolName: icon.symbolName, sortOrder: 0)
    }
}

// MARK: - Welcome

private struct WelcomeStep<Dots: View>: View {
    var dots: Dots
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    VStack(alignment: .leading, spacing: 16) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 32, weight: .regular))
                            .foregroundStyle(.accentGold)
                            .frame(width: 72, height: 72)
                            .background(.surface, in: .rect(cornerRadius: 20))
                            .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.stroke, lineWidth: 1) }
                            .accessibilityHidden(true)
                        Text("Spend It For Life")
                            .font(.screenTitle)
                            .foregroundStyle(.textPrimary)
                        Text("Know where your money goes, one purchase at a time.")
                            .font(.cardTitle)
                            .foregroundStyle(.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 20) {
                        point("timer", "Log in seconds", "Amount, category, done. Today is the default date.")
                        point("square.grid.2x2", "Your categories", "No presets. Name them, color them, pick an icon.")
                        point("chart.bar", "See the pattern", "Per month, per year, per category.")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 64)
            }
            .scrollIndicators(.hidden)
            dots
            Button("Get started", action: onNext)
                .buttonStyle(.primary)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
    }

    private func point(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.textPrimary)
                .frame(width: 40, height: 40)
                .background(.surfaceRaised, in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.rowTitle)
                    .foregroundStyle(.textPrimary)
                Text(detail)
                    .font(.rowDetail)
                    .foregroundStyle(.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Currency

private struct CurrencyStep<Dots: View>: View {
    @Binding var code: String
    var dots: Dots
    var onNext: () -> Void

    @State private var showAll = false

    static var commonCodes: [String] { ["EUR", "USD", "GBP", "SEK", "NOK", "CHF"] }

    /// A code picked from the full list gets a chip too, so it shows as chosen.
    private var chips: [String] {
        Self.commonCodes.contains(code) || code.isEmpty ? Self.commonCodes : Self.commonCodes + [code]
    }

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your currency")
                            .font(.screenTitle)
                            .foregroundStyle(.textPrimary)
                        Text("Picked from your iPhone’s region. Change it any time in Settings.")
                            .font(.body)
                            .foregroundStyle(.textSecondary)
                    }
                    .padding(.horizontal, 8)

                    VStack(spacing: 6) {
                        if let region = Money.regionName() {
                            Text("REGION · \(region.uppercased())")
                                .font(.label)
                                .tracking(0.3)
                                .foregroundStyle(.textSecondary)
                        }
                        HeroFigure(MoneyFormat(code: code).format(123_450))
                        Text(Money.currencyName(code))
                            .font(.rowTitle)
                            .foregroundStyle(.textPrimary)
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .card()
                    .accessibilityElement(children: .combine)

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("Or pick another")
                        FlowLayout {
                            ForEach(chips, id: \.self) { option in
                                Chip(title: option, isOn: option == code, height: 44) {
                                    withAnimation(.snappy(duration: 0.2)) { code = option }
                                }
                                .accessibilityLabel(Money.currencyName(option))
                            }
                            Button("All currencies") { showAll = true }
                                .font(.rowDetail)
                                .foregroundStyle(.dataBlue)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            dots
            Button("Use \(code)", action: onNext)
                .buttonStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .sheet(isPresented: $showAll) {
            NavigationStack {
                CurrencyPickerView(selection: code) { picked in
                    code = picked
                    showAll = false
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAll = false }
                            .tint(.textPrimary)
                    }
                }
            }
            .presentationBackground(.appBackground)
        }
    }
}

// MARK: - Categories

private struct CategoriesStep<Dots: View>: View {
    @Binding var drafts: [CategoryDraft]
    var dots: Dots
    var onFinish: () -> Void

    @State private var name = ""
    @State private var color = CategoryColor.moss
    @State private var icon = CategoryIcon.cart

    private struct Idea {
        var name: String
        var color: CategoryColor
        var icon: CategoryIcon
    }

    private static var allIdeas: [Idea] {
        [
            Idea(name: "Groceries", color: .moss, icon: .cart),
            Idea(name: "Eating out", color: .clay, icon: .forkKnife),
            Idea(name: "Transport", color: .denim, icon: .tram),
            Idea(name: "Home", color: .teal, icon: .house),
            Idea(name: "Bills", color: .steel, icon: .bolt),
            Idea(name: "Clothing", color: .violet, icon: .tshirt)
        ]
    }

    private var ideas: [Idea] {
        Self.allIdeas.filter { !CategoryRules.isTaken($0.name, among: drafts.map(\.name)) }
    }

    private var nameIsTaken: Bool {
        CategoryRules.isTaken(name, among: drafts.map(\.name))
    }

    private var canAdd: Bool {
        CategoryRules.isValid(name) && !nameIsTaken
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your categories")
                            .font(.screenTitle)
                            .foregroundStyle(.textPrimary)
                        Text("Add at least one to start. More can come later in Settings.")
                            .font(.body)
                            .foregroundStyle(.textSecondary)
                    }
                    .padding(.horizontal, 8)

                    if !drafts.isEmpty {
                        FlowLayout {
                            ForEach(drafts) { draft in
                                CategoryChipLabel(info: draft.info)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Added: \(drafts.map(\.name).formatted(.list(type: .and)))")
                    }

                    creator

                    if !ideas.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel("Ideas · tap to fill in")
                            FlowLayout {
                                ForEach(ideas, id: \.name) { idea in
                                    ideaChip(idea)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            dots
            VStack(spacing: 8) {
                Button("Start tracking", action: onFinish)
                    .buttonStyle(.primary)
                    .disabled(drafts.isEmpty)
                if drafts.isEmpty {
                    Text("Add one category to continue")
                        .font(.footnote)
                        .foregroundStyle(.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var creator: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                CategoryTile(symbol: icon.symbolName, color: color.color, size: 44)
                TextField("Category name", text: $name,
                          prompt: Text("Name, e.g. Groceries").foregroundStyle(.textTertiary))
                    .foregroundStyle(.textPrimary)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
            }
            .padding(.leading, 6)
            .padding(.trailing, 8)
            .frame(minHeight: 52)
            .background(.surfaceRaised, in: .rect(cornerRadius: Radius.tile))

            if nameIsTaken {
                Text("You already added this one.")
                    .font(.footnote)
                    .foregroundStyle(.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ColorSwatchRow(selection: $color)
            IconGrid(icons: CategoryIcon.onboarding, color: color.color, selection: $icon)

            Button(action: add) {
                Text(canAdd ? "Add “\(trimmedName)”" : "Add category")
                    .font(.rowTitle)
                    .foregroundStyle(canAdd ? .textPrimary : .textTertiary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(canAdd ? AnyShapeStyle(.fillSelected) : AnyShapeStyle(.clear), in: .capsule)
                    .overlay { Capsule().strokeBorder(.stroke, lineWidth: 1) }
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .disabled(!canAdd)
        }
        .card(padding: 12)
    }

    private func ideaChip(_ idea: Idea) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                name = idea.name
                color = idea.color
                icon = idea.icon
            }
        } label: {
            Text(idea.name)
                .font(.rowDetail)
                .foregroundStyle(.textSecondary)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .overlay {
                    Capsule().strokeBorder(.white.opacity(0.24), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Fills in the form")
    }

    private func add() {
        guard canAdd else { return }
        withAnimation(.snappy) {
            drafts.append(CategoryDraft(name: trimmedName, color: color, icon: icon))
            name = ""
            color = color.next
            icon = .cart
        }
    }
}

#if DEBUG
#Preview {
    OnboardingView()
        .environment(AppSettings())
        .modelContainer(DemoData.inMemoryContainer())
        .preferredColorScheme(.dark)
}
#endif
