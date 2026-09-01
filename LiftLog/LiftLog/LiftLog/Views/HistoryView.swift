import SwiftUI

/// Read-only browse of everything in training.md, newest date first.
struct HistoryView: View {
    @EnvironmentObject var store: Store

    private var sortedSessions: [Session] {
        store.sessions.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sortedSessions) { session in
                    Section(session.dateString) {
                        ForEach(session.exercises) { ex in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name).font(.headline)
                                Text(ex.sets.map(\.token).joined(separator: "  "))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .overlay {
                if store.sessions.isEmpty {
                    ContentUnavailableView("No sessions yet",
                                           systemImage: "dumbbell",
                                           description: Text("Log a workout, or pull to refresh."))
                }
            }
            .refreshable { await store.load() }
            .navigationTitle("History")
        }
    }
}
