import SwiftUI

/// Apple Batteries widget style: a progress ring around the device glyph.
struct BatteryRingView: View {
    var percent: Int
    var charging: Bool
    var stale: Bool
    var lineWidth: CGFloat = 6

    private var fraction: Double { min(max(Double(percent) / 100, 0), 1) }

    private var ringColor: Color {
        if stale { return .gray }
        if percent <= 10 && !charging { return .red }
        if percent <= 20 && !charging { return .orange }
        return .green
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "laptopcomputer")
                .resizable()
                .scaledToFit()
                .fontWeight(.medium)
                .padding(lineWidth * 2.6)
                .foregroundStyle(stale ? Color.secondary : Color.primary)
        }
        .overlay(alignment: .top) {
            if charging && !stale {
                Image(systemName: "bolt.fill")
                    .font(.system(size: lineWidth * 1.8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(lineWidth * 0.35)
                    .background(Circle().fill(.green))
                    .offset(y: -lineWidth * 1.2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mac battery \(percent) percent\(charging ? ", charging" : "")\(stale ? ", not updated recently" : "")")
    }
}

extension BatteryStatus {
    var detailText: String {
        if state == "charged" { return "Charged" }
        guard let minutes = minutesRemaining, minutes > 0 else {
            return charging ? "Charging" : (onAC ? "On power" : "On battery")
        }
        let time = minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
        return charging ? "\(time) to full" : "\(time) left"
    }
}
