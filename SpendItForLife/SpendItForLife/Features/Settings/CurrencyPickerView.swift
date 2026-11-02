import SwiftUI

/// All currencies, with the region's first. Pushed from Settings, and shown in
/// a sheet from onboarding.
struct CurrencyPickerView: View {
    var selection: String
    var onPick: (String) -> Void

    @State private var query = ""
    @State private var current = ""

    private struct Option: Identifiable {
        var code: String
        var name: String
        var id: String { code }
    }

    private static func makeOptions() -> [Option] {
        Locale.commonISOCurrencyCodes
            .compactMap { code in
                Locale.current.localizedString(forCurrencyCode: code).map { Option(code: code, name: $0) }
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    @State private var options: [Option] = Self.makeOptions()

    private var regionCode: String { Money.regionCurrencyCode() }

    private var filtered: [Option] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return options.filter { $0.code != regionCode } }
        return options.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) || $0.code.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                SearchField(prompt: "Search currencies", text: $query)

                if query.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        if let region = Money.regionName() {
                            SectionLabel("From your region · \(region)")
                        }
                        regionRow.card(padding: nil)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("All currencies")
                    if filtered.isEmpty {
                        Text("No currency matches.")
                            .font(.rowDetail)
                            .foregroundStyle(.textSecondary)
                            .padding(.horizontal, 4)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, option in
                                if index > 0 { RowDivider() }
                                row(option)
                            }
                        }
                        .card(padding: nil)
                    }
                    Text("Changing currency changes the symbol only. Amounts you logged are not converted.")
                        .font(.footnote)
                        .foregroundStyle(.textSecondary)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(.appBackground)
        .navigationTitle("Currency")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { current = selection }
    }

    private var regionRow: some View {
        let code = regionCode
        return Button { pick(code) } label: {
            HStack(spacing: 12) {
                symbolTile(code)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Money.currencyName(code))
                        .font(.body)
                        .foregroundStyle(.textPrimary)
                    Text("\(code) · \(MoneyFormat(code: code).format(123_450))")
                        .font(.rowDetail)
                        .foregroundStyle(.textSecondary)
                }
                Spacer(minLength: 8)
                checkmark(code)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 60)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(code == current ? .isSelected : [])
    }

    private func row(_ option: Option) -> some View {
        Button { pick(option.code) } label: {
            HStack(spacing: 12) {
                symbolTile(option.code)
                Text(option.name)
                    .font(.body)
                    .foregroundStyle(.textPrimary)
                Spacer(minLength: 8)
                Text(option.code)
                    .font(.rowDetail)
                    .foregroundStyle(.textSecondary)
                checkmark(option.code)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 56)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(option.code == current ? .isSelected : [])
    }

    private func symbolTile(_ code: String) -> some View {
        Text(Money.symbol(code))
            .font(.system(size: 13, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(.textPrimary)
            .padding(.horizontal, 2)
            .frame(width: 36, height: 36)
            .background(.surfaceRaised, in: .rect(cornerRadius: Radius.thumb))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func checkmark(_ code: String) -> some View {
        if code == current {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.dataBlue)
                .accessibilityHidden(true)
        }
    }

    private func pick(_ code: String) {
        current = code
        onPick(code)
    }
}

#Preview {
    NavigationStack { CurrencyPickerView(selection: "EUR") { _ in } }
        .preferredColorScheme(.dark)
}
