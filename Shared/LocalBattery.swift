import UIKit

/// This iPhone's own battery, read on device. Nothing is sent anywhere.
@MainActor
enum LocalBattery {
    static func read() -> BatterySnapshot? {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel
        guard level >= 0 else { return nil }
        let state = device.batteryState
        let charging = state == .charging
        let status = BatteryStatus(percent: Int((level * 100).rounded()),
                                   charging: charging,
                                   onAC: charging || state == .full,
                                   state: state == .full ? "charged" : (charging ? "charging" : "discharging"),
                                   minutesRemaining: nil,
                                   device: "iPhone",
                                   ageSeconds: 0)
        return BatterySnapshot(status: status, receivedAt: .now, kind: .iphone)
    }
}
