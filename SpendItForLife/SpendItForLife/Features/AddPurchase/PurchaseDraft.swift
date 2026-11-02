import Foundation

/// What's typed into Add purchase, and whether it can be saved.
nonisolated struct PurchaseDraft: Equatable, Sendable {
    var amountText = ""
    var hasCategory = false
    /// Decimals the chosen currency allows.
    var fractionDigits = 2

    var cents: Int? {
        guard let cents = Money.parseCents(amountText, fractionDigits: fractionDigits), cents > 0 else { return nil }
        return cents
    }

    var canSave: Bool { cents != nil && hasCategory }

    /// What's still missing, shown above the button. Nil when ready.
    var hint: String? {
        switch (cents != nil, hasCategory) {
        case (false, false): "Enter an amount and pick a category"
        case (false, true): "Enter an amount"
        case (true, false): "Pick a category"
        case (true, true): nil
        }
    }
}
