import XCTest
@testable import StackMirror

final class PersistenceSafetyTests: XCTestCase {
    func testMissingStateIsFirstRunButCorruptionCannotBeLoadedOrOverwritten() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("state.json")
        let service = PersistenceService(fileURL: file)
        XCTAssertTrue(try service.load().drafts.isEmpty)
        let damaged = Data("not valid JSON".utf8)
        try damaged.write(to: file)
        XCTAssertThrowsError(try service.load())
        XCTAssertThrowsError(try service.save(PersistedState()))
        XCTAssertEqual(try Data(contentsOf: file), damaged)
    }

    func testSavedStateHasDecodableBackupAndRestoresWithoutLosingDrafts() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = folder.appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at: folder) }
        let service = PersistenceService(fileURL: file)
        var state = PersistedState()
        state.configuration.template.prefix = "preserved-prefix"
        state.drafts = [SubstackDraft(id: 7, body: "fixture", triggerAt: Date(timeIntervalSince1970: 1_800_000_000), status: "scheduled")]
        try service.save(state)
        let expected = try Data(contentsOf: file)
        state.configuration.template.prefix = "new-prefix"
        try service.save(state)
        let backup = file.appendingPathExtension("backup")
        XCTAssertEqual(try Data(contentsOf: backup), expected)
        try Data(contentsOf: backup).write(to: file, options: .atomic)
        XCTAssertEqual(try service.load().configuration.template.prefix, "preserved-prefix")
        XCTAssertEqual(try service.load().drafts.first?.id, 7)
        XCTAssertEqual(try service.load().drafts.first?.triggerAt, Date(timeIntervalSince1970: 1_800_000_000))
    }
}
