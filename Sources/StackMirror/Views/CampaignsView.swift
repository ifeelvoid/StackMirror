import SwiftUI

struct CampaignsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedItemID: String?
    @State private var startDate = Date.now.addingTimeInterval(3600)
    @State private var result = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Newsletter Promotion").font(.largeTitle.bold())
            Text("Turn an article into three scheduled Notes: launch, pull quote, and reminder.")
                .foregroundStyle(.secondary)

            Picker("Article", selection: $selectedItemID) {
                Text("Choose an article…").tag(String?.none)
                ForEach(store.readingItems) { item in
                    Text("\(item.publicationName) — \(item.title)")
                        .tag(String?.some(item.id))
                }
            }

            DatePicker(
                "Campaign starts",
                selection: $startDate,
                in: Date.now...,
                displayedComponents: [.date, .hourAndMinute]
            )

            HStack {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(result.hasPrefix("Failed") ? .red : .green)
                Spacer()
                Button("Create Campaign") {
                    guard let item = store.readingItems.first(where: { $0.id == selectedItemID }) else {
                        result = "Failed: choose an article."
                        return
                    }
                    Task {
                        do {
                            try await store.createPromotionCampaign(for: item, start: startDate)
                            result = "Three Notes scheduled."
                        } catch {
                            result = "Failed: \(error.localizedDescription)"
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .padding(24)
        .navigationTitle("Campaigns")
    }
}
