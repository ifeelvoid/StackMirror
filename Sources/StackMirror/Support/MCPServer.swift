import Foundation

/// One MCP tool as advertised in `tools/list`.
struct MCPTool: Sendable {
    let name: String
    let title: String
    let description: String
    let inputSchema: JSONValue
    let readOnly: Bool

    var json: JSONValue {
        [
            "name": .string(name),
            "title": .string(title),
            "description": .string(description),
            "inputSchema": inputSchema,
            "annotations": [
                "title": .string(title),
                "readOnlyHint": .bool(readOnly),
                "destructiveHint": false,
                "idempotentHint": .bool(readOnly),
                "openWorldHint": true
            ]
        ]
    }
}

struct MCPToolResult: Equatable, Sendable {
    let text: String
    let isError: Bool

    static func ok(_ text: String) -> MCPToolResult { MCPToolResult(text: text, isError: false) }
    static func failure(_ text: String) -> MCPToolResult { MCPToolResult(text: text, isError: true) }
}

protocol MCPToolbox: Sendable {
    func tools() async -> [MCPTool]
    func call(_ name: String, arguments: [String: JSONValue]) async -> MCPToolResult
}

/// JSON-RPC 2.0 handling for the subset of MCP that StackMirror serves: tools over stdio.
struct MCPServer: Sendable {
    static let supportedProtocolVersions = ["2025-06-18", "2025-03-26", "2024-11-05"]

    let toolbox: any MCPToolbox
    let version: String

    /// Handles one newline-delimited message. Returns the response line, or nil for notifications.
    func handle(_ line: String) async -> String? {
        guard let message = try? JSONValue.decode(Data(line.utf8)), message.objectValue != nil else {
            return encode(errorResponse(id: .null, code: -32700, message: "Parse error"))
        }
        guard let method = message["method"]?.stringValue else {
            // Responses to server requests are not expected; ignore them.
            return message["id"] == nil ? nil : encode(errorResponse(id: message["id"] ?? .null, code: -32600, message: "Invalid request"))
        }
        guard let id = message["id"] else { return nil }

        let params = message["params"]?.objectValue ?? [:]
        let response: JSONValue
        switch method {
        case "initialize":
            response = result(id: id, initializeResult(requested: params["protocolVersion"]?.stringValue))
        case "ping":
            response = result(id: id, [:])
        case "tools/list":
            let tools = await toolbox.tools()
            response = result(id: id, ["tools": .array(tools.map(\.json))])
        case "tools/call":
            guard let name = params["name"]?.stringValue else {
                response = errorResponse(id: id, code: -32602, message: "Missing tool name")
                break
            }
            let outcome = await toolbox.call(name, arguments: params["arguments"]?.objectValue ?? [:])
            response = result(id: id, [
                "content": [["type": "text", "text": .string(outcome.text)]],
                "isError": .bool(outcome.isError)
            ])
        default:
            response = errorResponse(id: id, code: -32601, message: "Method not found: \(method)")
        }
        return encode(response)
    }

    private func initializeResult(requested: String?) -> JSONValue {
        let version = requested.flatMap { Self.supportedProtocolVersions.contains($0) ? $0 : nil }
            ?? Self.supportedProtocolVersions[0]
        return [
            "protocolVersion": .string(version),
            "capabilities": ["tools": ["listChanged": false]],
            "serverInfo": ["name": "stackmirror", "title": "StackMirror", "version": .string(self.version)],
            "instructions": "Schedules Substack Notes through the StackMirror Mac app. Scheduled Notes publish publicly at their time; confirm text and time with the user before calling schedule_note. Times are ISO 8601 with a timezone offset."
        ]
    }

    private func result(id: JSONValue, _ value: JSONValue) -> JSONValue {
        ["jsonrpc": "2.0", "id": id, "result": value]
    }

    private func errorResponse(id: JSONValue, code: Int, message: String) -> JSONValue {
        ["jsonrpc": "2.0", "id": id, "error": ["code": .int(code), "message": .string(message)]]
    }

    private func encode(_ value: JSONValue) -> String {
        guard let data = try? value.encoded(), let line = String(data: data, encoding: .utf8) else {
            return #"{"jsonrpc":"2.0","id":null,"error":{"code":-32603,"message":"Internal error"}}"#
        }
        return line
    }
}
