import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var configuration: AppConfiguration
    @Published private(set) var profile: SubstackProfile?
    @Published private(set) var notes: [SubstackNote]
    @Published private(set) var replies: [SubstackReply]
    @Published private(set) var drafts: [SubstackDraft]
    @Published private(set) var subscriptions: [SubstackSubscription]
    @Published private(set) var readingItems: [ReadingItem]
    @Published private(set) var lastManagerScanAt: Date?
    @Published private(set) var lastDraftRefreshAt: Date?
    @Published private(set) var isRefreshingDrafts = false
    @Published private(set) var isManagerScanning = false
    @Published private(set) var statusMessage = "Connect Substack in Settings"
    @Published private(set) var managerStatus = "Weekly scan has not run"

    private let substackClient = SubstackAPIClient()
    private let keychain = KeychainService()
    private let persistence = PersistenceService()
    private let launchAtLogin = LaunchAtLoginService()
    private let notifications = NotificationService()
    private var credentialCache: [CredentialKey: String] = [:]
    private var managerTask: Task<Void, Never>?
    private var stateRecoveryMessage: String?
    private var hasStarted = false

    init() {
        let state: PersistedState
        var recovery: String?
        do { state = try PersistenceService().load() }
        catch {
            state = PersistedState()
            recovery = "Saved app state cannot be read. Scheduling is blocked. Restore a verified state.json, then restart StackMirror."
        }
        configuration = state.configuration
        profile = state.profile
        notes = state.notes
        replies = state.replies
        drafts = state.drafts
        subscriptions = state.subscriptions
        readingItems = state.readingItems
        lastManagerScanAt = state.lastManagerScanAt
        stateRecoveryMessage = recovery
        if let recovery { statusMessage = recovery }
    }

    /// Notes Substack will publish later, soonest first. Only these belong on the calendar.
    var scheduledDrafts: [SubstackDraft] {
        drafts
            .filter { $0.triggerAt != nil }
            .sorted { $0.triggerAt! < $1.triggerAt! }
    }

    var menuBarIcon: String {
        if isRefreshingDrafts || isManagerScanning { return "arrow.triangle.2.circlepath" }
        if stateRecoveryMessage != nil { return "exclamationmark.triangle" }
        return "calendar"
    }

    var analyticsTotals: (likes: Int, replies: Int, restacks: Int) {
        (
            notes.reduce(0) { $0 + $1.reactionCount },
            notes.reduce(0) { $0 + $1.childrenCount },
            notes.reduce(0) { $0 + $1.restacks }
        )
    }

    func start() async {
        guard stateRecoveryMessage == nil else { return }
        guard !hasStarted else { return }
        hasStarted = true

        await notifications.requestAuthorization()
        guard hasSubstackSession else { return }
        await refreshDrafts()
        restartManagerSchedule()
        if managerScanIsDue {
            await scanManager()
        }
    }

    var hasSubstackSession: Bool {
        (try? cachedCredential(.substackSessionCookie).isEmpty == false) ?? false
    }

    func saveSubstackSession(_ cookie: String) throws {
        try keychain.save(cookie, for: .substackSessionCookie)
        credentialCache[.substackSessionCookie] = cookie
        statusMessage = "Substack connected"
    }

    func saveConfiguration() throws {
        do {
            try launchAtLogin.setEnabled(configuration.launchAtLogin)
        } catch {
            configuration.launchAtLogin = launchAtLogin.isEnabled
            throw error
        }
        try saveState()
        statusMessage = "Settings saved"
    }

    /// Fetches Substack's own scheduled drafts so the calendar reflects Notes created anywhere, not only here.
    func refreshDrafts() async {
        guard !isRefreshingDrafts else { return }
        isRefreshingDrafts = true
        defer { isRefreshingDrafts = false }
        do {
            let cookie = try requiredCredential(.substackSessionCookie, label: "Substack session cookie")
            drafts = try await substackClient.drafts(sessionCookie: cookie)
            lastDraftRefreshAt = .now
            statusMessage = "\(scheduledDrafts.count) scheduled Note\(scheduledDrafts.count == 1 ? "" : "s")"
            persist()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func publishManualNote(_ text: String, scheduledAt: Date?) async throws {
        let cookie = try requiredCredential(.substackSessionCookie, label: "Substack session cookie")
        let transformed = ContentTransformer.transform(text, configuration: configuration)
        let attachmentIDs = try await attachments(for: transformed, cookie: cookie)
        if let scheduledAt {
            let draft = try await substackClient.scheduleNote(
                text: transformed,
                at: scheduledAt,
                sessionCookie: cookie,
                attachmentIDs: attachmentIDs
            )
            drafts.removeAll { $0.id == draft.id }
            drafts.insert(draft, at: 0)
            statusMessage = "Note scheduled"
        } else {
            try await substackClient.publishNote(
                text: transformed,
                sessionCookie: cookie,
                attachmentIDs: attachmentIDs
            )
            statusMessage = "Note published"
        }
        persist()
    }

    func publishTestNote() async throws {
        let timestamp = Date.now.formatted(date: .abbreviated, time: .shortened)
        try await publishManualNote("StackMirror connection test — \(timestamp)", scheduledAt: nil)
    }

    func scanManager() async {
        guard !isManagerScanning else { return }
        isManagerScanning = true
        managerStatus = "Scanning Substack…"
        defer { isManagerScanning = false }

        do {
            let cookie = try requiredCredential(.substackSessionCookie, label: "Substack session cookie")
            let basicProfile = try await substackClient.profile(sessionCookie: cookie)
            guard let handle = basicProfile.handle else {
                throw APIClientError.missingData
            }
            let fullProfile = try await substackClient.profileWithSubscriptions(
                userID: basicProfile.id,
                handle: handle,
                sessionCookie: cookie
            )
            profile = fullProfile.profile
            subscriptions = fullProfile.subscriptions
            notes = try await substackClient.ownNotes(
                userID: basicProfile.id,
                sessionCookie: cookie
            )
            drafts = try await substackClient.drafts(sessionCookie: cookie)
            lastDraftRefreshAt = .now

            var newReplies: [SubstackReply] = []
            for note in notes.prefix(20) where note.childrenCount > 0 {
                let noteReplies = (try? await substackClient.replies(
                    noteID: note.id,
                    sessionCookie: cookie
                )) ?? []
                newReplies.append(contentsOf: noteReplies)
            }
            replies = newReplies.sorted { $0.date > $1.date }

            var newReadingItems: [ReadingItem] = []
            for subscription in subscriptions.prefix(25) {
                let archive = (try? await substackClient.archive(
                    publication: subscription.publication,
                    limit: 3
                )) ?? []
                newReadingItems.append(contentsOf: archive.map { post in
                    ReadingItem(
                        id: "\(subscription.publication.id)-\(post.id)",
                        publicationName: subscription.publication.name,
                        title: post.title,
                        subtitle: post.subtitle,
                        url: post.canonicalURL.flatMap(URL.init(string:)),
                        date: post.postDate
                    )
                })
            }
            readingItems = newReadingItems.sorted {
                ($0.date ?? .distantPast) > ($1.date ?? .distantPast)
            }
            lastManagerScanAt = .now
            managerStatus = "Weekly scan complete"
            persist()
        } catch {
            managerStatus = error.localizedDescription
            if configuration.notifyOnFailure {
                await notifications.failure("Weekly scan failed: \(error.localizedDescription)")
            }
        }
    }

    func createPromotionCampaign(for item: ReadingItem, start: Date = .now) async throws {
        guard let url = item.url else { throw APIClientError.missingData }
        let messages = [
            "\(item.title)\n\n\(url.absoluteString)",
            "A line worth sitting with from my latest piece:\n\n\(item.subtitle ?? item.title)\n\n\(url.absoluteString)",
            "If you missed it: \(item.title)\n\n\(url.absoluteString)"
        ]
        for (index, message) in messages.enumerated() {
            let date = Calendar.current.date(byAdding: .day, value: index * 2, to: start)!
            try await publishManualNote(message, scheduledAt: date)
        }
    }

    private var managerScanIsDue: Bool {
        guard let lastManagerScanAt else { return true }
        return Date.now.timeIntervalSince(lastManagerScanAt) >= 7 * 24 * 60 * 60
    }

    private func requiredCredential(_ key: CredentialKey, label: String) throws -> String {
        if let message = stateRecoveryMessage { throw NSError(domain: "StackMirror.StateRecovery", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        let value = try cachedCredential(key)
        guard !value.isEmpty else {
            throw APIClientError.missingCredential(label)
        }
        return value
    }

    private func cachedCredential(_ key: CredentialKey) throws -> String {
        if let cached = credentialCache[key] {
            return cached
        }
        let value = try keychain.read(key)
        credentialCache[key] = value
        return value
    }

    private func attachments(for text: String, cookie: String) async throws -> [Int] {
        guard configuration.includeLinkPreviews else { return [] }
        return await substackClient.linkPreviewAttachments(for: text, sessionCookie: cookie)
    }

    private func persist() {
        do {
            try saveState()
        } catch {
            statusMessage = "Could not save app state: \(error.localizedDescription)"
        }
    }

    private func saveState() throws {
        if let message = stateRecoveryMessage { throw NSError(domain: "StackMirror.StateRecovery", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
        try persistence.save(
            PersistedState(
                configuration: configuration,
                profile: profile,
                notes: notes,
                replies: replies,
                drafts: drafts,
                subscriptions: subscriptions,
                readingItems: readingItems,
                lastManagerScanAt: lastManagerScanAt
            )
        )
    }

    private func restartManagerSchedule() {
        managerTask?.cancel()
        managerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(21_600))
                guard !Task.isCancelled else { return }
                guard let self, self.managerScanIsDue else { continue }
                await self.scanManager()
            }
        }
    }
}
