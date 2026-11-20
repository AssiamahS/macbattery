import SwiftUI

/// Apple's medium Batteries layout: four rings in a row with the percentage under each.
/// iPhone, Watch, Mac, then one spare slot that stays empty.
struct BatteryRowView: View {
    var snapshots: [DeviceKind: BatterySnapshot]
    var date: Date
    var lineWidth: CGFloat = 6

    private static let slotCount = 4

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(0..<Self.slotCount, id: \.self) { index in
                let kind = index < DeviceKind.allCases.count ? DeviceKind.allCases[index] : nil
                slot(kind: kind, snapshot: kind.flatMap { snapshots[$0] })
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func slot(kind: DeviceKind?, snapshot: BatterySnapshot?) -> some View {
        let stale = snapshot?.isStale(at: date) ?? true
        return VStack(spacing: 8) {
            BatteryRingView(percent: snapshot?.status.percent ?? 0,
                            charging: snapshot?.status.charging ?? false,
                            stale: stale,
                            lineWidth: lineWidth,
                            symbol: kind?.symbol,
                            name: kind?.label ?? "Empty")
                .aspectRatio(1, contentMode: .fit)
            Text(snapshot.map { "\($0.status.percent)%" } ?? " ")
                .font(.system(.title3, design: .rounded, weight: .medium))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(stale ? Color.secondary : Color.primary)
        }
    }
}
