import Foundation
import Testing
@testable import SpendItForLife

struct SpendingStatsTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Helsinki")!
        c.locale = Locale(identifier: "en_US")
        return c
    }()
    private let groceries = UUID()
    private let eating = UUID()
    private let money = MoneyFormat(code: "EUR", locale: Locale(identifier: "en_US"))

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private var now: Date { date(2026, 11, 2) }

    private func info(_ name: String, _ id: UUID) -> CategoryInfo {
        CategoryInfo(id: id, name: name, colorKey: "moss", symbolName: "cart", sortOrder: 0)
    }

    private func bars(_ purchases: [PurchaseInfo], _ period: StatsPeriod) -> [PeriodBar] {
        SpendingStats.bars(purchases, period: period, now: now, calendar: calendar)
    }

    @Test func monthsAreGroupedByCategoryAndClippedToTheFirstPurchase() {
        let result = bars([
            PurchaseInfo(cents: 100, date: date(2026, 9, 30), categoryID: groceries),
            PurchaseInfo(cents: 50, date: date(2026, 9, 1), categoryID: groceries),
            PurchaseInfo(cents: 70, date: date(2026, 10, 1), categoryID: eating),
            PurchaseInfo(cents: 30, date: date(2026, 11, 1), categoryID: groceries),
        ], .months)
        #expect(result.map(\.name) == ["September 2026", "October 2026", "November 2026"])
        #expect(result[0].cents[groceries] == 150)
        #expect(result[1].total(focus: eating) == 70)
        #expect(result[1].total(focus: groceries) == 0)
        #expect(result.map(\.isPartial) == [false, false, true])
    }

    @Test func monthsStopAtTwelve() {
        let result = bars([PurchaseInfo(cents: 1, date: date(2020, 1, 1), categoryID: groceries)], .months)
        #expect(result.count == 12)
        #expect(result.first?.name == "December 2025")
        #expect(result.last?.name == "November 2026")
    }

    @Test func noDataGivesTheCurrentPeriodAlone() {
        #expect(bars([], .months).count == 1)
        #expect(bars([], .years).map(\.name) == ["2026 so far"])
    }

    @Test func yearsListEveryYearWithDataPlusTheCurrentOne() {
        let result = bars([
            PurchaseInfo(cents: 100, date: date(2023, 5, 1), categoryID: groceries),
            PurchaseInfo(cents: 200, date: date(2025, 5, 1), categoryID: groceries),
        ], .years)
        #expect(result.map(\.short) == ["2023", "2025", "2026"])
        #expect(result.last?.name == "2026 so far")
    }

    @Test func averageIgnoresThePartialPeriod() {
        let result = bars([
            PurchaseInfo(cents: 100, date: date(2026, 9, 5), categoryID: groceries),
            PurchaseInfo(cents: 300, date: date(2026, 10, 5), categoryID: groceries),
            PurchaseInfo(cents: 50, date: date(2026, 10, 5), categoryID: eating),
            PurchaseInfo(cents: 9_999, date: date(2026, 11, 1), categoryID: groceries),
        ], .months)
        #expect(SpendingStats.average(of: result) == 225)
        #expect(SpendingStats.average(of: result, focus: groceries) == 200)
    }

    @Test func averageCountsAnEmptyCompleteMonth() {
        let result = bars([
            PurchaseInfo(cents: 300, date: date(2026, 8, 5), categoryID: groceries),
            PurchaseInfo(cents: 300, date: date(2026, 10, 5), categoryID: groceries),
        ], .months)
        #expect(SpendingStats.average(of: result) == 200)
    }

    @Test func averageIsNilWithOnlyAPartialPeriod() {
        let result = bars([PurchaseInfo(cents: 100, date: date(2026, 11, 1), categoryID: groceries)], .months)
        #expect(SpendingStats.average(of: result) == nil)
    }

    @Test func defaultBarIsTheLatestCompleteOne() {
        let result = bars([PurchaseInfo(cents: 100, date: date(2026, 9, 5), categoryID: groceries)], .months)
        #expect(SpendingStats.defaultBar(in: result)?.name == "October 2026")
        #expect(SpendingStats.defaultBar(in: bars([], .months))?.name == "November 2026")
    }

    @Test func notesCompareWithTheAverage() {
        let bar = PeriodBar(start: date(2026, 10, 1), end: date(2026, 11, 1), name: "", short: "", isPartial: false, cents: [:])
        func note(_ total: Int, _ average: Int?) -> String {
            SpendingStats.note(for: bar, total: total, average: average, period: .months, money: money, now: now, calendar: calendar)
        }
        #expect(note(112_000, 100_000) == "12% above your average of €1,000")
        #expect(note(88_000, 100_000) == "12% below your average of €1,000")
        #expect(note(101_000, 100_000) == "About your average")
        #expect(note(100, nil) == "")
    }

    @Test func notesForPartialPeriods() {
        var month = PeriodBar(start: date(2026, 11, 1), end: date(2026, 12, 1), name: "", short: "", isPartial: true, cents: [:])
        #expect(SpendingStats.note(for: month, total: 10, average: 114_000, period: .months, money: money, now: now, calendar: calendar)
            == "2 days in · average month is €1,140")
        #expect(SpendingStats.note(for: month, total: 10, average: nil, period: .months, money: money, now: date(2026, 11, 1), calendar: calendar)
            == "1 day in")
        month.start = date(2026, 1, 1)
        let onJuneFirst = date(2026, 6, 1)
        let perMonth = 510_000.0 / (5 + 1.0 / 30)
        #expect(SpendingStats.note(for: month, total: 510_000, average: nil, period: .years, money: money, now: onJuneFirst, calendar: calendar)
            == "January to today · \(money.whole(Int(perMonth.rounded()))) a month")
    }

    @Test func sharesAreOfTheFullTotalAndSorted() {
        let categories = [info("Groceries", groceries), info("Eating out", eating)]
        let result = SpendingStats.shares(in: [groceries: 25, eating: 75], categories: categories)
        #expect(result.map(\.category.name) == ["Eating out", "Groceries"])
        #expect(result.map(\.percent) == [75, 25])
    }

    @Test func noCategoryBucketAppearsOnlyWithSpending() {
        let categories = [info("Groceries", groceries)]
        #expect(SpendingStats.shares(in: [groceries: 25], categories: categories).count == 1)
        let result = SpendingStats.shares(in: [groceries: 25, CategoryInfo.none.id: 25], categories: categories)
        #expect(result.map(\.percent) == [50, 50])
        #expect(result.contains { $0.category.name == "No category" })
    }

    @Test func monthSummaryFooter() {
        let categories = [info("Groceries", groceries)]
        let summary = SpendingStats.monthSummary([
            PurchaseInfo(cents: 128_410, date: date(2026, 10, 5), categoryID: groceries),
            PurchaseInfo(cents: 500, date: date(2026, 11, 1), categoryID: groceries),
        ], categories: categories, money: money, now: now, calendar: calendar)
        #expect(summary.total == 500)
        #expect(summary.monthName == "November")
        #expect(summary.footer == "October closed at €1,284.10 · 2 days into November")
    }

    @Test func monthSummaryWithoutAPreviousMonth() {
        let summary = SpendingStats.monthSummary([], categories: [], money: money, now: now, calendar: calendar)
        #expect(summary.total == 0)
        #expect(summary.footer == "2 days into November")
    }

    @Test func trendsNeedTwoCompleteMonths() {
        let categories = [info("Groceries", groceries)]
        #expect(SpendingStats.trends([], categories: categories, now: now, calendar: calendar) == nil)
        let oneMonth = [PurchaseInfo(cents: 100, date: date(2026, 10, 5), categoryID: groceries)]
        #expect(SpendingStats.trends(oneMonth, categories: categories, now: now, calendar: calendar) == nil)
    }

    @Test func trendsCompareTheLatestCompleteMonthWithTheAverage() throws {
        let categories = [info("Groceries", groceries), info("Eating out", eating)]
        let trends = try #require(SpendingStats.trends([
            PurchaseInfo(cents: 100, date: date(2026, 9, 5), categoryID: groceries),
            PurchaseInfo(cents: 300, date: date(2026, 10, 5), categoryID: groceries),
            PurchaseInfo(cents: 9_000, date: date(2026, 11, 1), categoryID: groceries),
        ], categories: categories, now: now, calendar: calendar))
        #expect(trends.months.count == 2)
        #expect(trends.rows[0].series == [100, 300])
        #expect(trends.rows[0].averageCents == 200)
        #expect(trends.rows[0].change == 50)
        #expect(trends.rows[1].change == nil)
        #expect(trends.footer(calendar: calendar) == "Change compares October with your 2-month average.")
    }

    @Test func trendsCoverAtMostTwelveCompleteMonths() throws {
        let trends = try #require(SpendingStats.trends(
            [PurchaseInfo(cents: 1, date: date(2020, 1, 1), categoryID: groceries)],
            categories: [], now: now, calendar: calendar))
        #expect(trends.months.count == 12)
        #expect(trends.months.last == date(2026, 10, 1))
        #expect(trends.months.first == date(2025, 11, 1))
    }

    @Test func changeText() {
        #expect(SpendingStats.changeText(12) == "+12%")
        #expect(SpendingStats.changeText(-8) == "−8%")
        #expect(SpendingStats.changeText(nil) == "—")
    }

    @Test func dayTitles() {
        #expect(DateText.sectionTitle(now, now: now, calendar: calendar) == "TODAY")
        #expect(DateText.sectionTitle(date(2026, 11, 1), now: now, calendar: calendar) == "YESTERDAY")
        #expect(DateText.sectionTitle(date(2026, 10, 31), now: now, calendar: calendar) == "SATURDAY 31 OCTOBER")
        #expect(DateText.sectionTitle(date(2025, 10, 31), now: now, calendar: calendar) == "FRIDAY 31 OCTOBER 2025")
    }
}
