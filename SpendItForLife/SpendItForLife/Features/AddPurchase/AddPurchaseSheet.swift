import SwiftData
import SwiftUI

/// New purchase / Edit purchase.
struct AddPurchaseSheet: View {
    enum Mode {
        case new
        case edit(Purchase)
    }

    /// New purchases start on the most recently used category.
    static let preselectsLastCategory = true

    let mode: Mode

    private enum DateChoice: Hashable {
        case today, yesterday, picked
    }

    private enum Field: Hashable {
        case amount, title
    }

    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Category.sortOrder), SortDescriptor(\Category.createdAt)])
    private var categories: [Category]

    @State private var amountText = ""
    @State private var selectedCategoryID: UUID?
    @State private var title = ""
    @State private var dateChoice = DateChoice.today
    @State private var pickedDate = Date.now
    @State private var showDatePicker = false
    @State private var showCategoryEditor = false
    @FocusState private var focus: Field?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var editing: Purchase? {
        if case .edit(let purchase) = mode { purchase } else { nil }
    }

    private var fractionDigits: Int { Money.maximumFractionDigits(settings.currencyCode) }

    private var selectedCategory: Category? {
        categories.first { $0.id == selectedCategoryID }
    }

    private var draft: PurchaseDraft {
        PurchaseDraft(amountText: amountText, hasCategory: selectedCategory != nil, fractionDigits: fractionDigits)
    }

    private var chosenDate: Date {
        let calendar = Calendar.current
        switch dateChoice {
        case .today: return calendar.startOfDay(for: .now)
        case .yesterday: return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now)) ?? .now
        case .picked: return calendar.startOfDay(for: pickedDate)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    amountField
                    categorySection
                    detailsCard
                    if editing != nil {
                        Button("Delete purchase", role: .destructive, action: deletePurchase)
                            .buttonStyle(DeleteButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.appBackground)
            .navigationTitle(editing == nil ? "New purchase" : "Edit purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(.textPrimary)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { saveBar }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.appBackground)
        .sheet(isPresented: $showDatePicker) { datePickerSheet }
        .sheet(isPresented: $showCategoryEditor) {
            CategoryEditorSheet(mode: .new) { created in
                selectedCategoryID = created.id
            }
        }
        .onAppear(perform: load)
        .onChange(of: draft.hint) {
            if let hint = draft.hint {
                AccessibilityNotification.Announcement(hint).post()
            }
        }
    }

    // MARK: Parts

    private var amountField: some View {
        VStack(spacing: 4) {
            Text("AMOUNT")
                .font(.label)
                .tracking(0.3)
                .foregroundStyle(.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Money.symbol(settings.currencyCode))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(draft.cents == nil ? .textTertiary : .textPrimary)
                    .accessibilityHidden(true)
                TextField("Amount", text: amountBinding,
                          prompt: Text(amountPlaceholder).foregroundStyle(.textTertiary))
                    .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.textPrimary)
                    .keyboardType(.decimalPad)
                    .focused($focus, equals: .amount)
                    .fixedSize()
                    .minimumScaleFactor(0.5)
                    .accessibilityLabel("Amount in \(Money.currencyName(settings.currencyCode))")
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .contentShape(.rect)
            .onTapGesture { focus = .amount }
        }
        .padding(.top, 8)
    }

    /// "0.00", with the separator the keyboard offers.
    private var amountPlaceholder: String {
        fractionDigits == 0 ? "0" : "0\(Locale.current.decimalSeparator ?? ".")00"
    }

    /// Keeps only what an amount may contain while typing.
    private var amountBinding: Binding<String> {
        Binding {
            amountText
        } set: { newValue in
            amountText = Money.sanitizeInput(newValue, fractionDigits: fractionDigits)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AdaptiveStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("CATEGORY · REQUIRED")
                    .font(.label)
                    .tracking(0.3)
                    .foregroundStyle(.textSecondary)
                Spacer(minLength: 8)
                Button("New category") { showCategoryEditor = true }
                    .font(.rowDetail)
                    .foregroundStyle(.dataBlue)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, 4)
            FlowLayout {
                ForEach(categories) { category in
                    let isOn = category.id == selectedCategoryID
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { selectedCategoryID = category.id }
                    } label: {
                        CategoryChipLabel(info: category.info, isOn: isOn)
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(category.name)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            FormRow(label: "Title") {
                TextField("Title", text: $title,
                          prompt: Text("Optional, e.g. K-Market").foregroundStyle(.textTertiary))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.textPrimary)
                    .focused($focus, equals: .title)
                    .submitLabel(.done)
            }
            RowDivider()
            AdaptiveStack {
                Text("Date")
                    .font(.body)
                    .foregroundStyle(.textPrimary)
                Spacer(minLength: 0)
                FlowLayout(spacing: 6) {
                    dateChip("Today", choice: .today)
                    dateChip("Yesterday", choice: .yesterday)
                    dateChip(dateChoice == .picked ? DateText.shortDay(pickedDate) : "Pick…", choice: .picked)
                }
                .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: false)
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .frame(minHeight: 56)
        }
        .card(padding: nil)
    }

    private func dateChip(_ text: String, choice: DateChoice) -> some View {
        Chip(title: text, isOn: dateChoice == choice) {
            if choice == .picked {
                focus = nil
                showDatePicker = true
            }
            withAnimation(.snappy(duration: 0.2)) { dateChoice = choice }
        }
    }

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker("Date", selection: $pickedDate, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(.dataBlue)
                .padding(.horizontal, 16)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(.appBackground)
                .navigationTitle("Pick a date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showDatePicker = false }
                            .tint(.textPrimary)
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.appBackground)
    }

    private var saveBar: some View {
        VStack(spacing: 10) {
            if let hint = draft.hint {
                Text(hint)
                    .font(.rowDetail)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button(saveLabel, action: save)
                .buttonStyle(.primary)
                .disabled(!draft.canSave)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.appBackground)
    }

    private var saveLabel: String {
        let verb = editing == nil ? "Add" : "Save"
        if draft.canSave, let cents = draft.cents {
            return "\(verb) \(settings.money.format(cents))"
        }
        return editing == nil ? "Add purchase" : "Save"
    }

    // MARK: Saving

    private func load() {
        if let editing {
            amountText = Money.inputText(cents: editing.amountCents, fractionDigits: fractionDigits)
            selectedCategoryID = editing.category?.id
            title = editing.title ?? ""
            pickedDate = editing.date
            switch DateText.relative(editing.date) {
            case "Today": dateChoice = .today
            case "Yesterday": dateChoice = .yesterday
            default: dateChoice = .picked
            }
            return
        }
        if Self.preselectsLastCategory { selectedCategoryID = lastUsedCategoryID() }
        focus = .amount
    }

    private func lastUsedCategoryID() -> UUID? {
        var descriptor = FetchDescriptor<Purchase>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first?.category?.id
    }

    private func save() {
        guard let cents = draft.cents, let category = selectedCategory else { return }
        if let editing {
            editing.amountCents = cents
            editing.category = category
            editing.title = Purchase.cleanTitle(title)
            editing.date = chosenDate
            try? modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            modelContext.insert(Purchase(amountCents: cents, date: chosenDate, title: title, category: category))
            try? modelContext.save()
            PurchaseActions.logged(cents: cents, categoryName: category.name, money: settings.money, router: router)
        }
        dismiss()
    }

    private func deletePurchase() {
        guard let editing else { return }
        let money = settings.money
        dismiss()
        PurchaseActions.delete(editing, money: money, router: router, in: modelContext)
    }
}

#if DEBUG
#Preview {
    Text("Spending")
        .sheet(isPresented: .constant(true)) { AddPurchaseSheet(mode: .new) }
        .environment(AppSettings())
        .environment(AppRouter())
        .modelContainer(DemoData.previewContainer())
        .preferredColorScheme(.dark)
}
#endif
