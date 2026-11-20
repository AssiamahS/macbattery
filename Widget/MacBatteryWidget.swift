import SwiftUI
import WidgetKit

struct BatteryEntry: TimelineEntry {
    let date: Date
    let snapshots: [DeviceKind: BatterySnapshot]

    /// The Mac drives the single-device families.
    var snapshot: BatterySnapshot? { snapshots[.mac] }
    var stale: Bool { snapshot?.isStale(at: date) ?? true }
}

/// Wraps WidgetKit's non-Sendable completion handler so it can be called from a Task.
private struct CompletionBox<T>: @unchecked Sendable {
    let call: (T) -> Void
}

struct BatteryProvider: TimelineProvider {
    private static let refresh: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> BatteryEntry {
        BatteryEntry(date: .now, snapshots: BatterySnapshot.previewBoard)
    }

    /// Server reports (Mac, Watch) plus this iPhone read locally. nil = the server was unreachable.
    private static func load() async -> (board: [DeviceKind: BatterySnapshot], reachable: Bool) {
        let fetched = try? await BatteryAPI.fetchAll()
        var board = fetched ?? [:]
        if let phone = await LocalBattery.read() { board[.iphone] = phone }
        return (board, fetched != nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (BatteryEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let box = CompletionBox(call: completion)
        Task {
            let loaded = await Self.load()
            box.call(BatteryEntry(date: .now,
                                  snapshots: loaded.reachable ? loaded.board : BatterySnapshot.previewBoard))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryEntry>) -> Void) {
        let box = CompletionBox(call: completion)
        Task {
            let now = Date.now
            let loaded = await Self.load()
            let next = now.addingTimeInterval(loaded.reachable ? Self.refresh : 5 * 60)
            var entries = [BatteryEntry(date: now, snapshots: loaded.board)]
            // Flip a ring to grey on schedule if its device goes quiet before the next refresh.
            let staleDates = loaded.board.values
                .map { $0.staleDate.addingTimeInterval(1) }
                .filter { $0 > now && $0 < next }
                .sorted()
            for date in staleDates {
                entries.append(BatteryEntry(date: date, snapshots: loaded.board))
            }
            box.call(Timeline(entries: entries, policy: .after(next)))
        }
    }
}

struct BatteryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BatteryEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .systemMedium:
            BatteryRowView(snapshots: entry.snapshots, date: entry.date)
                .containerBackground(.fill.tertiary, for: .widget)
        default:
            small
        }
    }

    private var percent: Int { entry.snapshot?.status.percent ?? 0 }
    private var charging: Bool { entry.snapshot?.status.charging ?? false }

    private var small: some View {
        VStack(spacing: 8) {
            BatteryRingView(percent: percent, charging: charging, stale: entry.stale, lineWidth: 8)
                .frame(width: 84, height: 84)
            if let snapshot = entry.snapshot {
                Text("\(snapshot.status.percent)%")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                Text(entry.stale ? "Not updated" : snapshot.status.detailText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("--%")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                Text("No data")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var circular: some View {
        Gauge(value: Double(percent), in: 0...100) {
            Image(systemName: "laptopcomputer")
        } currentValueLabel: {
            VStack(spacing: 0) {
                Image(systemName: charging && !entry.stale ? "bolt.fill" : "laptopcomputer")
                    .font(.system(size: 10, weight: .semibold))
                Text(entry.snapshot == nil ? "--" : "\(percent)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .opacity(entry.stale ? 0.5 : 1)
        .widgetAccentable()
        .containerBackground(.clear, for: .widget)
    }
}

struct MacBatteryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MacBattery", provider: BatteryProvider()) { entry in
            BatteryWidgetView(entry: entry)
        }
        .configurationDisplayName("Mac Battery")
        .description("iPhone, Apple Watch and MacBook battery levels.")
        .supportedFamilies([.systemMedium, .systemSmall, .accessoryCircular])
    }
}

@main
struct MacBatteryWidgetBundle: WidgetBundle {
    var body: some Widget {
        MacBatteryWidget()
    }
}

#Preview(as: .systemSmall) {
    MacBatteryWidget()
} timeline: {
    BatteryEntry(date: .now, snapshots: BatterySnapshot.previewBoard)
    BatteryEntry(date: .now.addingTimeInterval(3600), snapshots: BatterySnapshot.previewBoard)
}

#Preview(as: .systemMedium) {
    MacBatteryWidget()
} timeline: {
    BatteryEntry(date: .now, snapshots: BatterySnapshot.previewBoard)
}
