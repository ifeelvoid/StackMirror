import Foundation

enum SidebarSection: String, CaseIterable, Identifiable {
    case calendar
    case composer
    case campaigns
    case analytics
    case engagement
    case subscriptions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar: "Calendar"
        case .composer: "Composer"
        case .campaigns: "Campaigns"
        case .analytics: "Analytics"
        case .engagement: "Engagement"
        case .subscriptions: "Library"
        }
    }

    var icon: String {
        switch self {
        case .calendar: "calendar"
        case .composer: "square.and.pencil"
        case .campaigns: "megaphone"
        case .analytics: "chart.bar.xaxis"
        case .engagement: "bubble.left.and.bubble.right"
        case .subscriptions: "books.vertical"
        }
    }
}

struct ContentTemplate: Codable, Equatable, Sendable {
    var prefix = ""
    var suffix = ""
    var removePhrases = "Twitter,X.com,Threads"
    var replaceLineBreaks = false
}

struct SubstackProfile: Codable, Hashable, Sendable {
    let id: Int
    let name: String
    let handle: String?
    let followerCount: Int?
    let subscriberCountNumber: Int?
    let primaryPublication: SubstackPublication?
}

struct SubstackPublication: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let name: String
    let subdomain: String?
    let customDomain: String?
    let logoURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name, subdomain
        case customDomain = "custom_domain"
        case logoURL = "logo_url"
    }

    var siteURL: URL? {
        if let customDomain, !customDomain.isEmpty {
            return URL(string: "https://\(customDomain)")
        }
        guard let subdomain else { return nil }
        return URL(string: "https://\(subdomain).substack.com")
    }
}

struct SubstackSubscription: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let membershipState: String
    let publication: SubstackPublication

    enum CodingKeys: String, CodingKey {
        case id, publication
        case membershipState = "membership_state"
    }
}

struct SubstackNote: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let body: String
    let date: Date
    let reactionCount: Int
    let restacks: Int
    let childrenCount: Int

    var engagementTotal: Int { reactionCount + restacks + childrenCount }
}

struct SubstackReply: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let body: String
    let name: String
    let handle: String?
    let date: Date
    let parentNoteID: Int
}

struct SubstackDraft: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let body: String?
    let triggerAt: Date?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id, body, status
        case triggerAt = "trigger_at"
    }
}

struct ArchivePost: Codable, Hashable, Identifiable, Sendable {
    let id: Int
    let title: String
    let subtitle: String?
    let slug: String
    let canonicalURL: String?
    let postDate: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, slug
        case canonicalURL = "canonical_url"
        case postDate = "post_date"
    }
}

struct ReadingItem: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let publicationName: String
    let title: String
    let subtitle: String?
    let url: URL?
    let date: Date?
}

struct AppConfiguration: Codable, Equatable, Sendable {
    var includeLinkPreviews = true
    var notifyOnFailure = true
    var launchAtLogin = false
    var mcpEnabled = false
    var template = ContentTemplate()

    init() {}

    // Pre-scheduler state files also carry mirroring keys; keyed decoding ignores them.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        includeLinkPreviews = try container.decodeIfPresent(Bool.self, forKey: .includeLinkPreviews) ?? true
        notifyOnFailure = try container.decodeIfPresent(Bool.self, forKey: .notifyOnFailure) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        mcpEnabled = try container.decodeIfPresent(Bool.self, forKey: .mcpEnabled) ?? false
        template = try container.decodeIfPresent(ContentTemplate.self, forKey: .template) ?? ContentTemplate()
    }
}

struct PersistedState: Codable, Sendable {
    var configuration = AppConfiguration()
    var profile: SubstackProfile?
    var notes: [SubstackNote] = []
    var replies: [SubstackReply] = []
    var drafts: [SubstackDraft] = []
    var subscriptions: [SubstackSubscription] = []
    var readingItems: [ReadingItem] = []
    var lastManagerScanAt: Date?

    init(
        configuration: AppConfiguration = AppConfiguration(),
        profile: SubstackProfile? = nil,
        notes: [SubstackNote] = [],
        replies: [SubstackReply] = [],
        drafts: [SubstackDraft] = [],
        subscriptions: [SubstackSubscription] = [],
        readingItems: [ReadingItem] = [],
        lastManagerScanAt: Date? = nil
    ) {
        self.configuration = configuration
        self.profile = profile
        self.notes = notes
        self.replies = replies
        self.drafts = drafts
        self.subscriptions = subscriptions
        self.readingItems = readingItems
        self.lastManagerScanAt = lastManagerScanAt
    }

    // Mirroring-era `posts` and `records` keys are ignored, so old state files still load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        configuration = try container.decodeIfPresent(AppConfiguration.self, forKey: .configuration) ?? AppConfiguration()
        profile = try container.decodeIfPresent(SubstackProfile.self, forKey: .profile)
        notes = try container.decodeIfPresent([SubstackNote].self, forKey: .notes) ?? []
        replies = try container.decodeIfPresent([SubstackReply].self, forKey: .replies) ?? []
        drafts = try container.decodeIfPresent([SubstackDraft].self, forKey: .drafts) ?? []
        subscriptions = try container.decodeIfPresent([SubstackSubscription].self, forKey: .subscriptions) ?? []
        readingItems = try container.decodeIfPresent([ReadingItem].self, forKey: .readingItems) ?? []
        lastManagerScanAt = try container.decodeIfPresent(Date.self, forKey: .lastManagerScanAt)
    }
}
