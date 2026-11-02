import Foundation
import SwiftData
import Testing
@testable import SpendItForLife

@MainActor
struct CategoryTests {
    private let context: ModelContext

    init() throws {
        let schema = Schema([SpendItForLife.Category.self, Purchase.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        context = ModelContext(try ModelContainer(for: schema, configurations: [configuration]))
    }

    private func category(_ name: String) -> SpendItForLife.Category {
        SpendItForLife.Category.create(name: name, color: .moss, icon: .cart, in: context)
    }

    private func purchase(in category: SpendItForLife.Category, cents: Int = 100) {
        context.insert(Purchase(amountCents: cents, date: .now, category: category))
    }

    private var allCategories: [SpendItForLife.Category] {
        (try? context.fetch(FetchDescriptor<SpendItForLife.Category>())) ?? []
    }

    private var allPurchases: [Purchase] {
        (try? context.fetch(FetchDescriptor<Purchase>())) ?? []
    }

    @Test func createTrimsAndAppends() {
        let first = category("  Home ")
        let second = category("Bills")
        #expect(first.name == "Home")
        #expect(first.sortOrder == 0)
        #expect(second.sortOrder == 1)
    }

    @Test func deleteMovesPurchasesToTheTarget() {
        let old = category("Old")
        let target = category("Target")
        purchase(in: old)
        purchase(in: old)
        try? context.save()
        #expect(SpendItForLife.Category.delete(old, movingPurchasesTo: target, in: context))
        #expect(allCategories.map(\.name) == ["Target"])
        #expect(allPurchases.count == 2)
        #expect(allPurchases.allSatisfy { $0.category?.name == "Target" })
    }

    @Test func deleteWithPurchasesRemovesThem() {
        let old = category("Old")
        let other = category("Other")
        purchase(in: old)
        purchase(in: other)
        try? context.save()
        #expect(SpendItForLife.Category.deleteWithPurchases(old, in: context))
        #expect(allPurchases.count == 1)
        #expect(allPurchases.first?.category?.name == "Other")
    }

    @Test func theLastCategoryCannotBeDeleted() {
        let only = category("Only")
        purchase(in: only)
        try? context.save()
        #expect(!SpendItForLife.Category.deleteWithPurchases(only, in: context))
        #expect(!SpendItForLife.Category.delete(only, movingPurchasesTo: only, in: context))
        #expect(allCategories.count == 1)
        #expect(allPurchases.count == 1)
    }

    @Test func moveRewritesTheOrder() {
        let list = [category("A"), category("B"), category("C")]
        SpendItForLife.Category.move(list, from: IndexSet(integer: 2), to: 0)
        #expect(list.sorted { $0.sortOrder < $1.sortOrder }.map(\.name) == ["C", "A", "B"])
    }

    @Test func mergeKeepsTheOlderCategoryAndItsPurchases() {
        let older = category("Groceries")
        older.createdAt = .distantPast
        let newer = category("groceries ")
        purchase(in: newer)
        try? context.save()
        SpendItForLife.Category.mergeDuplicates(in: context)
        #expect(allCategories.count == 1)
        #expect(allCategories.first?.id == older.id)
        #expect(allPurchases.first?.category?.id == older.id)
    }

    @Test func purchaseStoresStartOfDayAndCleanTitle() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Helsinki")!
        let noon = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 12))!
        let item = Purchase(amountCents: 1, date: noon, title: "   ", category: nil, calendar: calendar)
        #expect(item.date == calendar.startOfDay(for: noon))
        #expect(item.title == nil)
        #expect(Purchase.cleanTitle(" K-Market ") == "K-Market")
    }
}

struct CategoryRuleTests {
    @Test func namesMustBeNonEmptyAndUnique() {
        #expect(!CategoryRules.isValid("   "))
        #expect(CategoryRules.isValid(" Home "))
        #expect(CategoryRules.isTaken(" GROCERIES ", among: ["Groceries"]))
        #expect(!CategoryRules.isTaken("Home", among: ["Groceries"]))
        #expect(!CategoryRules.isTaken("  ", among: ["  "]))
    }

    @Test func unknownKeysFallBack() {
        #expect(CategoryColor(key: "neon") == .steel)
        #expect(CategoryIcon.symbol(for: "unknown") == "tag")
        #expect(CategoryIcon.onboarding.count == 12)
        #expect(CategoryIcon.allCases.count == 18)
    }
}

struct OnboardingGateTests {
    @Test func freshInstallNeedsOnboarding() {
        #expect(OnboardingGate.isNeeded(hasCompleted: false, categoryCount: 0))
    }

    @Test func syncedCategoriesSkipIt() {
        #expect(!OnboardingGate.isNeeded(hasCompleted: false, categoryCount: 3))
    }

    @Test func completedStaysCompleted() {
        #expect(!OnboardingGate.isNeeded(hasCompleted: true, categoryCount: 0))
    }
}
