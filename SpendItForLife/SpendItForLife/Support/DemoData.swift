#if DEBUG
import Foundation
import SwiftData

/// Debug-only sample spending based on the designs. Enable with the launch
/// argument `-demoData YES`; it lives in an in-memory store and never touches
/// real data or iCloud. `-demoEmpty YES` keeps the categories but no purchases,
/// `-demoNew YES` shows a first launch.
enum DemoData {
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: "demoData") }
    private static var isEmpty: Bool { UserDefaults.standard.bool(forKey: "demoEmpty") }
    private static var isNew: Bool { UserDefaults.standard.bool(forKey: "demoNew") }

    static func makeContainer() -> ModelContainer {
        let container = inMemoryContainer()
        guard !isNew else { return container }
        insertSamples(into: container.mainContext, withPurchases: !isEmpty)
        return container
    }

    static func inMemoryContainer() -> ModelContainer {
        let schema = Schema([Category.self, Purchase.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    /// A seeded container for previews.
    static func previewContainer() -> ModelContainer {
        let container = inMemoryContainer()
        insertSamples(into: container.mainContext, withPurchases: true)
        return container
    }

    private static func insertSamples(into context: ModelContext, withPurchases: Bool, calendar: Calendar = .current) {
        let specs: [(String, CategoryColor, CategoryIcon, Int, [String])] = [
            ("Groceries", .moss, .cart, 3_950, ["K-Market", "Lidl", "Prisma"]),
            ("Eating out", .clay, .forkKnife, 2_200, ["Lunch", "Dinner in Kallio", ""]),
            ("Transport", .denim, .tram, 720, ["", "Day ticket"]),
            ("Home", .teal, .house, 3_500, ["", "Light bulbs"]),
            ("Clothing", .violet, .tshirt, 8_500, ["Wool socks", "Rain jacket"]),
            ("Subscriptions", .rose, .repeatArrows, 1_199, ["Music", "News"])
        ]
        let categories = specs.enumerated().map { index, spec in
            let category = Category(name: spec.0, color: spec.1, icon: spec.2, sortOrder: index)
            context.insert(category)
            return category
        }
        guard withPurchases else {
            try? context.save()
            return
        }

        let today = calendar.startOfDay(for: .now)
        // Repeatable numbers, so screenshots stay the same.
        var seed = 11
        func next(_ limit: Int) -> Int {
            seed = (seed &* 1_103_515_245 &+ 12_345) & 0x7FFF_FFFF
            return (seed >> 8) % limit
        }
        for dayOffset in stride(from: 3, through: 1_400, by: 3) {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            for _ in 0...next(2) {
                let index = [0, 0, 0, 1, 1, 2, 3, 4, 5][next(9)]
                let spec = specs[index]
                let cents = spec.3 / 2 + next(spec.3)
                let title = spec.4[next(spec.4.count)]
                context.insert(Purchase(amountCents: cents, date: date, title: title, category: categories[index]))
            }
        }
        // The recent days from the Spending design.
        let recent: [(Int, Int, String, Int)] = [
            (0, 0, "K-Market Kamppi", 2_385), (0, 1, "Lunch", 1_350),
            (1, 0, "Lidl", 4_120), (1, 5, "Spotify", 1_199),
            (2, 1, "Dinner in Kallio", 5_800), (2, 4, "Darn Tough socks", 2_600), (2, 3, "", 990)
        ]
        for (dayOffset, index, title, cents) in recent {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            context.insert(Purchase(amountCents: cents, date: date, title: title, category: categories[index]))
        }
        try? context.save()
    }
}
#endif
