import SwiftData
import SwiftUI

/// Tab 1: this month's total and the purchases by day. Older months load as
/// the list reaches its end.
struct SpendingView: View {
    private static let monthsPerPage = 3

    @State private var monthsLoaded = SpendingView.monthsPerPage

    /// Whole months back from the current one. Always covers last month, for
    /// the month card's footer.
    private var cutoff: Date {
        let calendar = Calendar.current
        let thisMonth = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        return calendar.date(byAdding: .month, value: -(monthsLoaded - 1), to: thisMonth) ?? thisMonth
    }

    var body: some View {
        SpendingList(cutoff: cutoff) {
            monthsLoaded += Self.monthsPerPage
        }
    }
}

private struct SpendingList: View {
    let cutoff: Date
    var onLoadMore: () -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query private var purchases: [Purchase]
    @Query(sort: [SortDescriptor(\Category.sortOrder), SortDescriptor(\Category.createdAt)])
    private var categories: [Category]

    @State private var editing: Purchase?

    init(cutoff: Date, onLoadMore: @escaping () -> Void) {
        self.cutoff = cutoff
        self.onLoadMore = onLoadMore
        _purchases = Query(filter: #Predicate<Purchase> { $0.date >= cutoff },
                           sort: [SortDescriptor(\.date, order: .reverse), SortDescriptor(\.createdAt, order: .reverse)])
    }

    private var money: MoneyFormat { settings.money }

    /// Purchases by day, newest first. The query's order is kept inside a day.
    private var days: [(day: Date, purchases: [Purchase])] {
        let calendar = Calendar.current
        var result: [(day: Date, purchases: [Purchase])] = []
        for purchase in purchases {
            let day = calendar.startOfDay(for: purchase.date)
            if result.last?.day == day {
                result[result.count - 1].purchases.append(purchase)
            } else {
                result.append((day, [purchase]))
            }
        }
        return result
    }

    var body: some View {
        List {
            Section {
                MonthCard(summary: SpendingStats.monthSummary(purchases.map(\.info),
                                                              categories: categories.map(\.info), money: money),
                          isEmpty: purchases.isEmpty, money: money) {
                    router.tab = .insights
                }
                .plainListRow()
            } header: {
                // A header, as a row's rounded corners would clip the text.
                ScreenHeader(subtitle: DateText.fullDay(.now), title: "Spending")
                    .textCase(nil)
                    .listRowInsets(.init())
                    .padding(.bottom, 8)
            }

            ForEach(days, id: \.day) { group in
                Section {
                    ForEach(group.purchases) { purchase in
                        PurchaseRow(purchase: purchase, money: money) { editing = purchase }
                            .cardListRow()
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Delete", role: .destructive) {
                                    PurchaseActions.delete(purchase, money: money, router: router, in: modelContext)
                                }
                            }
                            .onAppear {
                                if purchase.id == purchases.last?.id { loadMoreIfNeeded() }
                            }
                    }
                } header: {
                    AdaptiveStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(DateText.sectionTitle(group.day))
                            .font(.label)
                            .tracking(0.3)
                        Spacer(minLength: 0)
                        Text(money.format(group.purchases.reduce(0) { $0 + $1.amountCents }))
                            .font(.footnote.weight(.semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.textSecondary)
                    .textCase(nil)
                    .listRowInsets(.init(top: 8, leading: 4, bottom: 6, trailing: 4))
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .listScreen()
        .sheet(item: $editing) { purchase in
            AddPurchaseSheet(mode: .edit(purchase))
        }
    }

    private func loadMoreIfNeeded() {
        let cutoff = cutoff
        let older = FetchDescriptor<Purchase>(predicate: #Predicate { $0.date < cutoff })
        if ((try? modelContext.fetchCount(older)) ?? 0) > 0 { onLoadMore() }
    }
}

// MARK: - Month card

private struct MonthCard: View {
    var summary: MonthSummary
    var isEmpty: Bool
    var money: MoneyFormat
    var onInsights: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AdaptiveStack(alignment: .firstTextBaseline) {
                Text("\(summary.monthName.uppercased()) SO FAR")
                    .font(.label)
                    .tracking(0.3)
                    .foregroundStyle(.textSecondary)
                Spacer(minLength: 0)
                Button("Insights", action: onInsights)
                    .font(.rowDetail)
                    .foregroundStyle(.dataBlue)
                    .buttonStyle(.plain)
            }
            HeroFigure(money.format(summary.total))
            if summary.total > 0 {
                SplitBar(shares: summary.shares, height: 8)
                    .accessibilityLabel("\(summary.monthName) by category")
                    .accessibilityValue(summary.shares.map { "\($0.category.name) \(money.format($0.cents))" }.joined(separator: ", "))
                FlowLayout(spacing: 4) {
                    ForEach(summary.shares) { share in
                        HStack(spacing: 6) {
                            Circle().fill(share.category.color).frame(width: 8, height: 8)
                            Text(share.category.name)
                                .foregroundStyle(.textSecondary)
                            Text(money.format(share.cents))
                                .foregroundStyle(.textPrimary)
                                .monospacedDigit()
                        }
                        .font(.footnote)
                        .padding(.trailing, 10)
                    }
                }
                .accessibilityHidden(true)
                RowDivider()
                Text(summary.footer)
                    .font(.rowDetail)
                    .foregroundStyle(.textSecondary)
            } else if isEmpty {
                Text("Nothing logged yet. Tap + to add your first purchase.")
                    .font(.rowDetail)
                    .foregroundStyle(.textSecondary)
            } else {
                Text(summary.footer)
                    .font(.rowDetail)
                    .foregroundStyle(.textSecondary)
            }
        }
        .card()
    }
}

/// A horizontal bar split by category colour.
struct SplitBar: View {
    var shares: [CategoryShare]
    var height: CGFloat
    /// When set, the other categories dim.
    var focus: UUID?

