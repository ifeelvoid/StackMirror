import Foundation

/// Runs StackMirror as a stdio MCP server: one JSON-RPC message per line in, one per line out.
/// It never starts the SwiftUI app, so no window or Dock icon appears.
enum MCPStdio {
    static let flag = "--mcp"

    static func run() async {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let server = MCPServer(toolbox: StackMirrorToolbox.live(), version: version)
        do {
            for try await line in FileHandle.standardInput.bytes.lines {
                guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                if let response = await server.handle(line) {
                    FileHandle.standardOutput.write(Data((response + "\n").utf8))
                }
            }
        } catch {
            FileHandle.standardError.write(Data("stackmirror-mcp: stdin closed with error: \(error.localizedDescription)\n".utf8))
        }
    }
}

@main
enum StackMirrorMain {
    static func main() {
        if CommandLine.arguments.contains(MCPStdio.flag) {
            Task {
                await MCPStdio.run()
                exit(0)
            }
            dispatchMain()
        } else {
            MainActor.assumeIsolated { StackMirrorApp.main() }
        }
    }
}
