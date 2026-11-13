import AppKit
import SwiftUI

struct MCPSettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var status = ""
    @State private var succeeded = false
    @State private var installedInClaude = false

    private let setup = MCPClientSetup()

    var body: some View {
        Form {
            Section {
                Toggle("Enable MCP server", isOn: Binding(
                    get: { store.configuration.mcpEnabled },
                    set: { setEnabled($0) }
                ))
                Text("Lets AI assistants like Claude list your scheduled Notes, see recent engagement, and schedule new Notes. They can't publish immediately, edit, or delete. Turning this off stops all tool calls right away.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("AI assistants (MCP)")
            }

            Section("Connect a client") {
                HStack {
                    Button(installedInClaude ? "Update in Claude Desktop" : "Add to Claude Desktop") { installInClaude() }
                    Spacer()
                    if installedInClaude {
                        Label("Added", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                copyRow("Claude Code", value: setup.claudeCodeCommand, label: "Copy Command")
                copyRow("Cursor, Windsurf, and other clients", value: setup.genericSnippet, label: "Copy JSON")
                if !setup.isInApplications {
                    Label("Move StackMirror to Applications first. Clients launch it from this path, so moving the app later breaks the connection.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text(setup.executablePath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if !status.isEmpty {
                Label(status, systemImage: succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(succeeded ? .green : .red)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            status = ""
            installedInClaude = setup.isInstalledInClaudeDesktop()
        }
    }

    private func copyRow(_ title: String, value: String, label: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button(label) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
                report("Copied the \(title) setup.", ok: true)
            }
        }
    }

    private func setEnabled(_ enabled: Bool) {
        let previous = store.configuration.mcpEnabled
        store.configuration.mcpEnabled = enabled
        do {
            // Saved immediately: the MCP process reads this switch on every request.
            try store.saveConfiguration()
            report(enabled ? "MCP server enabled." : "MCP server disabled.", ok: true)
        } catch {
            store.configuration.mcpEnabled = previous
            report(error.localizedDescription, ok: false)
        }
    }

    private func installInClaude() {
        do {
            try setup.installInClaudeDesktop()
            installedInClaude = true
            report("Added to Claude Desktop. Quit and reopen Claude to load it.", ok: true)
        } catch {
            report(error.localizedDescription, ok: false)
        }
    }

    private func report(_ message: String, ok: Bool) {
        status = message
        succeeded = ok
    }
}
