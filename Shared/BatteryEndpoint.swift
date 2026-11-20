import Foundation

/// The macbattery Worker. Shared by the app, the widget and the watch reporter.
enum BatteryService {
    static let base = URL(string: "https://macbattery.sylvesterassiamahpm.workers.dev")!

    /// POST /battery/<device>. The Mac uses its own shell reporter; this is for the watch.
    static func report(device: String, percent: Int, charging: Bool, name: String, secret: String) async throws {
        var request = URLRequest(url: base.appendingPathComponent("battery").appendingPathComponent(device),
                                 cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(secret, forHTTPHeaderField: "x-battery-secret")
        let body: [String: Any] = [
            "percent": percent,
            "charging": charging,
            "onAC": charging,
            "state": charging ? "charging" : "discharging",
            "device": name,
            "reportedAt": ISO8601DateFormatter().string(from: .now),
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
}