    var body: some View {
        GeometryReader { proxy in
            let visible = shares.filter { $0.cents > 0 }
            let total = visible.reduce(0) { $0 + $1.cents }
            let gaps = CGFloat(max(visible.count - 1, 0)) * 2
            HStack(spacing: 2) {
                ForEach(visible) { share in
                    Rectangle()
                        .fill(share.category.color)
                        .opacity(focus == nil || focus == share.id ? 1 : 0.4)
                        .frame(width: max((proxy.size.width - gaps) * CGFloat(share.cents) / CGFloat(max(total, 1)), 0))
                }
            }
        }
        .frame(height: height)
        .background(.surfaceRaised)
        .clipShape(.capsule)
        .accessibilityElement()
    }
}

// MARK: - Row

private struct PurchaseRow: View {
    let purchase: Purchase
    var money: MoneyFormat
    var onTap: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let category = purchase.categoryInfo
        Button(action: onTap) {
            HStack(alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center, spacing: 12) {
                CategoryTile(symbol: category.symbolName, color: category.color)
                AdaptiveStack(spacing: 2) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(purchase.displayTitle)
                            .font(.rowTitle)
                            .foregroundStyle(.textPrimary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        Text(purchase.title == nil ? "No title" : category.name)
                            .font(.rowDetail)
                            .foregroundStyle(.textSecondary)
                    }
                    Spacer(minLength: 8)
                    Text(money.format(purchase.amountCents))
                        .font(.number(.body))
                        .foregroundStyle(.textPrimary)
                }
            }
            .frame(minHeight: 48)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText(category))
        .accessibilityHint("Edits this purchase")
    }

    private func accessibilityText(_ category: CategoryInfo) -> String {
        var parts = [purchase.displayTitle]
        if purchase.title != nil { parts.append(category.name) }
        parts.append(money.format(purchase.amountCents))
        parts.append(DateText.spoken(purchase.date))
        return parts.joined(separator: ", ")
    }
}

#Preview {
    NavigationStack { SpendingView() }
        .environment(AppSettings())
        .environment(AppRouter())
        .modelContainer(DemoData.previewContainer())
        .preferredColorScheme(.dark)
}
