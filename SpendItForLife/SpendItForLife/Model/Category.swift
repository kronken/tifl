import Foundation
import SwiftData
import SwiftUI

/// A user-made spending category. Every property is optional or defaulted, as
/// required for CloudKit sync; "required" rules live in the UI.
@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    /// Raw value of `CategoryColor`.
    var colorKey: String = "moss"
    /// Raw value of `CategoryIcon`.
    var symbolName: String = "cart"
    /// Position in Settings and Add purchase.
    var sortOrder: Int = 0
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Purchase.category)
    var purchases: [Purchase]? = []

    init(name: String, color: CategoryColor, icon: CategoryIcon, sortOrder: Int = 0) {
        self.name = name
        self.colorKey = color.rawValue
        self.symbolName = icon.symbolName
        self.sortOrder = sortOrder
    }
}

extension Category {
    var info: CategoryInfo {
        CategoryInfo(id: id, name: name, colorKey: colorKey, symbolName: symbolName, sortOrder: sortOrder)
    }

    var purchaseCount: Int { purchases?.count ?? 0 }
}

// MARK: - Changes

extension Category {
    /// A new category at the end of the list.
    @discardableResult
    static func create(name: String, color: CategoryColor, icon: CategoryIcon, in context: ModelContext) -> Category {
        let all = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        let category = Category(name: name.trimmingCharacters(in: .whitespacesAndNewlines), color: color, icon: icon,
                                sortOrder: (all.map(\.sortOrder).max() ?? -1) + 1)
        context.insert(category)
        return category
    }

    /// Writes a new order after a drag in Settings.
    static func move(_ ordered: [Category], from source: IndexSet, to destination: Int) {
        var list = ordered
        list.move(fromOffsets: source, toOffset: destination)
        for (index, category) in list.enumerated() where category.sortOrder != index {
            category.sortOrder = index
        }
    }

    /// Moves this category's purchases to `target`, then deletes it. Refuses
    /// to delete the last category. Returns whether it was deleted.
    @discardableResult
    static func delete(_ category: Category, movingPurchasesTo target: Category, in context: ModelContext) -> Bool {
        guard target.id != category.id, canDelete(in: context) else { return false }
        for purchase in category.purchases ?? [] {
            purchase.category = target
        }
        context.delete(category)
        try? context.save()
        return true
    }

    /// Deletes this category and its purchases. Refuses to delete the last
    /// category. Returns whether it was deleted.
    @discardableResult
    static func deleteWithPurchases(_ category: Category, in context: ModelContext) -> Bool {
        guard canDelete(in: context) else { return false }
        for purchase in category.purchases ?? [] {
            context.delete(purchase)
        }
        context.delete(category)
        try? context.save()
        return true
    }

    private static func canDelete(in context: ModelContext) -> Bool {
        ((try? context.fetchCount(FetchDescriptor<Category>())) ?? 0) > 1
    }

    /// Two devices can each create the same category before syncing, e.g. a
    /// reinstall that finishes onboarding before iCloud has delivered. The
    /// older one is kept and the other's purchases move to it.
    static func mergeDuplicates(in context: ModelContext) {
        let all = ((try? context.fetch(FetchDescriptor<Category>())) ?? [])
            .sorted { $0.createdAt != $1.createdAt ? $0.createdAt < $1.createdAt : $0.id.uuidString < $1.id.uuidString }
        var keepers: [String: Category] = [:]
        var merged = false
        for category in all {
            let key = CategoryRules.normalized(category.name)
            guard let keeper = keepers[key] else {
                keepers[key] = category
                continue
            }
            for purchase in category.purchases ?? [] {
                purchase.category = keeper
            }
            context.delete(category)
            merged = true
        }
        if merged { try? context.save() }
    }
}

// MARK: - Plain values

/// A category as plain values, so the rules and stats can be tested without
/// SwiftData.
nonisolated struct CategoryInfo: Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var colorKey: String
    var symbolName: String
    var sortOrder: Int

    /// Stands in for purchases that have no category, which sync or a deleted
    /// category on another device can leave behind.
    static let none = CategoryInfo(id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
                                   name: "No category", colorKey: CategoryColor.steel.rawValue,
                                   symbolName: CategoryIcon.tag.symbolName, sortOrder: .max)

    var color: Color { CategoryColor(key: colorKey).color }
    var symbol: String { CategoryIcon.symbol(for: symbolName) }
}

nonisolated enum CategoryRules {
    static func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Whether `name` is not empty once trimmed.
    static func isValid(_ name: String) -> Bool {
        !normalized(name).isEmpty
    }

    /// Whether `names` (the other categories) already has `name`, ignoring case.
    static func isTaken(_ name: String, among names: [String]) -> Bool {
        let wanted = normalized(name)
        return !wanted.isEmpty && names.contains { normalized($0) == wanted }
    }
}
