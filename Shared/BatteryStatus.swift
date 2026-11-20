import Foundation

/// One device's battery report as served by the macbattery Worker.
struct BatteryStatus: Codable, Equatable, Sendable {
    var percent: Int
    var charging: Bool
    var onAC: Bool
    var state: String
    var minutesRemaining: Int?
    var device: String
    var ageSeconds: Int
}

/// The slots of the Batteries-style row, in display order.
enum DeviceKind: String, CaseIterable, Sendable {
    case iphone, watch, mac

    var symbol: String {
        switch self {
        case .iphone: "iphone"
        case .watch: "applewatch"
        case .mac: "laptopcomputer"
        }
    }

    var label: String {
        switch self {
        case .iphone: "iPhone"
        case .watch: "Watch"
        case .mac: "Mac"
        }
    }

    /// How long after its last report a device counts as asleep or out of reach.
    /// The Mac posts every 2 minutes; the watch only gets a background slot now and then.
    var staleAfter: TimeInterval {
        switch self {
        case .iphone: 30 * 60
        case .watch: 2 * 60 * 60
        case .mac: 10 * 60
        }
    }
}

/// A status pinned to the moment it was measured (or received by the Worker).
struct BatterySnapshot: Equatable, Sendable {
    var status: BatteryStatus
    var receivedAt: Date
    var kind: DeviceKind = .mac

    var staleDate: Date { receivedAt.addingTimeInterval(kind.staleAfter) }

    func isStale(at date: Date) -> Bool { date > staleDate }

    static let preview = BatterySnapshot(
        status: BatteryStatus(percent: 76, charging: true, onAC: true, state: "charging",
                              minutesRemaining: 42, device: "MacBook Air", ageSeconds: 0),
        receivedAt: .now
    )

    static let previewBoard: [DeviceKind: BatterySnapshot] = [
        .iphone: BatterySnapshot(
            status: BatteryStatus(percent: 69, charging: false, onAC: false, state: "discharging",
                                  minutesRemaining: nil, device: "iPhone", ageSeconds: 0),
            receivedAt: .now, kind: .iphone),
        .watch: BatterySnapshot(
            status: BatteryStatus(percent: 17, charging: true, onAC: true, state: "charging",
                                  minutesRemaining: nil, device: "Apple Watch", ageSeconds: 0),
            receivedAt: .now, kind: .watch),
        .mac: preview,
    ]
}

enum BatteryAPI {
    private struct Board: Decodable {
        var devices: [String: BatteryStatus]
    }

    /// GET /batteries: every device that has reported, keyed by slot.
    static func fetchAll() async throws -> [DeviceKind: BatterySnapshot] {
        var request = URLRequest(url: BatteryService.base.appendingPathComponent("batteries"),
                                 cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let board = try JSONDecoder().decode(Board.self, from: data)
        let now = Date.now
        var result: [DeviceKind: BatterySnapshot] = [:]
        for (id, status) in board.devices {
            guard let kind = DeviceKind(rawValue: id) else { continue }
            result[kind] = BatterySnapshot(status: status,
                                           receivedAt: now.addingTimeInterval(-TimeInterval(status.ageSeconds)),
                                           kind: kind)
        }
        return result
    }
}
