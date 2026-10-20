import AppKit
import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selection = 0
    @State private var search = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selection) {
                Text("Subscriptions").tag(0)
                Text("Reading List").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            switch selection {
            case 0: subscriptions
            default: readingList
            }
        }
        .navigationTitle("Library")
        .searchable(text: $search)
    }

    private var subscriptions: some View {
        List(store.subscriptions.filter {
            search.isEmpty || $0.publication.name.localizedCaseInsensitiveContains(search)
        }) { subscription in
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(subscription.publication.name)
                    Text(subscription.membershipState)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let url = subscription.publication.siteURL {
                    Link("Open", destination: url)
                }
            }
        }
        .toolbar { Button("Export CSV") { exportCSV() } }
    }

    private var readingList: some View {
        List(store.readingItems.filter {
            search.isEmpty ||
            $0.title.localizedCaseInsensitiveContains(search) ||
            $0.publicationName.localizedCaseInsensitiveContains(search)
        }) { item in
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                Text(item.publicationName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let url = item.url {
                    Link(url.absoluteString, destination: url).font(.caption2)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "substack-subscriptions.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? CSVExportService().subscriptions(store.subscriptions)
            .write(to: url, atomically: true, encoding: .utf8)
    }
}
