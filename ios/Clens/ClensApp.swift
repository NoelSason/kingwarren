import SwiftUI

@main
struct ClensApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var ocean = OceanStressService()
    @StateObject private var coordinator: ScanCoordinator
    @StateObject private var history = ScanHistoryStore()
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
                .preferredColorScheme(darkMode ? .dark : .light)
        }
    }
}
