import Foundation

enum MCPClientSetupError: LocalizedError {
    case unreadableConfig(String)

    var errorDescription: String? {
        switch self {
        case .unreadableConfig(let path):
            "Claude Desktop's config at \(path) isn't valid JSON, so StackMirror left it untouched. Fix it or add the snippet by hand."
        }
    }
}

/// Connection details for MCP clients, plus a safe merge into Claude Desktop's config.
struct MCPClientSetup: Sendable {
    static let serverName = "stackmirror"

    let executablePath: String

    init(executablePath: String = Bundle.main.executableURL?.path ?? CommandLine.arguments[0]) {
        self.executablePath = executablePath
    }

    var isInApplications: Bool {
        executablePath.hasPrefix("/Applications/") || executablePath.hasPrefix(NSHomeDirectory() + "/Applications/")
    }

    var serverEntry: JSONValue {
        ["command": .string(executablePath), "args": [.string(MCPStdio.flag)]]
    }

    var claudeCodeCommand: String {
        "claude mcp add --scope user \(Self.serverName) -- \(shellQuoted(executablePath)) \(MCPStdio.flag)"
    }

    var genericSnippet: String {
        let config: JSONValue = ["mcpServers": .object([Self.serverName: serverEntry])]
        return (try? String(decoding: config.encoded(pretty: true), as: UTF8.self)) ?? ""
    }

    /// Adds or replaces only the `stackmirror` server, keeping every other key in the config.
    func merged(intoClaudeConfig existing: Data?) throws -> JSONValue {
        var root: [String: JSONValue] = [:]
        if let existing, !existing.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) {
            guard let object = (try? JSONValue.decode(existing))?.objectValue else {
                throw MCPClientSetupError.unreadableConfig("claude_desktop_config.json")
            }
            root = object
        }
        var servers = root["mcpServers"]?.objectValue ?? [:]
        servers[Self.serverName] = serverEntry
        root["mcpServers"] = .object(servers)
        return .object(root)
    }

    static var claudeDesktopConfigURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude/claude_desktop_config.json")
    }

    /// Writes the merged config after backing up the current file next to it.
    func installInClaudeDesktop(configURL: URL = Self.claudeDesktopConfigURL) throws {
        let fileManager = FileManager.default
        let existing = fileManager.fileExists(atPath: configURL.path) ? try Data(contentsOf: configURL) : nil
        let config: JSONValue
        do {
            config = try merged(intoClaudeConfig: existing)
        } catch MCPClientSetupError.unreadableConfig {
            throw MCPClientSetupError.unreadableConfig(configURL.path)
        }
        try fileManager.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let existing {
            try existing.write(to: configURL.appendingPathExtension("stackmirror-backup"), options: .atomic)
        }
        try config.encoded(pretty: true).write(to: configURL, options: .atomic)
    }

    func isInstalledInClaudeDesktop(configURL: URL = Self.claudeDesktopConfigURL) -> Bool {
        guard let data = try? Data(contentsOf: configURL),
              let entry = (try? JSONValue.decode(data))?["mcpServers"]?[Self.serverName] else { return false }
        return entry == serverEntry
    }

    private func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
