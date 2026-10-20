import Foundation

struct CSVExportService: Sendable {
    func subscriptions(_ subscriptions: [SubstackSubscription]) -> String {
        let header = "name,url,membership_state"
        let rows = subscriptions.map { subscription in
            [
                escape(subscription.publication.name),
                escape(subscription.publication.siteURL?.absoluteString ?? ""),
                escape(subscription.membershipState)
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private func escape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
