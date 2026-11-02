import Charts
import SwiftUI

// MARK: - By category

/// The selected period's categories. Tapping one shows it alone on the chart.
struct CategoryBreakdownCard: View {
    var bar: PeriodBar
    var shares: [CategoryShare]
    var focus: UUID?
    var money: MoneyFormat
    var onToggle: (UUID) -> Void
    var onReset: () -> Void

    private var focusName: String? {
        shares.first { $0.id == focus }?.category.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AdaptiveStack {
                Text("BY CATEGORY · \(bar.name.uppercased())")
                    .font(.label)
                    .tracking(0.3)
                    .foregroundStyle(.textSecondary)
                Spacer(minLength: 8)
                if focus != nil {
                    Button(action: onReset) {
                        Label("Show all", systemImage: "arrow.uturn.backward")
                            .font(.rowDetail.weight(.semibold))
                            .foregroundStyle(.textPrimary)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .patinaGlass(in: Capsule())
                }
            }
            .frame(minHeight: 32)

            SplitBar(shares: shares, height: 12, focus: focus)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                ForEach(Array(shares.enumerated()), id: \.element.id) { index, share in
                    if index > 0 { RowDivider() }
                    row(share)
                }
            }

            Text(focusName.map { "\($0) is shown alone on the chart." } ?? "Tap a category to show only it on the chart.")
                .font(.footnote)
                .foregroundStyle(.textSecondary)
        }
        .card()
    }

    private func row(_ share: CategoryShare) -> some View {
        let isOn = focus == share.id
        return Button {
            onToggle(share.id)
        } label: {
            HStack(spacing: 12) {
                CategoryTile(symbol: share.category.symbolName, color: share.category.color,
                             size: 36, cornerRadius: Radius.thumb)
                VStack(spacing: 4) {
                    AdaptiveStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(share.category.name)
                            .font(.rowTitle)
                            .foregroundStyle(.textPrimary)
                        Spacer(minLength: 0)
                        Text(money.format(share.cents))
                            .font(.number(.body))
                            .foregroundStyle(.textPrimary)
                    }
                    HStack(spacing: 8) {
                        ProgressBar(fraction: Double(share.percent) / 100, color: share.category.color)
                        Text("\(share.percent)%")
                            .font(.footnote)
                            .foregroundStyle(.textSecondary)
                            .monospacedDigit()
                            .frame(minWidth: 36, alignment: .trailing)
                    }
                }
            }
            .padding(.vertical, 8)
            .frame(minHeight: 52)
            .contentShape(.rect)
            .opacity(focus == nil || isOn ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(share.category.name), \(money.format(share.cents)), \(share.percent) percent")
        .accessibilityHint(isOn ? "Shows all categories on the chart" : "Shows only this category on the chart")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

private struct ProgressBar: View {
    var fraction: Double
    var color: Color

    var body: some View {
        Capsule()
            .fill(.surfaceRaised)
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * min(max(fraction, 0), 1))
                }
            }
    }
}

// MARK: - Stat tiles

/// Average, top category, purchase count and the biggest purchase.
struct StatTiles: View {
    var bars: [PeriodBar]
    var bar: PeriodBar
    var period: StatsPeriod
    var shares: [CategoryShare]
    var focus: UUID?
    /// The purchases in `bar`.
    var purchases: [Purchase]
    var money: MoneyFormat

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    private var periodWord: String { period == .months ? "month" : "year" }

    /// The short period name: "October", "2026 so far".
    private var shortName: String {
        period == .months ? DateText.month(bar.start) : bar.name
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            StatTile(label: "AVERAGE \(periodWord.uppercased())", value: averageValue, note: averageNote)
            StatTile(label: "TOP CATEGORY", value: top?.category.name ?? "—",
                     note: top.map { "\($0.percent)% of the \(periodWord)" } ?? "Nothing logged")
            StatTile(label: "PURCHASES", value: purchases.count.formatted(), note: "In \(shortName)")
            StatTile(label: "BIGGEST ONE", value: biggest.map { money.format($0.amountCents) } ?? "—",
                     note: biggest.map { "\($0.categoryInfo.name) · \(DateText.shortDay($0.date))" } ?? "Nothing logged")
        }
    }

    private var top: CategoryShare? {
        shares.first { $0.cents > 0 }
    }

    private var biggest: Purchase? {
        purchases.max { $0.amountCents < $1.amountCents }
    }

    private var complete: [PeriodBar] {
        bars.filter { !$0.isPartial }
    }

    private var averageValue: String {
        SpendingStats.average(of: bars, focus: focus).map(money.whole) ?? "—"
    }

    private var averageNote: String {
        guard let first = complete.first, let last = complete.last else {
            return "Needs a full \(periodWord)"
        }
        if period == .years {
            return complete.count == 1 ? first.name : "\(first.name) to \(last.name)"
        }
        return complete.count == 1 ? "Last full month" : "Last \(complete.count) full months"
    }
}

private struct StatTile: View {
    var label: String
    var value: String
    var note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.label)
                .tracking(0.3)
                .foregroundStyle(.textSecondary)
            Text(value)
                .font(.number(.title2))
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(note)
                .font(.footnote)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .card(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Trends

/// Each category over the last 12 complete months.
struct TrendsCard: View {
    var trends: TrendSummary
    var money: MoneyFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CATEGORY TRENDS · LAST \(trends.months.count) MONTHS")
                .font(.label)
                .tracking(0.3)
                .foregroundStyle(.textSecondary)
            VStack(spacing: 0) {
                ForEach(Array(trends.rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 { RowDivider() }
                    TrendRow(row: row, months: trends.months, money: money)
                }
            }
            Text(trends.footer())
                .font(.footnote)
                .foregroundStyle(.textSecondary)
        }
        .card()
    }
}

private struct TrendRow: View {
    var row: CategoryTrend
    var months: [Date]
    var money: MoneyFormat

    var body: some View {
        AdaptiveStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.category.name)
                    .font(.rowDetail.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                Text("\(money.whole(row.averageCents)) / mo")
                    .font(.footnote)
                    .foregroundStyle(.textSecondary)
                    .monospacedDigit()
            }
            .frame(minWidth: 104, alignment: .leading)

            Chart(Array(zip(months, row.series)), id: \.0) { month, cents in
                LineMark(x: .value("Month", month), y: .value("Amount", cents))
                    .foregroundStyle(row.category.color)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .frame(height: 32)

            Text(SpendingStats.changeText(row.change))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.textSecondary)
                .monospacedDigit()
                .frame(minWidth: 40, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .frame(minHeight: 52)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.category.name), \(money.whole(row.averageCents)) a month on average, \(SpendingStats.changeText(row.change)) latest month")
    }
}
