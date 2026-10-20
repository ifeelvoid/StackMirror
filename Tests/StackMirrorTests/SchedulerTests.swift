import XCTest
@testable import StackMirror

final class SchedulerTests: XCTestCase {
    private func gregorian(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    func testMonthCellsPadToWholeWeeksFromTheLocaleFirstWeekday() {
        // October 2026 starts on a Thursday and has 31 days.
        let sundayFirst = CalendarGrid(calendar: gregorian(firstWeekday: 1)).cells(forMonthContaining: date("2026-10-15T16:00:00Z"))
        XCTAssertEqual(sundayFirst.count % 7, 0)
        XCTAssertEqual(sundayFirst.prefix(4).filter { $0 == nil }.count, 4)
        XCTAssertNotNil(sundayFirst[4])
        XCTAssertEqual(sundayFirst.compactMap { $0 }.count, 31)

        let mondayFirst = CalendarGrid(calendar: gregorian(firstWeekday: 2)).cells(forMonthContaining: date("2026-10-15T16:00:00Z"))
        XCTAssertEqual(mondayFirst.prefix(3).filter { $0 == nil }.count, 3)
        XCTAssertNotNil(mondayFirst[3])
        XCTAssertEqual(CalendarGrid(calendar: gregorian(firstWeekday: 2)).weekdaySymbols.first, "M")
    }

    func testDraftsGroupByLocalDaySortedByTimeAndUnscheduledAreExcluded() {
        let calendar = gregorian(firstWeekday: 1)
        let grid = CalendarGrid(calendar: calendar)
        // 03:30 UTC on Oct 21 is still Oct 20 in New York.
        let lateEvening = SubstackDraft(id: 1, body: "late", triggerAt: date("2026-10-21T03:30:00Z"), status: nil)
        let morning = SubstackDraft(id: 2, body: "morning", triggerAt: date("2026-10-20T13:00:00Z"), status: nil)
        let unscheduled = SubstackDraft(id: 3, body: "draft", triggerAt: nil, status: nil)

        let byDay = grid.draftsByDay([lateEvening, morning, unscheduled])
        let october20 = calendar.startOfDay(for: date("2026-10-20T16:00:00Z"))

        XCTAssertEqual(byDay.keys.count, 1)
        XCTAssertEqual(byDay[october20]?.map(\.id), [2, 1])
    }

    func testDraftDecodesSubstackTriggerAt() throws {
        let json = #"{"id": 991, "body": "Scheduled note", "trigger_at": "2026-10-21T15:30:00.000Z", "status": "scheduled"}"#
        let draft = try JSONDecoder.apiDecoder.decode(SubstackDraft.self, from: Data(json.utf8))

        XCTAssertEqual(draft.triggerAt, date("2026-10-21T15:30:00Z"))
        XCTAssertEqual(draft.body, "Scheduled note")
    }

    func testAPIDecoderAcceptsFractionalAndStandardISO8601Dates() throws {
        let fractional = try JSONDecoder.apiDecoder.decode(Date.self, from: Data("\"2026-10-12T12:00:00.000Z\"".utf8))
        let standard = try JSONDecoder.apiDecoder.decode(Date.self, from: Data("\"2026-10-12T12:00:00Z\"".utf8))

        XCTAssertEqual(fractional, standard)
    }

    func testPreSchedulerStateStillLoadsAndKeepsSubstackData() throws {
        // Shape written by the mirroring release: source posts, mirror records, and mirror settings.
        let legacy = """
        {
          "configuration": {"marker": "[substack]", "requireMarker": true, "enabled": true, "postizEnabled": true,
                            "deliveryMode": "substackScheduler", "includeLinkPreviews": false,
                            "template": {"prefix": "kept", "suffix": "", "removePhrases": "", "replaceLineBreaks": false}},
          "posts": [{"buffer": {"_0": {"id": "1", "text": "x", "status": "scheduled", "channelId": "c"}}}],
          "records": [{"id": "6F9619FF-8B86-D011-B42D-00C04FC964FF", "sourcePostID": "buffer:1", "text": "x",
                       "state": "published", "detail": "d", "updatedAt": "2026-10-01T00:00:00Z"}],
          "drafts": [{"id": 5, "body": "kept draft", "trigger_at": "2026-10-21T15:30:00Z"}],
          "notes": [], "replies": [], "subscriptions": [], "readingItems": []
        }
        """
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("state.json")
        try Data(legacy.utf8).write(to: file)

        let state = try PersistenceService(fileURL: file).load()

        XCTAssertEqual(state.configuration.template.prefix, "kept")
        XCTAssertFalse(state.configuration.includeLinkPreviews)
        XCTAssertEqual(state.drafts.map(\.id), [5])
    }
}
