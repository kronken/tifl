import Foundation
import Testing
@testable import SpendItForLife

struct MoneyTests {
    @Test(arguments: [
        ("23", 2_300),
        ("23.85", 2_385),
        ("23,85", 2_385),
        ("23,8", 2_380),
        ("23.", 2_300),
        (".5", 50),
        (",05", 5),
        ("0", 0),
    ])
    func parsesBothSeparators(text: String, cents: Int) {
        #expect(Money.parseCents(text) == cents)
    }

    @Test func noDigitsIsNil() {
        #expect(Money.parseCents("") == nil)
        #expect(Money.parseCents(",") == nil)
    }

    @Test func zeroDecimalCurrencyIgnoresDecimals() {
        #expect(Money.parseCents("500.50", fractionDigits: 0) == 50_000)
    }

    @Test(arguments: [
        ("12.345", "12.34"),
        ("12,3,4", "12,34"),
        ("1a2", "12"),
        (".5", "0.5"),
        ("1234567890123", "123456789"),
    ])
    func sanitizesTyping(text: String, expected: String) {
        #expect(Money.sanitizeInput(text, fractionDigits: 2) == expected)
    }

    @Test func sanitizeDropsSeparatorWithoutDecimals() {
        #expect(Money.sanitizeInput("500.5", fractionDigits: 0) == "5005")
    }

    @Test func formatsWithTheCurrencysDecimals() {
        let locale = Locale(identifier: "en_US")
        #expect(MoneyFormat(code: "EUR", locale: locale).format(128_410) == "€1,284.10")
        #expect(MoneyFormat(code: "JPY", locale: locale).format(50_000) == "¥500")
        #expect(MoneyFormat(code: "EUR", locale: locale).whole(114_049) == "€1,140")
    }

    @Test func changingCurrencyKeepsTheNumber() {
        let locale = Locale(identifier: "en_US")
        #expect(MoneyFormat(code: "USD", locale: locale).format(2_385) == "$23.85")
        #expect(MoneyFormat(code: "EUR", locale: locale).format(2_385) == "€23.85")
    }

    @Test func inputTextRoundTrips() {
        #expect(Money.inputText(cents: 2_385, fractionDigits: 2) == "23.85")
        #expect(Money.inputText(cents: 2_300, fractionDigits: 2) == "23")
        #expect(Money.inputText(cents: 2_305, fractionDigits: 2) == "23.05")
        #expect(Money.inputText(cents: 50_000, fractionDigits: 0) == "500")
    }
}

struct PurchaseDraftTests {
    @Test func needsAmountAndCategory() {
        #expect(PurchaseDraft().hint == "Enter an amount and pick a category")
        #expect(PurchaseDraft(amountText: "0").hint == "Enter an amount and pick a category")
        #expect(PurchaseDraft(amountText: "5").hint == "Pick a category")
        #expect(PurchaseDraft(hasCategory: true).hint == "Enter an amount")
        let ready = PurchaseDraft(amountText: "23,85", hasCategory: true)
        #expect(ready.canSave && ready.hint == nil && ready.cents == 2_385)
    }
}
