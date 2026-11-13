import XCTest
@testable import StackMirror

final class MCPServerTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-11-12T16:00:00Z")!

    private actor Recorder {
        var scheduled: [(String, Date, Bool)] = []
        func add(_ text: String, _ at: Date, _ previews: Bool) { scheduled.append((text, at, previews)) }
    }

    private func toolbox(enabled: Bool, drafts: [SubstackDraft] = [], recorder: Recorder = Recorder(), limit: Int = 20) -> StackMirrorToolbox {
        var state = PersistedState()
        state.configuration.mcpEnabled = enabled
        state.configuration.template.prefix = "PRE "
        state.notes = [
            SubstackNote(id: 1, body: "old", date: now.addingTimeInterval(-7200), reactionCount: 1, restacks: 0, childrenCount: 0),
            SubstackNote(id: 2, body: "new", date: now.addingTimeInterval(-60), reactionCount: 5, restacks: 2, childrenCount: 1)
        ]
        let snapshot = state
        let fixedNow = now
        return StackMirrorToolbox(
            loadState: { snapshot },
            sessionCookie: { "cookie" },
            fetchDrafts: { _ in drafts },
            schedule: { text, at, _, previews in
                await recorder.add(text, at, previews)
                return SubstackDraft(id: 77, body: text, triggerAt: at, status: "scheduled")
            },
            now: { fixedNow },
            limiter: ScheduleLimiter(limit: limit)
        )
    }

    private func send(_ server: MCPServer, _ json: String) async throws -> JSONValue {
        let response = await server.handle(json)
        let line = try XCTUnwrap(response)
        return try JSONValue.decode(Data(line.utf8))
    }

    private func call(_ box: StackMirrorToolbox, _ name: String, _ args: JSONValue) async throws -> JSONValue {
        let server = MCPServer(toolbox: box, version: "test")
        let request: JSONValue = ["jsonrpc": "2.0", "id": 9, "method": "tools/call", "params": ["name": .string(name), "arguments": args]]
        return try await send(server, String(decoding: try request.encoded(), as: UTF8.self))["result"]!
    }

    private func text(_ result: JSONValue) -> String {
        guard case .array(let content)? = result["content"] else { return "" }
        return content.first?["text"]?.stringValue ?? ""
    }

    func testInitializeNegotiatesProtocolVersionAndEchoesID() async throws {
        let server = MCPServer(toolbox: toolbox(enabled: true), version: "1.1.0")
        let known = try await send(server, #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26"}}"#)
        XCTAssertEqual(known["id"], 1)
        XCTAssertEqual(known["result"]?["protocolVersion"], "2025-03-26")
        XCTAssertEqual(known["result"]?["serverInfo"]?["version"], "1.1.0")

        let unknown = try await send(server, #"{"jsonrpc":"2.0","id":"a","method":"initialize","params":{"protocolVersion":"2099-01-01"}}"#)
        XCTAssertEqual(unknown["id"], "a")
        XCTAssertEqual(unknown["result"]?["protocolVersion"], .string(MCPServer.supportedProtocolVersions[0]))
    }

    func testNotificationsGetNoReplyAndBadInputGetsJSONRPCErrors() async throws {
        let server = MCPServer(toolbox: toolbox(enabled: true), version: "t")
        let notification = await server.handle(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#)
        XCTAssertNil(notification)
        let parse = try await send(server, "not json")
        XCTAssertEqual(parse["error"]?["code"], -32700)
        let unknown = try await send(server, #"{"jsonrpc":"2.0","id":3,"method":"resources/list"}"#)
        XCTAssertEqual(unknown["error"]?["code"], -32601)
    }

    func testDisabledServerListsNoToolsAndRefusesCalls() async throws {
        let server = MCPServer(toolbox: toolbox(enabled: false), version: "t")
        let list = try await send(server, #"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#)
        XCTAssertEqual(list["result"]?["tools"], .array([]))

        let result = try await call(toolbox(enabled: false), "recent_note_stats", [:])
        XCTAssertEqual(result["isError"], true)
        XCTAssertEqual(text(result), StackMirrorToolbox.disabledMessage)
    }

    func testEnabledServerListsThreeToolsAndNoPublishNow() async throws {
        let server = MCPServer(toolbox: toolbox(enabled: true), version: "t")
        let list = try await send(server, #"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#)
        guard case .array(let tools)? = list["result"]?["tools"] else { return XCTFail("no tools") }
        XCTAssertEqual(tools.compactMap { $0["name"]?.stringValue }, ["list_scheduled_notes", "schedule_note", "recent_note_stats"])
    }

    func testScheduleNoteValidatesInputAndAppliesTemplate() async throws {
        let recorder = Recorder()
        let box = toolbox(enabled: true, recorder: recorder)

        let past = try await call(box, "schedule_note", ["text": "hi", "at": "2026-11-12T10:00:00-05:00"])
        XCTAssertEqual(past["isError"], true)
        let noZone = try await call(box, "schedule_note", ["text": "hi", "at": "2026-11-13T09:00:00"])
        XCTAssertEqual(noZone["isError"], true)
        let empty = try await call(box, "schedule_note", ["text": "  ", "at": "2026-11-13T09:00:00-05:00"])
        XCTAssertEqual(empty["isError"], true)

        let ok = try await call(box, "schedule_note", ["text": "hello", "at": "2026-11-13T09:00:00-05:00"])
        XCTAssertEqual(ok["isError"], false)
        XCTAssertTrue(text(ok).contains("\"id\" : 77"))
        let scheduled = await recorder.scheduled
        XCTAssertEqual(scheduled.count, 1)
        XCTAssertEqual(scheduled.first?.0, ContentTransformer.transform("hello", configuration: { var c = AppConfiguration(); c.template.prefix = "PRE "; return c }()))
        XCTAssertTrue(scheduled.first?.0.hasPrefix("PRE") == true)
        XCTAssertEqual(scheduled.first?.1, ISO8601DateFormatter().date(from: "2026-11-13T14:00:00Z"))
    }

    func testScheduleNoteStopsAtTheSessionCap() async throws {
        let box = toolbox(enabled: true, limit: 1)
        let first = try await call(box, "schedule_note", ["text": "one", "at": "2026-11-13T09:00:00Z"])
        let second = try await call(box, "schedule_note", ["text": "two", "at": "2026-11-13T10:00:00Z"])
        XCTAssertEqual(first["isError"], false)
        XCTAssertEqual(second["isError"], true)
    }

    func testListScheduledNotesFiltersPastAndUnscheduledAndSorts() async throws {
        let drafts = [
            SubstackDraft(id: 3, body: "later", triggerAt: now.addingTimeInterval(7200), status: nil),
            SubstackDraft(id: 1, body: "past", triggerAt: now.addingTimeInterval(-60), status: nil),
            SubstackDraft(id: 2, body: "soon", triggerAt: now.addingTimeInterval(600), status: nil),
            SubstackDraft(id: 4, body: "unscheduled", triggerAt: nil, status: nil)
        ]
        let result = try await call(toolbox(enabled: true, drafts: drafts), "list_scheduled_notes", [:])
        let payload = try JSONValue.decode(Data(text(result).utf8))
        guard case .array(let items)? = payload["scheduled_notes"] else { return XCTFail("no items") }
        XCTAssertEqual(items.compactMap { $0["id"]?.intValue }, [2, 3])
    }

    func testRecentNoteStatsAreNewestFirstAndClamped() async throws {
        let result = try await call(toolbox(enabled: true), "recent_note_stats", ["limit": 1])
        let payload = try JSONValue.decode(Data(text(result).utf8))
        guard case .array(let notes)? = payload["notes"] else { return XCTFail("no notes") }
        XCTAssertEqual(notes.compactMap { $0["id"]?.intValue }, [2])
        XCTAssertEqual(notes.first?["reactions"], 5)
    }
}

final class MCPClientSetupTests: XCTestCase {
    private let setup = MCPClientSetup(executablePath: "/Applications/StackMirror.app/Contents/MacOS/StackMirror")

    func testMergeKeepsOtherServersAndKeys() throws {
        let existing = #"{"globalShortcut":"Cmd+Space","mcpServers":{"other":{"command":"x"},"stackmirror":{"command":"old"}}}"#
        let merged = try setup.merged(intoClaudeConfig: Data(existing.utf8))
        XCTAssertEqual(merged["globalShortcut"], "Cmd+Space")
        XCTAssertEqual(merged["mcpServers"]?["other"]?["command"], "x")
        XCTAssertEqual(merged["mcpServers"]?["stackmirror"], setup.serverEntry)
        XCTAssertEqual(setup.serverEntry["args"], ["--mcp"])
    }

    func testMergeRefusesInvalidJSONButAcceptsMissingOrBlankFiles() throws {
        XCTAssertThrowsError(try setup.merged(intoClaudeConfig: Data("{ nope".utf8)))
        XCTAssertThrowsError(try setup.merged(intoClaudeConfig: Data("[1]".utf8)))
        XCTAssertNotNil(try setup.merged(intoClaudeConfig: nil)["mcpServers"]?["stackmirror"])
        XCTAssertNotNil(try setup.merged(intoClaudeConfig: Data(" \n".utf8))["mcpServers"]?["stackmirror"])
    }

    func testInstallBacksUpAndLeavesUnreadableConfigUntouched() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let config = folder.appendingPathComponent("claude_desktop_config.json")

        try Data(#"{"mcpServers":{"other":{"command":"x"}}}"#.utf8).write(to: config)
        try setup.installInClaudeDesktop(configURL: config)
        XCTAssertTrue(setup.isInstalledInClaudeDesktop(configURL: config))
        let backup = try String(contentsOf: config.appendingPathExtension("stackmirror-backup"), encoding: .utf8)
        XCTAssertTrue(backup.contains("other"))

        let broken = Data("{ broken".utf8)
        try broken.write(to: config)
        XCTAssertThrowsError(try setup.installInClaudeDesktop(configURL: config))
        XCTAssertEqual(try Data(contentsOf: config), broken)
    }

    func testClaudeCodeCommandQuotesThePath() {
        let spaced = MCPClientSetup(executablePath: "/Volumes/My Disk/StackMirror.app/Contents/MacOS/StackMirror")
        XCTAssertEqual(spaced.claudeCodeCommand,
                       "claude mcp add --scope user stackmirror -- '/Volumes/My Disk/StackMirror.app/Contents/MacOS/StackMirror' --mcp")
        XCTAssertFalse(spaced.isInApplications)
        XCTAssertTrue(setup.isInApplications)
    }

    func testOlderConfigurationsDecodeWithMCPOff() throws {
        let config = try JSONDecoder().decode(AppConfiguration.self, from: Data(#"{"includeLinkPreviews":true}"#.utf8))
        XCTAssertFalse(config.mcpEnabled)
    }
}
