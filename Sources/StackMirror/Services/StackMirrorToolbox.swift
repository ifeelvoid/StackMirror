import Foundation

/// Counts schedule calls for one MCP server process so a runaway agent cannot flood the calendar.
actor ScheduleLimiter {
    private let limit: Int
    private var used = 0

    init(limit: Int) { self.limit = limit }

    func take() -> Bool {
        guard used < limit else { return false }
        used += 1
        return true
    }
}

/// The StackMirror tools served over MCP. It reads `state.json` and never writes it; the app stays the only writer.
struct StackMirrorToolbox: MCPToolbox {
    static let schedulesPerSession = 20
    static let disabledMessage = "MCP is turned off. Turn it on in StackMirror → Settings → AI Assistants."

    let loadState: @Sendable () throws -> PersistedState
    let sessionCookie: @Sendable () throws -> String
    let fetchDrafts: @Sendable (_ cookie: String) async throws -> [SubstackDraft]
    let schedule: @Sendable (_ text: String, _ at: Date, _ cookie: String, _ linkPreviews: Bool) async throws -> SubstackDraft
    let now: @Sendable () -> Date
    let limiter: ScheduleLimiter

    static func live() -> StackMirrorToolbox {
        let client = SubstackAPIClient()
        return StackMirrorToolbox(
            loadState: { try PersistenceService().load() },
            sessionCookie: { try KeychainService().read(.substackSessionCookie) },
            fetchDrafts: { cookie in try await client.drafts(sessionCookie: cookie) },
            schedule: { text, at, cookie, linkPreviews in
                let attachments = linkPreviews ? await client.linkPreviewAttachments(for: text, sessionCookie: cookie) : []
                return try await client.scheduleNote(text: text, at: at, sessionCookie: cookie, attachmentIDs: attachments)
            },
            now: { Date.now },
            limiter: ScheduleLimiter(limit: schedulesPerSession)
        )
    }

    func tools() async -> [MCPTool] {
        guard (try? loadState().configuration.mcpEnabled) == true else { return [] }
        return Self.catalog
    }

