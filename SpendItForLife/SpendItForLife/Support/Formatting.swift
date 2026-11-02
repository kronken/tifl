import Foundation

/// Money is stored as whole cents and shown in the chosen currency.
nonisolated enum Money {
    /// The device region's currency, used until the user picks another.
    static func regionCurrencyCode(locale: Locale = .current) -> String {
        locale.currency?.identifier ?? "EUR"
    }

    /// The region's name, e.g. "Finland".
    static func regionName(locale: Locale = .current) -> String? {
        locale.region.flatMap { locale.localizedString(forRegionCode: $0.identifier) }
    }

    /// The currency's name, e.g. "Euro".
    static func currencyName(_ code: String, locale: Locale = .current) -> String {
        locale.localizedString(forCurrencyCode: code) ?? code
    }

    /// The currency's symbol, e.g. "€".
    static func symbol(_ code: String, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = code
        return formatter.currencySymbol ?? code
    }

    /// The decimals an amount may have: the currency's own, at most two.
    static func maximumFractionDigits(_ code: String, locale: Locale = .current) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = code
        return min(formatter.maximumFractionDigits, 2)
    }

    /// Keeps what's allowed in an amount field while typing: digits and one
    /// `.` or `,`, with at most `fractionDigits` digits after it.
    static func sanitizeInput(_ text: String, fractionDigits: Int) -> String {
        var result = ""
        var decimals: Int?
        for character in text where character.isASCII {
            if character.isNumber {
                if let count = decimals {
                    guard count < fractionDigits else { continue }
                    decimals = count + 1
                } else if result.count >= 9 {
                    continue
                }
                result.append(character)
            } else if character == "." || character == ",", decimals == nil, fractionDigits > 0 {
                result.append(result.isEmpty ? "0" : "")
                result.append(character)
                decimals = 0
            }
        }
        return result
    }

    /// Parses what the user typed into an amount field. Accepts "23", "23.85",
    /// "23,85" and "23,8". Digits past `fractionDigits` are ignored. Returns
    /// nil when there are no digits.
    static func parseCents(_ text: String, fractionDigits: Int = 2) -> Int? {
        let kept = text.filter { $0.isASCII && ($0.isNumber || $0 == "." || $0 == ",") }
        guard kept.contains(where: \.isNumber) else { return nil }
        let parts = kept.split(whereSeparator: { $0 == "." || $0 == "," }).map(String.init)
        let startsWithSeparator = kept.first == "." || kept.first == ","
        let whole = startsWithSeparator ? "0" : parts[0]
        let fraction = startsWithSeparator ? parts[0] : (parts.count > 1 ? parts[1] : "")
        guard let units = Int(whole) else { return nil }
        let (scaled, overflow) = units.multipliedReportingOverflow(by: 100)
        guard !overflow else { return nil }
        let used = String(fraction.prefix(min(fractionDigits, 2)))
        let cents = used.isEmpty ? 0 : Int(used.padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0
        return scaled + cents
    }

    /// What's typed into the amount field when editing a purchase, e.g. "23.85"
    /// or "24" when the currency has no decimals.
    static func inputText(cents: Int, fractionDigits: Int) -> String {
        if fractionDigits == 0 { return String((cents + 50) / 100) }
        let fraction = cents % 100
        return fraction == 0 ? String(cents / 100) : String(format: "%d.%02d", cents / 100, fraction)
    }
}

/// Formats cents in one currency. The one place amounts turn into text.
nonisolated struct MoneyFormat: Equatable, Sendable {
    var code: String
    var locale: Locale = .current

    /// "€1,284.10", with the currency's usual decimals. For lists and totals.
    func format(_ cents: Int) -> String {
        (Decimal(cents) / 100).formatted(.currency(code: code).locale(locale))
    }

    /// "€1,284". For chart labels and averages.
    func whole(_ cents: Int) -> String {
        (Decimal(cents) / 100).formatted(.currency(code: code).precision(.fractionLength(0)).locale(locale))
    }
}

/// Dates as the designs write them.
nonisolated enum DateText {
    /// "Monday 2 November".
    static func fullDay(_ date: Date, calendar: Calendar = .current) -> String {
        date.formatted(.verbatim("\(weekday: .wide) \(day: .defaultDigits) \(month: .wide)",
                                 locale: calendar.locale ?? .current, timeZone: calendar.timeZone, calendar: calendar))
    }

    /// "TODAY", "YESTERDAY", "SATURDAY 31 OCTOBER", with the year if it isn't this one.
    static func sectionTitle(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        relative(date, now: now, calendar: calendar)?.uppercased() ?? {
            var text = fullDay(date, calendar: calendar)
            if !calendar.isDate(date, equalTo: now, toGranularity: .year) {
                text += " \(calendar.component(.year, from: date))"
            }
            return text.uppercased()
        }()
    }

    /// "Today" or "Yesterday"; nil for any other day.
    static func relative(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String? {
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        if day == today { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), day == yesterday { return "Yesterday" }
        return nil
    }

    /// "today", "yesterday" or "31 October", for VoiceOver.
    static func spoken(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        relative(date, now: now, calendar: calendar)?.lowercased() ?? shortDay(date, calendar: calendar, wide: true)
    }

    /// "Oct 14", or "October 14" when `wide`.
    static func shortDay(_ date: Date, calendar: Calendar = .current, wide: Bool = false) -> String {
        let locale = calendar.locale ?? .current
        return wide
            ? date.formatted(.verbatim("\(month: .wide) \(day: .defaultDigits)", locale: locale, timeZone: calendar.timeZone, calendar: calendar))
            : date.formatted(.verbatim("\(month: .abbreviated) \(day: .defaultDigits)", locale: locale, timeZone: calendar.timeZone, calendar: calendar))
    }

    /// "October".
    static func month(_ date: Date, calendar: Calendar = .current) -> String {
        date.formatted(.verbatim("\(month: .wide)", locale: calendar.locale ?? .current, timeZone: calendar.timeZone, calendar: calendar))
    }

    /// "October 2026".
    static func monthYear(_ date: Date, calendar: Calendar = .current) -> String {
        date.formatted(.verbatim("\(month: .wide) \(year: .defaultDigits)", locale: calendar.locale ?? .current, timeZone: calendar.timeZone, calendar: calendar))
    }

    /// "Jan 2023".
    static func shortMonthYear(_ date: Date, calendar: Calendar = .current) -> String {
        date.formatted(.verbatim("\(month: .abbreviated) \(year: .defaultDigits)", locale: calendar.locale ?? .current, timeZone: calendar.timeZone, calendar: calendar))
    }

    /// "O", the single letter under a month's bar.
    static func monthLetter(_ date: Date, calendar: Calendar = .current) -> String {
        date.formatted(.verbatim("\(month: .narrow)", locale: calendar.locale ?? .current, timeZone: calendar.timeZone, calendar: calendar))
    }
}
