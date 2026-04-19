import Foundation
import Combine

// Provides the current ocean stress index to the scoring engine.
//
// Sean's pipeline (project_oceanscore.py, CELL 4) produces a scalar in
// [0, 2] where 1.0 = normal. The app reads it from here; when Sean ships
// the backend we flip `source` to .remote and point `remoteURL` at the
// published JSON. Until then we use the Mock value so the UI stays
// consistent with the demo copy ("Stress index 1.34×").
@MainActor
final class OceanStressService: ObservableObject {
    enum Source { case mock, remote }

    @Published private(set) var stressIndex: Double
    @Published private(set) var source: Source = .mock
    @Published private(set) var updatedAt: Date = .now
    @Published private(set) var location: String = "CCE2 mooring · San Diego shelf"

    // Flip to .remote and set remoteURL once Sean publishes a JSON endpoint
    // with shape: {"stress_index": 1.34, "updated_at": "...", "location": "..."}.
    var remoteURL: URL? = nil

    init(initial: Double = Mock.oceanToday.stressIndex) {
        self.stressIndex = initial
    }

    func set(stressIndex: Double, location: String? = nil, updatedAt: Date = .now, source: Source = .remote) {
        self.stressIndex = max(0.0, min(stressIndex, 2.0))
        self.updatedAt = updatedAt
        self.source = source
        if let location { self.location = location }
    }

    // Placeholder hook — wire to real fetch once the backend publishes one.
    func refreshFromRemoteIfAvailable() async {
        guard let remoteURL else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: remoteURL)
            struct Payload: Decodable {
                let stress_index: Double
                let location: String?
                let updated_at: String?
            }
            let p = try JSONDecoder().decode(Payload.self, from: data)
            let parsedDate = p.updated_at.flatMap { ISO8601DateFormatter().date(from: $0) } ?? .now
            set(stressIndex: p.stress_index, location: p.location, updatedAt: parsedDate, source: .remote)
        } catch {
            // Keep current (mock) value silently — demo must not break.
        }
    }
}
