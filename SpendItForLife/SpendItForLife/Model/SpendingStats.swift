import Foundation

/// Months or years on Insights.
nonisolated enum StatsPeriod: Hashable, Sendable {
    case months, years

    var component: Calendar.Component { self == .months ? .month : .year }
}

/// One bar on the Insights chart: spending in a month or a year, by category.
nonisolated struct PeriodBar: Identifiable, Equatable, Sendable {
    var start: Date
    var end: Date
    /// "October 2026", "2026 so far".
    var name: String
    /// "O", "2026".
    var short: String
    /// The current month or year, which isn't over yet.
    var isPartial: Bool
    var cents: [UUID: Int]

    var id: Date { start }

    /// The bar's total, for one category when `focus` is set.
    func total(focus: UUID? = nil) -> Int {
        if let focus { return cents[focus] ?? 0 }
        return cents.values.reduce(0, +)
    }

    func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }
}

/// A category's share of a period, for the breakdown and the month card.
nonisolated struct CategoryShare: Identifiable, Equatable, Sendable {
    var category: CategoryInfo
    var cents: Int
    /// Whole percent of the full period total.
    var percent: Int

    var id: UUID { category.id }
}

/// The card at the top of Spending.
nonisolated struct MonthSummary: Equatable, Sendable {
    var monthName: String
    var total: Int
    var shares: [CategoryShare]
    /// "October closed at €1,284.10 · 2 days into November".
    var footer: String
}

/// One row of the trends card.
nonisolated struct CategoryTrend: Identifiable, Equatable, Sendable {
    var category: CategoryInfo
    var averageCents: Int
    /// The category's spending per complete month, oldest first.
    var series: [Int]
    /// Latest complete month against the average, in whole percent. Nil when
    /// the average is zero.
    var change: Int?

    var id: UUID { category.id }
}

nonisolated struct TrendSummary: Equatable, Sendable {
    /// The months compared, oldest first.
    var months: [Date]
    var rows: [CategoryTrend]

    /// "Change compares October with your 12-month average."
    func footer(calendar: Calendar = .current) -> String {
        guard let latest = months.last else { return "" }
        return "Change compares \(DateText.month(latest, calendar: calendar)) with your \(months.count)-month average."
    }
}

