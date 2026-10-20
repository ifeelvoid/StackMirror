import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Substack Performance").font(.largeTitle.bold())
                        Text(store.managerStatus).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if store.isManagerScanning { ProgressView() }
                    Button("Scan Now") { Task { await store.scanManager() } }
                }

                HStack(spacing: 12) {
                    card("Notes", store.notes.count, "note.text")
                    card("Likes", store.analyticsTotals.likes, "heart")
                    card("Replies", store.analyticsTotals.replies, "bubble.left")
                    card("Restacks", store.analyticsTotals.restacks, "arrow.2.squarepath")
                }

                GroupBox("Top Notes") {
                    VStack(spacing: 0) {
                        ForEach(store.notes.sorted { $0.engagementTotal > $1.engagementTotal }.prefix(12)) { note in
                            HStack(alignment: .top) {
                                Text(note.body).lineLimit(2)
                                Spacer()
                                Text(note.engagementTotal.formatted()).font(.title3.bold())
                            }
                            .padding(.vertical, 9)
                            Divider()
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Analytics")
    }

    private func card(_ title: String, _ value: Int, _ icon: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: icon).foregroundStyle(.secondary)
                Text(value.formatted()).font(.title.bold())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity)
    }
}
