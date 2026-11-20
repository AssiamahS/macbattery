import SwiftUI
import WatchKit

/// iOS cannot read the paired watch's battery, so the watch reports its own level to the Worker.
@main
struct MacBatteryWatchApp: App {
    @State private var reporter = WatchReporter()

    var body: some Scene {
        WindowGroup {
            WatchView(reporter: reporter)
        }
        .backgroundTask(.appRefresh(WatchReporter.refreshID)) {
            await reporter.report()
        }
    }
}

@MainActor
@Observable
final class WatchReporter {
    static let refreshID = "battery"
    private static let interval: TimeInterval = 15 * 60

    var percent: Int?
    var charging = false
    var lastSent: Date?
    var lastError: String?

    /// Injected at build time (REPORT_SECRET build setting); never committed.
    private var secret: String {
        (Bundle.main.object(forInfoDictionaryKey: "ReportSecret") as? String) ?? ""
    }

    func report() async {
        scheduleNext()
        let device = WKInterfaceDevice.current()
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel
        guard level >= 0 else { return }
        let value = Int((level * 100).rounded())
        let isCharging = device.batteryState == .charging
        percent = value
        charging = isCharging
        guard !secret.isEmpty else {
            lastError = "No report key in this build"
            return
        }
        do {
            try await BatteryService.report(device: "watch", percent: value, charging: isCharging,
                                            name: device.name, secret: secret)
            lastSent = .now
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// watchOS decides the real cadence; this only states the earliest useful time.
    private func scheduleNext() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date.now.addingTimeInterval(Self.interval),
            userInfo: Self.refreshID as NSString
        ) { _ in }
    }
}

struct WatchView: View {
    var reporter: WatchReporter
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 6) {
            Text(reporter.percent.map { "\($0)%" } ?? "--%")
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if let error = reporter.lastError {
                Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            } else if let sent = reporter.lastSent {
                Text("Sent \(sent, style: .time)").font(.footnote).foregroundStyle(.secondary)
            } else {
                Text("Sending").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .task { await reporter.report() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await reporter.report() } }
        }
    }
}
