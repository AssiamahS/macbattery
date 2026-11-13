import SwiftUI
import WidgetKit

@main
struct MacBatteryApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var snapshot: BatterySnapshot?
    @State private var errorText: String?
    @State private var loading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let snapshot {
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            let stale = snapshot.isStale(at: context.date)
                            VStack(spacing: 16) {
                                BatteryRingView(percent: snapshot.status.percent,
                                                charging: snapshot.status.charging,
                                                stale: stale, lineWidth: 16)
                                    .frame(width: 200, height: 200)
                                Text("\(snapshot.status.percent)%")
                                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                Text(snapshot.status.detailText)
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                Text("\(snapshot.status.device) · updated \(snapshot.receivedAt, style: .relative) ago")
                                    .font(.footnote)
                                    .foregroundStyle(stale ? .orange : .secondary)
                            }
                        }
                    } else if loading {
                        ProgressView().padding(.top, 120)
                    }
                    if let errorText {
                        Text(errorText).font(.footnote).foregroundStyle(.red)
                    }
                    Text("Add the widget: long-press the Home Screen, tap Edit, Add Widget, then search for Mac Battery.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            }
            .refreshable { await load() }
            .navigationTitle("Mac Battery")
            .toolbar {
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await load() } }
            }
        }
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            snapshot = try await BatteryAPI.fetch()
            errorText = nil
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            errorText = "Could not reach the battery service: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
}
