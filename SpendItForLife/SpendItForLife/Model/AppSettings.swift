import Foundation
import Observation

/// User settings. The currency syncs through the iCloud key-value store and is
/// mirrored locally for fast reads; the onboarding flag stays on this device.
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let currencyCode = "currencyCode"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    var currencyCode: String {
        didSet {
            guard !isApplyingDebugOverrides, currencyCode != oldValue else { return }
            local.set(currencyCode, forKey: Key.currencyCode)
            store.set(currencyCode, forKey: Key.currencyCode)
        }
    }

    var hasCompletedOnboarding: Bool {
        didSet {
            guard !isApplyingDebugOverrides else { return }
            #if DEBUG
            // Demo data is in memory only, so it shouldn't count as onboarded.
            if DemoData.isEnabled { return }
            #endif
            local.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding)
        }
    }

    /// Formats amounts in the chosen currency.
    var money: MoneyFormat { MoneyFormat(code: currencyCode) }

    private let store: NSUbiquitousKeyValueStore
    private let local: UserDefaults
    @ObservationIgnored private var observer: NSObjectProtocol?
    /// While true, changes aren't written to storage (debug launch overrides).
    @ObservationIgnored private var isApplyingDebugOverrides = false

    init(store: NSUbiquitousKeyValueStore = .default, local: UserDefaults = .standard) {
        self.store = store
        self.local = local
        store.synchronize()
        currencyCode = store.string(forKey: Key.currencyCode)
            ?? local.string(forKey: Key.currencyCode)
            ?? Money.regionCurrencyCode()
        hasCompletedOnboarding = local.bool(forKey: Key.hasCompletedOnboarding)
        #if DEBUG
        // Launch arguments for screenshots. They change what this run shows,
        // never what's stored: `-debugCurrency USD`.
        isApplyingDebugOverrides = true
        if let override = UserDefaults.standard.string(forKey: "debugCurrency") {
            currencyCode = override
        }
        isApplyingDebugOverrides = false
        #endif

        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    /// Picks up a currency changed on another device.
    private func reload() {
        guard let synced = store.string(forKey: Key.currencyCode), synced != currencyCode else { return }
        currencyCode = synced
    }
}

/// Whether the first-launch flow is needed. A reinstall or second device that
/// already has categories from iCloud skips it.
nonisolated enum OnboardingGate {
    static func isNeeded(hasCompleted: Bool, categoryCount: Int) -> Bool {
        !hasCompleted && categoryCount == 0
    }
}
