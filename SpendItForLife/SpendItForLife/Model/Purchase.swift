import Foundation
import SwiftData

/// One logged purchase. Every property is optional or defaulted, as required
/// for CloudKit sync; "required" rules live in the UI.
@Model
final class Purchase {
    var id: UUID = UUID()
    /// Whole hundredths in every currency. Changing currency never converts it.
    var amountCents: Int = 0
    /// Start of the local day.
    var date: Date = Date.now
    /// Trimmed; nil when empty.
    var title: String?
    var category: Category?
    var createdAt: Date = Date.now

    init(amountCents: Int, date: Date, title: String? = nil, category: Category?, calendar: Calendar = .current) {
        self.amountCents = amountCents
        self.date = calendar.startOfDay(for: date)
        self.title = Self.cleanTitle(title)
        self.category = category
    }

    /// Trims a title; an empty one becomes nil.
    nonisolated static func cleanTitle(_ title: String?) -> String? {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension Purchase {
    var info: PurchaseInfo {
        PurchaseInfo(cents: amountCents, date: date, categoryID: category?.id ?? CategoryInfo.none.id)
    }

    var categoryInfo: CategoryInfo { category?.info ?? .none }

    /// The title, or the category's name when there is none.
    var displayTitle: String { title ?? categoryInfo.name }
}

/// A purchase as plain values, so the stats can be tested without SwiftData.
nonisolated struct PurchaseInfo: Equatable, Sendable {
    var cents: Int
    var date: Date
    var categoryID: UUID
}
