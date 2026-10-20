import SwiftUI

struct EngagementView: View {
    @EnvironmentObject private var store: AppStore
    @State private var search = ""

    private var filtered: [SubstackReply] {
        guard !search.isEmpty else { return store.replies }
        return store.replies.filter {
            $0.body.localizedCaseInsensitiveContains(search) ||
            $0.name.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        Group {
            if filtered.isEmpty {
                ContentUnavailableView(
                    "No replies cached",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Run the weekly scan to refresh replies to your Notes.")
                )
            } else {
                List(filtered) { reply in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(reply.name).fontWeight(.semibold)
                            if let handle = reply.handle {
                                Text("@\(handle)").foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(AppDateFormatters.dateTime.string(from: reply.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(reply.body)
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        .searchable(text: $search)
        .navigationTitle("Engagement")
        .toolbar { Button("Scan Now") { Task { await store.scanManager() } } }
    }
}