    func call(_ name: String, arguments: [String: JSONValue]) async -> MCPToolResult {
        let state: PersistedState
        do {
            state = try loadState()
        } catch {
            return .failure("StackMirror could not read its saved state: \(error.localizedDescription)")
        }
        guard state.configuration.mcpEnabled else { return .failure(Self.disabledMessage) }

        do {
            switch name {
            case "list_scheduled_notes": return try await listScheduled(arguments)
            case "schedule_note": return try await scheduleNote(arguments, configuration: state.configuration)
            case "recent_note_stats": return try noteStats(arguments, notes: state.notes)
            default: return .failure("Unknown tool: \(name)")
            }
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    // MARK: - Tools

    private func listScheduled(_ arguments: [String: JSONValue]) async throws -> MCPToolResult {
        let from = try optionalDate(arguments, "from") ?? now()
        let to = try optionalDate(arguments, "to") ?? .distantFuture
        let drafts = try await fetchDrafts(try cookie())
            .filter { draft in draft.triggerAt.map { $0 >= from && $0 <= to } ?? false }
            .sorted { $0.triggerAt! < $1.triggerAt! }
        let items: [JSONValue] = drafts.map { draft in
            ["id": .int(draft.id), "scheduled_at": .string(MCPDates.format(draft.triggerAt!)), "text": .string(draft.body ?? "")]
        }
        return .ok(try json(["count": .int(items.count), "scheduled_notes": .array(items)]))
    }

    private func scheduleNote(_ arguments: [String: JSONValue], configuration: AppConfiguration) async throws -> MCPToolResult {
        let text = arguments["text"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return .failure("`text` is required.") }
        guard let rawTime = arguments["at"]?.stringValue else { return .failure("`at` is required, as ISO 8601 with a timezone offset.") }
        guard let at = MCPDates.parse(rawTime) else {
            return .failure("`at` must be ISO 8601 with a timezone offset, for example 2026-11-13T09:00:00-05:00.")
        }
        guard at > now().addingTimeInterval(60) else { return .failure("`at` must be at least one minute in the future.") }
        guard await limiter.take() else {
            return .failure("This MCP session already scheduled \(Self.schedulesPerSession) Notes. Restart the client to schedule more.")
        }

        let transformed = ContentTransformer.transform(text, configuration: configuration)
        let draft = try await schedule(transformed, at, try cookie(), configuration.includeLinkPreviews)
        return .ok(try json([
            "id": .int(draft.id),
            "scheduled_at": .string(MCPDates.format(draft.triggerAt ?? at)),
            "text": .string(draft.body ?? transformed)
        ]))
    }

    private func noteStats(_ arguments: [String: JSONValue], notes: [SubstackNote]) throws -> MCPToolResult {
        let limit = min(max(arguments["limit"]?.intValue ?? 10, 1), 50)
        let recent = notes.sorted { $0.date > $1.date }.prefix(limit)
        let items: [JSONValue] = recent.map { note in
            [
                "id": .int(note.id),
                "published_at": .string(MCPDates.format(note.date)),
                "text": .string(note.body),
                "reactions": .int(note.reactionCount),
                "restacks": .int(note.restacks),
                "replies": .int(note.childrenCount)
            ]
        }
        return .ok(try json([
            "note": "From StackMirror's last weekly scan. Open the app to refresh.",
            "notes": .array(items)
        ]))
    }

    // MARK: - Helpers

    private func cookie() throws -> String {
        let value = try sessionCookie()
        guard !value.isEmpty else { throw APIClientError.missingCredential("Substack session. Connect Substack in StackMirror Settings") }
        return value
    }

    private func optionalDate(_ arguments: [String: JSONValue], _ key: String) throws -> Date? {
        guard let raw = arguments[key]?.stringValue else { return nil }
        guard let date = MCPDates.parse(raw) else { throw MCPArgumentError(message: "`\(key)` must be ISO 8601 with a timezone offset.") }
        return date
    }

    private func json(_ value: JSONValue) throws -> String {
        String(decoding: try value.encoded(pretty: true), as: UTF8.self)
    }

    static let catalog: [MCPTool] = [
        MCPTool(
            name: "list_scheduled_notes",
            title: "List scheduled Substack Notes",
            description: "Lists Notes scheduled on Substack, live from the user's account, sorted by time. Defaults to everything from now on.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "from": ["type": "string", "description": "ISO 8601 start, with timezone offset. Defaults to now."],
                    "to": ["type": "string", "description": "ISO 8601 end, with timezone offset. Optional."]
                ]
            ],
            readOnly: true
        ),
        MCPTool(
            name: "schedule_note",
            title: "Schedule a Substack Note",
            description: "Schedules a Note on the user's Substack as a native scheduled draft. It publishes publicly at `at`. Confirm the exact text and time with the user first. StackMirror's prefix, suffix, and link-preview settings are applied.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "text": ["type": "string", "description": "The Note text."],
                    "at": ["type": "string", "description": "When to publish: ISO 8601 with timezone offset, at least one minute in the future."]
                ],
                "required": ["text", "at"]
            ],
            readOnly: false
        ),
        MCPTool(
            name: "recent_note_stats",
            title: "Recent Note engagement",
            description: "Reactions, restacks, and replies on the user's recent Notes, from StackMirror's last scan. Useful for picking topics and times.",
            inputSchema: [
                "type": "object",
                "properties": [
                    "limit": ["type": "integer", "minimum": 1, "maximum": 50, "description": "How many Notes, newest first. Default 10."]
                ]
            ],
            readOnly: true
        )
    ]
}

struct MCPArgumentError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum MCPDates {
    static func parse(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    /// ISO 8601 in the Mac's own timezone, so agents see the user's local times.
    static func format(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}
