import SwiftData
import SwiftUI

/// Tab 3: the currency and the categories.
struct SettingsView: View {
    private enum EditorSheet: Identifiable {
        case new
        case edit(Category)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let category): category.id.uuidString
            }
        }
    }

    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Category.sortOrder), SortDescriptor(\Category.createdAt)])
    private var categories: [Category]

    @State private var editMode = EditMode.inactive
    @State private var editorSheet: EditorSheet?
    @State private var showCurrency = false

    private var isReordering: Bool { editMode.isEditing }

    var body: some View {
        List {
            Section {
                currencyRow
                    .cardListRow()
            } header: {
                VStack(alignment: .leading, spacing: 24) {
                    ScreenHeader(title: "Settings")
                        .accessibilityAddTraits(.isHeader)
                    SectionLabel("General")
                }
                .textCase(nil)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 8, trailing: 0))
            }

            Section {
                ForEach(categories) { category in
                    categoryRow(category)
                        .cardListRow()
                }
                .onMove { source, destination in
                    Category.move(categories, from: source, to: destination)
                    try? modelContext.save()
                }
                addCategoryRow
                    .cardListRow()
                    .moveDisabled(true)
            } header: {
                AdaptiveStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("CATEGORIES")
                        .font(.label)
                        .tracking(0.3)
                        .foregroundStyle(.textSecondary)
                    Spacer(minLength: 8)
                    Button(isReordering ? "Done" : "Reorder") {
                        withAnimation { editMode = isReordering ? .inactive : .active }
                    }
                    .font(.rowDetail)
                    .foregroundStyle(.dataBlue)
                    .frame(minHeight: 32)
                }
                .padding(.horizontal, 4)
                .textCase(nil)
                .listRowInsets(.init(top: 8, leading: 0, bottom: 8, trailing: 0))
            } footer: {
                Text(isReordering
                     ? "Drag to change the order used when adding a purchase."
                     : "Order here is the order in Add purchase. Deleting a category asks where its purchases should go.")
                    .font(.footnote)
                    .foregroundStyle(.textSecondary)
                    .textCase(nil)
                    .listRowInsets(.init(top: 8, leading: 4, bottom: 8, trailing: 4))
            }
        }
        .listScreen()
        .environment(\.editMode, $editMode)
        .sheet(item: $editorSheet) { sheet in
            switch sheet {
            case .new: CategoryEditorSheet(mode: .new)
            case .edit(let category): CategoryEditorSheet(mode: .edit(category))
            }
        }
        .navigationDestination(isPresented: $showCurrency) {
            CurrencyPickerView(selection: settings.currencyCode) { settings.currencyCode = $0 }
        }
        .onChange(of: showCurrency) {
            withAnimation { router.isCurrencyPickerOpen = showCurrency }
        }
        #if DEBUG
        // `-openCurrency YES`, `-openCategory Groceries`, `-openNewCategory YES`, for screenshots.
        .onAppear {
            if UserDefaults.standard.bool(forKey: "openCurrency") { showCurrency = true }
            if UserDefaults.standard.bool(forKey: "openNewCategory") { editorSheet = .new }
            if let name = UserDefaults.standard.string(forKey: "openCategory"),
               let category = categories.first(where: { $0.name == name }) {
                editorSheet = .edit(category)
            }
        }
        #endif
    }

    // MARK: Rows

    private var currencyRow: some View {
        Button { showCurrency = true } label: {
            HStack(spacing: 12) {
                Text(Money.symbol(settings.currencyCode))
                    .font(.system(size: 18, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(.surfaceRaised, in: .rect(cornerRadius: Radius.thumb))
                    .accessibilityHidden(true)
                AdaptiveStack(spacing: 2) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Currency")
                            .font(.body)
                            .foregroundStyle(.textPrimary)
                        if let currencySubline {
                            Text(currencySubline)
                                .font(.rowDetail)
                                .foregroundStyle(.textSecondary)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(Money.currencyName(settings.currencyCode))
                        .font(.body)
                        .foregroundStyle(.textSecondary)
                }
                chevron
            }
            .frame(minHeight: 48)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isReordering)
    }

    /// Only while the currency still matches the device's region.
    private var currencySubline: String? {
        guard settings.currencyCode == Money.regionCurrencyCode(), let region = Money.regionName() else { return nil }
        return "From your region: \(region)"
    }

    private func categoryRow(_ category: Category) -> some View {
        Button {
            editorSheet = .edit(category)
        } label: {
            HStack(spacing: 12) {
                CategoryTile(symbol: category.symbolName, color: category.info.color, size: 36, cornerRadius: Radius.thumb)
                AdaptiveStack(spacing: 2) {
                    Text(category.name)
                        .font(.body)
                        .foregroundStyle(.textPrimary)
                    Spacer(minLength: 8)
                    Text(category.purchaseCount.formatted())
                        .font(.rowDetail)
                        .foregroundStyle(.textSecondary)
                        .monospacedDigit()
                }
                if !isReordering { chevron }
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        // Not `.disabled`, which would dim the rows being dragged.
        .allowsHitTesting(!isReordering)
        .accessibilityLabel("\(category.name), \(category.purchaseCount) purchases")
        .accessibilityHint(isReordering ? "" : "Edits this category")
    }

    private var addCategoryRow: some View {
        Button {
            editorSheet = .new
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Color.dataBlue.opacity(0.16), in: .rect(cornerRadius: Radius.thumb))
                    .accessibilityHidden(true)
                Text("Add category")
                    .font(.body)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.dataBlue)
            .frame(minHeight: 40)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(isReordering)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.textTertiary)
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    NavigationStack { SettingsView() }
        .environment(AppSettings())
        .environment(AppRouter())
        .modelContainer(DemoData.previewContainer())
        .preferredColorScheme(.dark)
}
#endif
