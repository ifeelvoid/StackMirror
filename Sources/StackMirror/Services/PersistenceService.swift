import Foundation

struct PersistenceService: Sendable {
    private let fileURL: URL

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        if let fileURL { self.fileURL = fileURL; return }
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.fileURL = base.appendingPathComponent("StackMirror/state.json")
    }

    func load() throws -> PersistedState {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder.apiDecoder.decode(PersistedState.self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return PersistedState()
        }
    }

    func save(_ state: PersistedState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let previous = try Data(contentsOf: fileURL)
            // Never overwrite unreadable publication history, even through a manual action.
            _ = try JSONDecoder.apiDecoder.decode(PersistedState.self, from: previous)
            let backup = fileURL.appendingPathExtension("backup")
            try previous.write(to: backup, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
        }
        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}
