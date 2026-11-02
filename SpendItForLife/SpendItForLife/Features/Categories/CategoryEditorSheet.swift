import SwiftData
import SwiftUI

/// New category / Edit category. Opened from Settings or from Add purchase,
/// which pre-selects a newly created category.
struct CategoryEditorSheet: View {
    enum Mode {
        case new
        case edit(Category)
    }

    let mode: Mode
    /// Called with a newly created category after Save.
    var onCreate: (Category) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Category.sortOrder), SortDescriptor(\Category.createdAt)])
    private var categories: [Category]

    @State private var name = ""
    @State private var color = CategoryColor.denim
    @State private var icon = CategoryIcon.cart
    // Copied on appear: the body must not touch the category once it's deleted.
    @State private var editingID: UUID?
    @State private var purchaseCount = 0
    @State private var confirmDelete = false
    @State private var showMovePicker = false
    /// Runs after the move picker has closed.
    @State private var pendingDelete: (() -> Void)?

    private var isEditing: Bool {
        if case .edit = mode { true } else { false }
    }

    private var editing: Category? {
        if case .edit(let category) = mode { category } else { nil }
    }

    private var others: [Category] {
        categories.filter { $0.id != editingID }
    }

    private var nameIsTaken: Bool {
        CategoryRules.isTaken(name, among: others.map(\.name))
    }

    private var canSave: Bool {
        CategoryRules.isValid(name) && !nameIsTaken
    }

    var body: some View {
        EditSheet(title: isEditing ? "Edit category" : "New category", canSave: canSave, onSave: save) {
            preview

            VStack(alignment: .leading, spacing: 8) {
                FormRow(label: "Name") {
                    TextField("Name", text: $name,
                              prompt: Text("Groceries, Rent, Coffee").foregroundStyle(.textTertiary))
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                }
                .foregroundStyle(.textPrimary)
                .card(padding: nil)
                if nameIsTaken {
                    Text("You already have a category with this name.")
                        .font(.footnote)
                        .foregroundStyle(.warning)
                        .padding(.horizontal, 4)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Color")
                ColorSwatchRow(selection: $color)
                    .card(padding: 12)
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Icon")
                IconGrid(icons: CategoryIcon.allCases, color: color.color, selection: $icon)
                    .card(padding: 12)
            }

            if isEditing {
                deleteSection
            }
        }
        .onAppear(perform: load)
        .confirmationDialog("Delete \(name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete category", role: .destructive) {
                if let editing { finishDelete { Category.deleteWithPurchases(editing, in: modelContext) } }
            }
        }
        .sheet(isPresented: $showMovePicker, onDismiss: runPendingDelete) {
            if let editing {
                MovePurchasesSheet(count: purchaseCount, others: others) { target in
                    pendingDelete = { Category.delete(editing, movingPurchasesTo: target, in: modelContext) }
                    showMovePicker = false
                } onDeletePurchases: {
                    pendingDelete = { Category.deleteWithPurchases(editing, in: modelContext) }
                    showMovePicker = false
                }
            }
        }
    }

    // MARK: Parts

    private var preview: some View {
        VStack(spacing: 10) {
            Image(systemName: icon.symbolName)
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(color.color)
                .frame(width: 88, height: 88)
                .background(color.color.opacity(0.16), in: .rect(cornerRadius: Radius.card))
                .overlay { RoundedRectangle(cornerRadius: Radius.card).strokeBorder(.stroke, lineWidth: 1) }
            Text(CategoryRules.isValid(name) ? name.trimmingCharacters(in: .whitespacesAndNewlines) : "Category name")
                .font(.cardTitle)
                .foregroundStyle(CategoryRules.isValid(name) ? .textPrimary : .textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preview: \(CategoryRules.isValid(name) ? name : "Category name"), \(color.name), \(icon.name)")
    }

    private var deleteSection: some View {
        VStack(spacing: 8) {
            Button("Delete category", role: .destructive, action: startDelete)
                .buttonStyle(DeleteButtonStyle())
                .disabled(others.isEmpty)
            Text(deleteNote)
                .font(.footnote)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 12)
    }

    private var deleteNote: String {
        if others.isEmpty { return "This is your only category. Add another before deleting it." }
        switch purchaseCount {
        case 0: return "No purchases use it."
        case 1: return "1 purchase uses it. You choose where it moves before it goes."
        default: return "\(purchaseCount.formatted()) purchases use it. You choose where they move before it goes."
        }
    }

    // MARK: Saving

    private func load() {
        guard let editing else { return }
        editingID = editing.id
        name = editing.name
        color = CategoryColor(key: editing.colorKey)
        icon = CategoryIcon(rawValue: editing.symbolName) ?? .tag
        purchaseCount = editing.purchaseCount
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let editing {
            editing.name = trimmed
            editing.colorKey = color.rawValue
            editing.symbolName = icon.symbolName
        } else {
            onCreate(Category.create(name: trimmed, color: color, icon: icon, in: modelContext))
        }
        try? modelContext.save()
    }

    private func startDelete() {
        if purchaseCount == 0 {
            confirmDelete = true
        } else {
            showMovePicker = true
        }
    }

    private func runPendingDelete() {
        guard let pendingDelete else { return }
        finishDelete(pendingDelete)
    }

    private func finishDelete(_ action: () -> Void) {
        action()
        dismiss()
    }
}

/// A full-width capsule in the destructive colour.
struct DeleteButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rowTitle)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(isEnabled ? AnyShapeStyle(.destructive) : AnyShapeStyle(.textTertiary))
            .background(.surface, in: .capsule)
            .overlay { Capsule().strokeBorder(.stroke, lineWidth: 1) }
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// MARK: - Move picker

/// Where a deleted category's purchases go.
private struct MovePurchasesSheet: View {
    var count: Int
    var others: [Category]
    var onMove: (Category) -> Void
    var onDeletePurchases: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmDeleteAll = false

    private var countText: String {
        count == 1 ? "1 purchase" : "\(count.formatted()) purchases"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 0) {
                        ForEach(Array(others.enumerated()), id: \.element.id) { index, category in
                            if index > 0 { RowDivider() }
                            Button { onMove(category) } label: {
                                HStack(spacing: 12) {
                                    CategoryTile(symbol: category.symbolName, color: category.info.color,
                                                 size: 36, cornerRadius: Radius.thumb)
                                    Text(category.name)
                                        .font(.body)
                                        .foregroundStyle(.textPrimary)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(minHeight: 56)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .card(padding: nil)

                    Button("Delete purchases too", role: .destructive) { confirmDeleteAll = true }
                        .buttonStyle(DeleteButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(.appBackground)
            .navigationTitle("Move \(countText) to…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(.textPrimary)
                }
            }
            .confirmationDialog("Delete \(countText)?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
                Button("Delete category and purchases", role: .destructive, action: onDeletePurchases)
            } message: {
                Text("This can't be undone.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.appBackground)
    }
}

#Preview {
    Text("Settings")
        .sheet(isPresented: .constant(true)) { CategoryEditorSheet(mode: .new) }
        .modelContainer(DemoData.previewContainer())
        .preferredColorScheme(.dark)
}
