import SwiftData
import SwiftUI

/// Tab 2: spending over time, by category, and category trends.
struct InsightsView: View {
    @Environment(AppSettings.self) private var settings
    @Query private var purchases: [Purchase]
    @Query(sort: [SortDescriptor(\Category.sortOrder), SortDescriptor(\Category.createdAt)])
    private var categories: [Category]

    @State private var period = StatsPeriod.months
    @State private var selectedMonth: Date?
    @State private var selectedYear: Date?
    /// The category shown alone on the chart. Kept when the period or bar changes.
    @State private var focus: UUID?

    var body: some View {
        // Read once per update: everything below comes from these.
        let infos = purchases.map(\.info)
        let categoryInfos = categories.map(\.info)
        let bars = SpendingStats.bars(infos, period: period)
        let bar = selectedBar(in: bars)
        let activeFocus = validFocus(categoryInfos)

        TabScreen {
            ScreenHeader(subtitle: subtitle(infos), title: "Insights")
            SegmentedControl(options: [(StatsPeriod.months, "Months"), (StatsPeriod.years, "Years")], selection: $period)
            if let bar {
                let shares = SpendingStats.shares(in: bar.cents, categories: categoryInfos)
                OverTimeCard(
                    bars: bars,
                    selected: bar,
                    period: period,
                    focus: activeFocus,
                    focusName: focusName(activeFocus, shares),
                    categories: categoryInfos + [.none],
                    money: settings.money
                ) { select($0) }
                CategoryBreakdownCard(bar: bar, shares: shares, focus: activeFocus, money: settings.money) { id in
                    withAnimation(.snappy) { focus = focus == id ? nil : id }
                } onReset: {
                    withAnimation(.snappy) { focus = nil }
                }
                StatTiles(bars: bars, bar: bar, period: period, shares: shares, focus: activeFocus,
                          purchases: purchases.filter { bar.contains($0.date) }, money: settings.money)
            }
            if let trends = SpendingStats.trends(infos, categories: categoryInfos) {
                TrendsCard(trends: trends, money: settings.money)
            }
        }
        #if DEBUG
        // `-debugPeriod years`, `-debugFocus Groceries`, for screenshots.
        .onAppear {
            if UserDefaults.standard.string(forKey: "debugPeriod") == "years" { period = .years }
            if let name = UserDefaults.standard.string(forKey: "debugFocus") {
                focus = categoryInfos.first { $0.name == name }?.id
            }
        }
        #endif
    }

    private func selectedBar(in bars: [PeriodBar]) -> PeriodBar? {
        let id = period == .months ? selectedMonth : selectedYear
        return bars.first { $0.id == id } ?? SpendingStats.defaultBar(in: bars)
    }

    private func select(_ bar: PeriodBar) {
        withAnimation(.snappy(duration: 0.2)) {
            if period == .months {
                selectedMonth = bar.id
            } else {
                selectedYear = bar.id
            }
        }
    }

    /// A focused category may have been deleted, or be the no-category bucket
    /// which has since emptied.
    private func validFocus(_ infos: [CategoryInfo]) -> UUID? {
        guard let focus else { return nil }
        return infos.contains { $0.id == focus } || focus == CategoryInfo.none.id ? focus : nil
    }

    private func focusName(_ focus: UUID?, _ shares: [CategoryShare]) -> String? {
        guard let focus else { return nil }
        return shares.first { $0.id == focus }?.category.name
            ?? categories.first { $0.id == focus }?.name
            ?? CategoryInfo.none.name
    }

    /// "6 categories · tracking since Jan 2023".
    private func subtitle(_ infos: [PurchaseInfo]) -> String {
        let count = categories.count == 1 ? "1 category" : "\(categories.count) categories"
        guard let first = infos.map(\.date).min() else { return count }
        return "\(count) · tracking since \(DateText.shortMonthYear(first))"
    }
}

#Preview {
    NavigationStack { InsightsView() }
        .environment(AppSettings())
        .modelContainer(DemoData.previewContainer())
        .preferredColorScheme(.dark)
}
