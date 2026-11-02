import Accessibility
import Charts
import SwiftUI

/// The period's total and the stacked bar chart.
struct OverTimeCard: View {
    var bars: [PeriodBar]
    var selected: PeriodBar
    var period: StatsPeriod
    var focus: UUID?
    var focusName: String?
    /// Stacking order, with the no-category bucket last.
    var categories: [CategoryInfo]
    var money: MoneyFormat
    var onSelect: (PeriodBar) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var total: Int { selected.total(focus: focus) }
    private var average: Int? { SpendingStats.average(of: bars, focus: focus) }

    private var caption: String {
        var text = selected.name.uppercased()
        if let focusName { text += " · \(focusName.uppercased())" }
        return text
    }

    private var note: String {
        SpendingStats.note(for: selected, total: total, average: average, period: period, money: money)
    }

    private var hint: String {
        if let focusName {
            return "Showing \(focusName) only. Tap it again or Show all to bring back the rest."
        }
        return "Tap a bar to see its breakdown. Tap a category below to show it alone."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(caption)
                    .font(.label)
                    .tracking(0.3)
                    .foregroundStyle(.textSecondary)
                HeroFigure(money.format(total))
                if !note.isEmpty {
                    Text(note)
                        .font(.rowDetail)
                        .foregroundStyle(.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)

            chart
                .frame(height: 180)

            Text(hint)
                .font(.footnote)
                .foregroundStyle(.textSecondary)
        }
        .card()
    }

    private var visibleCategories: [CategoryInfo] {
        guard let focus else { return categories }
        return categories.filter { $0.id == focus }
    }

    private var chart: some View {
        Chart {
            ForEach(bars) { bar in
                ForEach(visibleCategories) { category in
                    if let cents = bar.cents[category.id], cents > 0 {
                        BarMark(
                            x: .value("Period", bar.name),
                            y: .value("Amount", Double(cents) / 100),
                            width: bars.count <= 4 ? .fixed(44) : .automatic
                        )
                        .foregroundStyle(category.color)
                        .cornerRadius(2)
                        .opacity(bar.id == selected.id ? 1 : 0.42)
                    }
                }
            }
            if let average, average > 0 {
                RuleMark(y: .value("Average", Double(average) / 100))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.white.opacity(0.32))
                    .annotation(position: .top, alignment: .trailing, spacing: 2) {
                        Text("avg \(money.whole(average))")
                            .font(.label.weight(.semibold))
                            .foregroundStyle(.textSecondary)
                            .padding(.leading, 4)
                            .background(.surface)
                    }
            }
        }
        .chartLegend(.hidden)
        .chartYAxis(.hidden)
        .chartXScale(domain: bars.map(\.name))
        .chartXAxis {
            AxisMarks(values: bars.map(\.name)) { value in
                if let name = value.as(String.self), let bar = bars.first(where: { $0.name == name }) {
                    AxisValueLabel(centered: true, collisionResolution: .disabled) {
                        Text(bar.short)
                            .font(.caption.weight(bar.id == selected.id ? .bold : .medium))
                            .foregroundStyle(bar.id == selected.id ? .textPrimary : .textSecondary)
                    }
                }
            }
        }
        // A tap gesture rather than `chartXSelection`, which inside a scroll
        // view only responds to a long press.
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(.rect)
                    .onTapGesture { location in
                        guard let plotFrame = proxy.plotFrame,
                              let name: String = proxy.value(atX: location.x - geometry[plotFrame].minX),
                              let bar = bars.first(where: { $0.name == name }) else { return }
                        onSelect(bar)
                    }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: focus)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: period)
        .accessibilityChartDescriptor(ChartDescriptor(bars: bars, focus: focus, money: money))
        .accessibilityRepresentation {
            VStack {
                ForEach(bars) { bar in
                    Button("\(bar.name), \(money.format(bar.total(focus: focus)))") { onSelect(bar) }
                        .accessibilityAddTraits(bar.id == selected.id ? .isSelected : [])
                }
            }
        }
    }
}

/// Lets VoiceOver users explore the bars as an audio graph.
private struct ChartDescriptor: AXChartDescriptorRepresentable {
    var bars: [PeriodBar]
    var focus: UUID?
    var money: MoneyFormat

    func makeChartDescriptor() -> AXChartDescriptor {
        let values = bars.map { Double($0.total(focus: focus)) / 100 }
        let money = money
        let xAxis = AXCategoricalDataAxisDescriptor(title: "Period", categoryOrder: bars.map(\.name))
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Spending",
            range: 0...max(values.max() ?? 0, 1),
            gridlinePositions: []
        ) { money.whole(Int($0 * 100)) }
        let series = AXDataSeriesDescriptor(
            name: "Spending",
            isContinuous: false,
            dataPoints: bars.map {
                AXDataPoint(x: $0.name, y: Double($0.total(focus: focus)) / 100,
                            label: "\($0.name), \(money.format($0.total(focus: focus)))")
            }
        )
        return AXChartDescriptor(title: "Spending over time", summary: nil, xAxis: xAxis, yAxis: yAxis,
                                 additionalAxes: [], series: [series])
    }
}
