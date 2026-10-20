import Foundation

struct SubstackAPIClient: Sendable {
    private let baseURL = URL(string: "https://substack.com")!
    private let requestTimeout: TimeInterval = 20

    func profile(sessionCookie: String) async throws -> SubstackProfile {
        try await request(path: "/api/v1/user/profile/self", sessionCookie: sessionCookie)
    }

    func profileWithSubscriptions(
        userID: Int,
        handle: String,
        sessionCookie: String
    ) async throws -> ProfileEnvelope {
        try await request(
            path: "/api/v1/user/\(userID)-\(handle)/public_profile/self",
            sessionCookie: sessionCookie
        )
    }

    func ownNotes(
        userID: Int,
        sessionCookie: String,
        limit: Int = 50
    ) async throws -> [SubstackNote] {
        let envelope: FeedEnvelope = try await request(
            path: "/api/v1/reader/feed/profile/\(userID)?limit=\(limit)",
            sessionCookie: sessionCookie
        )
        return envelope.items.compactMap { item in
            guard item.type == "comment",
                  let comment = item.comment,
                  comment.type == "feed",
                  comment.userID == userID,
                  let date = parseAPIDate(comment.date) else {
                return nil
            }
            return SubstackNote(
                id: comment.id,
                body: comment.body,
                date: date,
                reactionCount: comment.reactionCount,
                restacks: comment.restacks,
                childrenCount: comment.childrenCount
            )
        }
    }

    func drafts(sessionCookie: String, limit: Int = 50) async throws -> [SubstackDraft] {
        let envelope: DraftEnvelope = try await request(
            path: "/api/v1/feed/drafts?limit=\(limit)",
            sessionCookie: sessionCookie
        )
        return envelope.drafts
    }

    func replies(
        noteID: Int,
        sessionCookie: String
    ) async throws -> [SubstackReply] {
        let envelope: ReplyEnvelope = try await request(
            path: "/api/v1/reader/comment/\(noteID)/replies",
            sessionCookie: sessionCookie
        )
        return envelope.commentBranches.flatMap { branch in
            branch.compactMap { comment in
                guard let date = parseAPIDate(comment.date) else {
                    return nil
                }
                return SubstackReply(
                    id: comment.id,
                    body: comment.body,
                    name: comment.name,
                    handle: comment.handle,
                    date: date,
                    parentNoteID: noteID
                )
            }
        }
    }

    func archive(publication: SubstackPublication, limit: Int = 10) async throws -> [ArchivePost] {
        guard let siteURL = publication.siteURL else { return [] }
        let url = siteURL.appending(path: "/api/v1/archive")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "sort", value: "new"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        try validate(response: response, data: data)
        return try JSONDecoder.apiDecoder.decode([ArchivePost].self, from: data)
    }

    func createAttachment(
        url: URL,
        sessionCookie: String
    ) async throws -> Int {
        let payload = AttachmentPayload(url: url.absoluteString, type: "link")
        let response: AttachmentResponse = try await request(
            path: "/api/v1/comment/attachment",
            method: "POST",
            payload: payload,
            sessionCookie: sessionCookie
        )
        return response.id
    }

    func publishNote(
        text: String,
        sessionCookie: String,
        attachmentIDs: [Int] = []
    ) async throws {
        let payload = NotePayload(
            bodyJson: noteDocument(text),
            attachmentIds: attachmentIDs.isEmpty ? nil : attachmentIDs,
            tabId: "for-you",
            surface: "feed",
            replyMinimumRole: "everyone"
        )
        let _: FeedCommentResponse = try await request(
            path: "/api/v1/comment/feed",
            method: "POST",
            payload: payload,
            sessionCookie: sessionCookie
        )
    }

    func scheduleNote(
        text: String,
        at date: Date,
        sessionCookie: String,
        attachmentIDs: [Int] = []
    ) async throws -> SubstackDraft {
        let payload = DraftPayload(
            bodyJson: noteDocument(text),
            attachmentIds: attachmentIDs.isEmpty ? nil : attachmentIDs,
            tabId: "for-you",
            surface: "feed",
            replyMinimumRole: "everyone",
            triggerAt: ISO8601DateFormatter().string(from: date)
        )
        return try await request(
            path: "/api/v1/comment/draft",
            method: "POST",
            payload: payload,
            sessionCookie: sessionCookie
        )
    }

