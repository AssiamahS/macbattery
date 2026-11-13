import Foundation

/// Latest battery report as served by GET /battery on the macbattery Worker.
struct BatteryStatus: Codable, Equatable, Sendable {
    var percent: Int
    var charging: Bool
    var onAC: Bool
    var state: String
    var minutesRemaining: Int?
    var device: String
    var ageSeconds: Int
}

/// A fetched status pinned to the moment the Worker received it.
struct BatterySnapshot: Equatable, Sendable {
    var status: BatteryStatus
    var receivedAt: Date

    /// Reporter posts every 2 minutes; after this long with no report the Mac is asleep/offline.
    static let staleAfter: TimeInterval = 10 * 60

    func isStale(at date: Date) -> Bool {
        date.timeIntervalSince(receivedAt) > Self.staleAfter
    }

    static let preview = BatterySnapshot(
        status: BatteryStatus(percent: 76, charging: true, onAC: true, state: "charging",
                              minutesRemaining: 42, device: "MacBook Air", ageSeconds: 0),
        receivedAt: .now
    )
}

enum BatteryAPI {
    static let endpoint = URL(string: "https://macbattery.sylvesterassiamahpm.workers.dev/battery")!

    static func fetch() async throws -> BatterySnapshot {
        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let status = try JSONDecoder().decode(BatteryStatus.self, from: data)
        let receivedAt = Date.now.addingTimeInterval(-TimeInterval(status.ageSeconds))
        return BatterySnapshot(status: status, receivedAt: receivedAt)
    }
}
