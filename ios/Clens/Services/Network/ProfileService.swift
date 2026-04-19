import Foundation

@MainActor
final class ProfileService: ObservableObject {
    @Published private(set) var profile: DatabricksProfile?
    @Published private(set) var isLoading = false

    func load(userID: String) async {
        isLoading = true
        defer { isLoading = false }
        profile = try? await APIClient.shared.fetchProfile(userID: userID)
    }
}