    private func request<Response: Decodable>(
        path: String,
        sessionCookie: String
    ) async throws -> Response {
        var request = URLRequest(url: URL(string: path, relativeTo: baseURL)!)
        request.timeoutInterval = requestTimeout
        request.setValue("substack.sid=\(sessionCookie)", forHTTPHeaderField: "Cookie")
        request.setValue("https://substack.com", forHTTPHeaderField: "Origin")
        request.setValue("https://substack.com/notes", forHTTPHeaderField: "Referer")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.apiDecoder.decode(Response.self, from: data)
    }

    private func request<Response: Decodable, Payload: Encodable>(
        path: String,
        method: String,
        payload: Payload,
        sessionCookie: String
    ) async throws -> Response {
        var request = URLRequest(url: URL(string: path, relativeTo: baseURL)!)
        request.timeoutInterval = requestTimeout
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("substack.sid=\(sessionCookie)", forHTTPHeaderField: "Cookie")
        request.setValue("https://substack.com", forHTTPHeaderField: "Origin")
        request.setValue("https://substack.com/notes", forHTTPHeaderField: "Referer")
        request.httpBody = try JSONEncoder.apiEncoder.encode(payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder.apiDecoder.decode(Response.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIClientError.http(
                http.statusCode,
                String(data: data, encoding: .utf8) ?? "Substack request failed."
            )
        }
    }

    private func noteDocument(_ text: String) -> NoteDocument {
        NoteDocument(
            type: "doc",
            attrs: ["schemaVersion": "v1"],
            content: text.components(separatedBy: "\n\n").map { paragraph in
                NoteParagraph(
                    type: "paragraph",
                    content: paragraph.isEmpty ? nil : [NoteText(type: "text", text: paragraph)]
                )
            }
        )
    }
}

struct ProfileEnvelope: Decodable, Sendable {
    let id: Int
    let name: String
    let handle: String?
    let followerCount: Int?
    let subscriberCountNumber: Int?
    let primaryPublication: SubstackPublication?
    let subscriptions: [SubstackSubscription]

    var profile: SubstackProfile {
        SubstackProfile(
            id: id,
            name: name,
            handle: handle,
            followerCount: followerCount,
            subscriberCountNumber: subscriberCountNumber,
            primaryPublication: primaryPublication
        )
    }
}

private struct FeedEnvelope: Decodable {
    let items: [FeedItem]
}

private struct FeedItem: Decodable {
    let type: String
    let comment: FeedComment?
}

private struct FeedComment: Decodable {
    let id: Int
    let body: String
    let userID: Int
    let type: String
    let date: String
    let reactionCount: Int
    let restacks: Int
    let childrenCount: Int

    enum CodingKeys: String, CodingKey {
        case id, body, type, date, restacks
        case userID = "user_id"
        case reactionCount = "reaction_count"
        case childrenCount = "children_count"
    }
}

private struct DraftEnvelope: Decodable {
    let drafts: [SubstackDraft]
}

private struct ReplyEnvelope: Decodable {
    let commentBranches: [[ReplyComment]]
}

private struct ReplyComment: Decodable {
    let id: Int
    let body: String
    let name: String
    let handle: String?
    let date: String
}

private struct FeedCommentResponse: Decodable {
    let id: Int
}

private struct AttachmentPayload: Encodable {
    let url: String
    let type: String
}

private struct AttachmentResponse: Decodable {
    let id: Int
}

private struct NotePayload: Encodable {
    let bodyJson: NoteDocument
    let attachmentIds: [Int]?
    let tabId: String
    let surface: String
    let replyMinimumRole: String
}

private struct DraftPayload: Encodable {
    let bodyJson: NoteDocument
    let attachmentIds: [Int]?
    let tabId: String
    let surface: String
    let replyMinimumRole: String
    let triggerAt: String
}

private struct NoteDocument: Encodable {
    let type: String
    let attrs: [String: String]
    let content: [NoteParagraph]
}

private struct NoteParagraph: Encodable {
    let type: String
    let content: [NoteText]?
}

private struct NoteText: Encodable {
    let type: String
    let text: String
}

private extension JSONEncoder {
    static var apiEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private func parseAPIDate(_ value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: value) { return date }
    return ISO8601DateFormatter().date(from: value)
}
