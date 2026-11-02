import SwiftData
import SwiftUI

@main
struct SpendItForLifeApp: App {
    @State private var settings = AppSettings()
    @State private var router = AppRouter()
    private let container = Self.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(router)
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }

    /// The SwiftData store, synced to the user's private iCloud database.
    static func makeContainer() -> ModelContainer {
        #if DEBUG
        if DemoData.isEnabled { return DemoData.makeContainer() }
        // The unit tests host in the app and make their own stores.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return DemoData.inMemoryContainer()
        }
        #endif
        let schema = Schema([Category.self, Purchase.self])
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.joakimkronqvist.sifl")
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create the model container: \(error)")
        }
    }
}
