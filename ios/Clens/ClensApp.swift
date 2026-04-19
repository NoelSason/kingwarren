import SwiftUI

@main
struct ClensApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var ocean = OceanStressService()
    @StateObject private var coordinator: ScanCoordinator

    init() {
        let ocean = OceanStressService()
        _ocean = StateObject(wrappedValue: ocean)
        _coordinator = StateObject(wrappedValue: ScanCoordinator(ocean: ocean))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(router)
                .environmentObject(ocean)
                .environmentObject(coordinator)
                .preferredColorScheme(.light)
        }
    }
}
