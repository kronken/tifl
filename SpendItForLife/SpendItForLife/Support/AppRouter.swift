import Observation
import SwiftData
import UIKit

/// A short message above the tab bar, with an optional Undo.
struct Toast: Identifiable {
    let id = UUID()
    var message: String
    var undo: (() -> Void)?
}

/// App-wide navigation state.
@MainActor
@Observable
final class AppRouter {
    enum TabID: String, Hashable {
        case spending, insights, settings
    }

    var tab: TabID = .spending
    /// Hides the tab bar and add button while Settings shows the currency picker.
    var isCurrencyPickerOpen = false
    var toast: Toast?
}

/// Deleting and logging, with the feedback that goes with them.
enum PurchaseActions {
    static func delete(_ purchase: Purchase, money: MoneyFormat, router: AppRouter, in context: ModelContext) {
        let cents = purchase.amountCents
        let date = purchase.date
        let title = purchase.title
        let category = purchase.category
        let categoryName = purchase.categoryInfo.name
        let createdAt = purchase.createdAt
        context.delete(purchase)
        try? context.save()
        router.toast = Toast(message: "Deleted. \(money.format(cents)) on \(categoryName).") {
            let restored = Purchase(amountCents: cents, date: date, title: title, category: category)
            restored.createdAt = createdAt
            context.insert(restored)
            try? context.save()
        }
    }

    static func logged(cents: Int, categoryName: String, money: MoneyFormat, router: AppRouter) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        router.toast = Toast(message: "Logged. \(money.format(cents)) on \(categoryName).")
    }
}
