import SwiftData
import SwiftUI

/// The three tabs, the floating tab bar with its add button, and onboarding.
struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var categories: [Category]

    @State private var showOnboarding = false
    @State private var showAddPurchase = false

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            Tab("Spending", systemImage: "creditcard", value: AppRouter.TabID.spending) {
                NavigationStack { SpendingView() }
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab("Insights", systemImage: "chart.bar", value: AppRouter.TabID.insights) {
                NavigationStack { InsightsView() }
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab("Settings", systemImage: "gearshape", value: AppRouter.TabID.settings) {
                NavigationStack { SettingsView() }
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
        }
        .tint(.accentGold)
        // Over the content, which leaves room with `tabBarClearance`.
        .overlay(alignment: .bottom) {
            if !router.isCurrencyPickerOpen {
                FloatingTabBar(selection: $router.tab) { showAddPurchase = true }
                    .transition(.opacity)
            }
        }
        .ignoresSafeArea(.keyboard)
        .overlay(alignment: .bottom) {
            ToastView(toast: $router.toast)
                .padding(.bottom, router.isCurrencyPickerOpen ? 16 : 100)
        }
        .sheet(isPresented: $showAddPurchase) {
            AddPurchaseSheet(mode: .new)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .onAppear {
            applyLaunchArguments()
            evaluateOnboarding()
            Category.mergeDuplicates(in: modelContext)
        }
        .onChange(of: categories.count) {
            evaluateOnboarding()
            Category.mergeDuplicates(in: modelContext)
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            Category.mergeDuplicates(in: modelContext)
        }
        .onChange(of: settings.hasCompletedOnboarding) {
            if settings.hasCompletedOnboarding { showOnboarding = false }
        }
    }

    /// Shows onboarding on a first launch. Categories that arrive from iCloud
    /// count as having done it. Onboarding holds its categories back until it
    /// finishes, so any here came from sync.
    private func evaluateOnboarding() {
        if !categories.isEmpty, !settings.hasCompletedOnboarding {
            settings.hasCompletedOnboarding = true
        }
        showOnboarding = OnboardingGate.isNeeded(hasCompleted: settings.hasCompletedOnboarding,
                                                 categoryCount: categories.count)
    }

    private func applyLaunchArguments() {
        #if DEBUG
        // `-initialTab insights`, `-openAddPurchase YES`, for screenshots.
        if let raw = UserDefaults.standard.string(forKey: "initialTab"), let tab = AppRouter.TabID(rawValue: raw) {
            router.tab = tab
        }
        if UserDefaults.standard.bool(forKey: "openAddPurchase") { showAddPurchase = true }
        #endif
    }
}

// MARK: - Tab bar

/// The design's floating glass tab bar with the brass add button beside it.
private struct FloatingTabBar: View {
    @Binding var selection: AppRouter.TabID
    var onAdd: () -> Void

    private let tabs: [(id: AppRouter.TabID, title: String, symbol: String)] = [
        (.spending, "Spending", "creditcard"),
        (.insights, "Insights", "chart.bar"),
        (.settings, "Settings", "gearshape")
    ]

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(tabs, id: \.id) { tab in
                    tabButton(tab)
                }
            }
            .padding(4)
            .frame(height: 64)
            .patinaGlass(in: Capsule())
            .dynamicTypeSize(...DynamicTypeSize.xLarge)

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.onAccent)
                    .frame(width: 64, height: 64)
                    .background(.accentGold, in: .circle)
                    .overlay { Circle().strokeBorder(.white.opacity(0.24), lineWidth: 1) }
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
            .accessibilityLabel("Add purchase")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(alignment: .bottom) {
            LinearGradient(colors: [Color(hex: 0x09090B, opacity: 0.95), Color(hex: 0x09090B, opacity: 0)],
                           startPoint: .bottom, endPoint: .top)
                .frame(height: 140)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private func tabButton(_ tab: (id: AppRouter.TabID, title: String, symbol: String)) -> some View {
        let isOn = selection == tab.id
        return Button {
            selection = tab.id
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isOn ? .accentGold : .textPrimary)
                    .frame(height: 24)
                Text(tab.title)
                    .font(.label)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isOn ? AnyShapeStyle(.fillSelected) : AnyShapeStyle(.clear), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Toast

private struct ToastView: View {
    @Binding var toast: Toast?

    var body: some View {
        ZStack {
            if let toast {
                HStack(spacing: 12) {
                    Text(toast.message)
                        .font(.rowDetail)
                        .foregroundStyle(.textPrimary)
                        .monospacedDigit()
                    Spacer(minLength: 0)
                    if let undo = toast.undo {
                        Button("Undo") {
                            undo()
                            self.toast = nil
                        }
                        .font(.rowDetail.weight(.semibold))
                        .foregroundStyle(.dataBlue)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .patinaGlass(in: RoundedRectangle(cornerRadius: Radius.card))
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityElement(children: .contain)
                .task(id: toast.id) {
                    AccessibilityNotification.Announcement(toast.message).post()
                    try? await Task.sleep(for: .seconds(toast.undo == nil ? 3 : 6))
                    guard !Task.isCancelled else { return }
                    self.toast = nil
                }
            }
        }
        .animation(.snappy, value: toast?.id)
    }
}

#Preview {
    RootView()
        .environment(AppSettings())
        .environment(AppRouter())
        .modelContainer(DemoData.previewContainer())
        .preferredColorScheme(.dark)
}
