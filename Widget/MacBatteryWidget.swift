import SwiftUI
import WidgetKit

struct BatteryEntry: TimelineEntry {
    let date: Date
    let snapshot: BatterySnapshot?

    var stale: Bool { snapshot?.isStale(at: date) ?? true }
}

/// Wraps WidgetKit's non-Sendable completion handler so it can be called from a Task.
private struct CompletionBox<T>: @unchecked Sendable {
    let call: (T) -> Void
}

struct BatteryProvider: TimelineProvider {
    private static let refresh: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> BatteryEntry {
        BatteryEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (BatteryEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        let box = CompletionBox(call: completion)
        Task {
            let snapshot = try? await BatteryAPI.fetch()
            box.call(BatteryEntry(date: .now, snapshot: snapshot ?? .preview))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryEntry>) -> Void) {
        let box = CompletionBox(call: completion)
        Task {
            let now = Date.now
            let snapshot = try? await BatteryAPI.fetch()
            var entries = [BatteryEntry(date: now, snapshot: snapshot)]
            // Flip the ring to grey on schedule if no newer report has arrived by then.
            if let snapshot, !snapshot.isStale(at: now) {
                let staleAt = snapshot.receivedAt.addingTimeInterval(BatterySnapshot.staleAfter + 1)
                entries.append(BatteryEntry(date: staleAt, snapshot: snapshot))
            }
            let retry = snapshot == nil ? 5 * 60 : Self.refresh
            box.call(Timeline(entries: entries, policy: .after(now.addingTimeInterval(retry))))
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
        .description("Your MacBook's battery level.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
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
    BatteryEntry(date: .now, snapshot: .preview)
    BatteryEntry(date: .now.addingTimeInterval(3600), snapshot: .preview)
}
