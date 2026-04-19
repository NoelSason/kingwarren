import SwiftUI

@main
struct ClensApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var ocean = OceanStressService()
    @StateObject private var coordinator: ScanCoordinator
    @StateObject private var history = ScanHistoryStore()
    @StateObject private var profileService = ProfileService()
    @AppStorage("clens.darkMode") private var darkMode: Bool = false

    init() {
        let ocean = OceanStressService()
        _ocean = StateObject(wrappedValue: ocean)
        let hist = ScanHistoryStore()
        _history = StateObject(wrappedValue: hist)
        _coordinator = StateObject(wrappedValue: ScanCoordinator(ocean: ocean, history: hist))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(router)
                .environmentObject(ocean)
                .environmentObject(coordinator)
                .environmentObject(history)
                .environmentObject(profileService)
                .preferredColorScheme(darkMode ? .dark : .light)
                .task(id: router.session?.userID) {
                    guard let session = router.session else { return }
                    // Load profile from Databricks
                    await profileService.load(userID: session.userID)
                    // Wire and refresh ocean stress from Flask
                    ocean.remoteURL = URL(string: "http://127.0.0.1:5000/api/ocean-stress")
                    await ocean.refreshFromRemoteIfAvailable()
                }
        }
    }
}