/// Aggregation for Spending and Insights, on plain values so it can be tested.
nonisolated enum SpendingStats {
    /// Trend rows need at least this many complete months.
    static let minimumTrendMonths = 2

    // MARK: Bars

    /// Months: the last 12 with the current one last, from the first purchase
    /// on. Years: every year with data plus the current one.
    static func bars(_ purchases: [PurchaseInfo], period: StatsPeriod, now: Date = .now,
                     calendar: Calendar = .current) -> [PeriodBar] {
        guard let current = calendar.dateInterval(of: period.component, for: now)?.start else { return [] }
        var byPeriod: [Date: [UUID: Int]] = [:]
        for purchase in purchases {
            guard let start = calendar.dateInterval(of: period.component, for: purchase.date)?.start else { continue }
            byPeriod[start, default: [:]][purchase.categoryID, default: 0] += purchase.cents
        }

        let starts: [Date]
        switch period {
        case .months:
            let first = byPeriod.keys.min() ?? current
            starts = (0..<12).reversed().compactMap { calendar.date(byAdding: .month, value: -$0, to: current) }
                .filter { $0 >= first }
        case .years:
            starts = Set(byPeriod.keys.filter { $0 <= current }).union([current]).sorted()
        }

        return starts.compactMap { start in
            guard let end = calendar.date(byAdding: period.component, value: 1, to: start) else { return nil }
            let isPartial = start == current
            let year = calendar.component(.year, from: start)
            return PeriodBar(
                start: start,
                end: end,
                name: period == .months
                    ? DateText.monthYear(start, calendar: calendar)
                    : (isPartial ? "\(year) so far" : "\(year)"),
                short: period == .months ? DateText.monthLetter(start, calendar: calendar) : "\(year)",
                isPartial: isPartial,
                cents: byPeriod[start] ?? [:]
            )
        }
    }

    /// The average of complete periods, for one category when `focus` is set.
    /// Nil when no period is complete yet.
    static func average(of bars: [PeriodBar], focus: UUID? = nil) -> Int? {
        let complete = bars.filter { !$0.isPartial }
        guard !complete.isEmpty else { return nil }
        let sum = complete.reduce(0) { $0 + $1.total(focus: focus) }
        return Int((Double(sum) / Double(complete.count)).rounded())
    }

    /// The bar Insights opens on: the latest complete one, or the current one
    /// when nothing is complete.
    static func defaultBar(in bars: [PeriodBar]) -> PeriodBar? {
        bars.last { !$0.isPartial } ?? bars.last
    }

    // MARK: Notes

    /// The line under the hero total on Insights.
    static func note(for bar: PeriodBar, total: Int, average: Int?, period: StatsPeriod, money: MoneyFormat,
                     now: Date = .now, calendar: Calendar = .current) -> String {
        if bar.isPartial {
            switch period {
            case .months:
                let days = dayCount(calendar.component(.day, from: now))
                guard let average else { return "\(days) in" }
                return "\(days) in · average month is \(money.whole(average))"
            case .years:
                let month = calendar.component(.month, from: now)
                let day = calendar.component(.day, from: now)
                let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
                let months = Double(month - 1) + Double(day) / Double(daysInMonth)
                let perMonth = Int((Double(total) / months).rounded())
                return "January to today · \(money.whole(perMonth)) a month"
            }
        }
        guard let average, average > 0 else { return "" }
        let difference = (Double(total) - Double(average)) / Double(average) * 100
        if abs(difference) < 3 { return "About your average" }
        return "\(Int(abs(difference).rounded()))% \(difference > 0 ? "above" : "below") your average of \(money.whole(average))"
    }

    private static func dayCount(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count) days"
    }

    // MARK: Shares

    /// Every category's share of a period, biggest first. Percentages are of
    /// the full total. `.none` is included only when it has spending.
    static func shares(in cents: [UUID: Int], categories: [CategoryInfo]) -> [CategoryShare] {
        let total = cents.values.reduce(0, +)
        var all = categories
        if (cents[CategoryInfo.none.id] ?? 0) > 0 { all.append(.none) }
        return all.map { category in
            let amount = cents[category.id] ?? 0
            let percent = total > 0 ? Int((Double(amount) / Double(total) * 100).rounded()) : 0
            return CategoryShare(category: category, cents: amount, percent: percent)
        }
        .sorted { $0.cents != $1.cents ? $0.cents > $1.cents : $0.category.sortOrder < $1.category.sortOrder }
    }

    // MARK: Month card

    static func monthSummary(_ purchases: [PurchaseInfo], categories: [CategoryInfo], money: MoneyFormat,
                             now: Date = .now, calendar: Calendar = .current) -> MonthSummary {
        let bars = bars(purchases, period: .months, now: now, calendar: calendar)
        let currentCents = bars.last?.cents ?? [:]
        let currentName = DateText.month(now, calendar: calendar)
        var footer = "\(dayCount(calendar.component(.day, from: now))) into \(currentName)"
        if bars.count > 1, let previous = bars.dropLast().last {
            footer = "\(DateText.month(previous.start, calendar: calendar)) closed at \(money.format(previous.total())) · " + footer
        }
        return MonthSummary(
            monthName: currentName,
            total: currentCents.values.reduce(0, +),
            shares: shares(in: currentCents, categories: categories).filter { $0.cents > 0 },
            footer: footer
        )
    }

    // MARK: Trends

    /// Per category over the last 12 complete months. Nil with fewer than two
    /// complete months of data.
    static func trends(_ purchases: [PurchaseInfo], categories: [CategoryInfo], now: Date = .now,
                       calendar: Calendar = .current) -> TrendSummary? {
        // Thirteen months back from the current one gives 12 complete ones.
        guard let current = calendar.dateInterval(of: .month, for: now)?.start,
              let earliest = calendar.date(byAdding: .month, value: -12, to: current),
              let first = purchases.map(\.date).min(),
              let firstMonth = calendar.dateInterval(of: .month, for: first)?.start else { return nil }
        let months = (1...12).reversed().compactMap { calendar.date(byAdding: .month, value: -$0, to: current) }
            .filter { $0 >= max(firstMonth, earliest) }
        guard months.count >= minimumTrendMonths else { return nil }

        var cents: [UUID: [Date: Int]] = [:]
        for purchase in purchases {
            guard let month = calendar.dateInterval(of: .month, for: purchase.date)?.start else { continue }
            cents[purchase.categoryID, default: [:]][month, default: 0] += purchase.cents
        }

        let rows = categories.map { category in
            let series = months.map { cents[category.id]?[$0] ?? 0 }
            let average = Double(series.reduce(0, +)) / Double(series.count)
            let change = average > 0
                ? Int(((Double(series.last ?? 0) - average) / average * 100).rounded())
                : nil
            return CategoryTrend(category: category, averageCents: Int(average.rounded()), series: series, change: change)
        }
        return TrendSummary(months: months, rows: rows)
    }

    /// "+12%", "−8%", or "—" with no change to show.
    static func changeText(_ change: Int?) -> String {
        guard let change else { return "—" }
        return "\(change >= 0 ? "+" : "−")\(abs(change))%"
    }
}
