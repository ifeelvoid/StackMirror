import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var substackCookie = ""
    @State private var credentialStatus = ""
    @State private var settingsStatus = ""
    @State private var settingsSaveSucceeded = false
    @State private var showingSubstackSignIn = false

    var body: some View {
        TabView {
            Form {
                Section("Substack") {
                    HStack {
                        Button("Connect Substack…") {
                            showingSubstackSignIn = true
                        }
                        Spacer()
                        Text(store.hasSubstackSession ? "Connected" : "Not connected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    DisclosureGroup("Advanced: use an existing session cookie") {
                        SecureField("Substack session cookie", text: $substackCookie)
                        HStack {
                            Button("Save to Keychain") {
                                guard !substackCookie.isEmpty else { return }
                                do {
                                    try store.saveSubstackSession(substackCookie)
                                    substackCookie = ""
                                    credentialStatus = "Session saved in Keychain."
                                } catch {
                                    credentialStatus = error.localizedDescription
                                }
                            }
                            Spacer()
                            Text(credentialStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Notes") {
                    Toggle("Create link previews", isOn: $store.configuration.includeLinkPreviews)
                    TextField("Prefix", text: $store.configuration.template.prefix)
                    TextField("Suffix", text: $store.configuration.template.suffix)
                    TextField(
                        "Remove phrases, comma separated",
                        text: $store.configuration.template.removePhrases
                    )
                    Toggle(
                        "Normalize paragraph spacing",
                        isOn: $store.configuration.template.replaceLineBreaks
                    )
                }

                Section("Mac") {
                    Toggle("Launch at login", isOn: $store.configuration.launchAtLogin)
                    Toggle("Notify on failures", isOn: $store.configuration.notifyOnFailure)
                    Text("Scheduled Notes are held by Substack, so StackMirror does not need to run when they publish. Analytics, replies, and reading data scan once per week.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your session stays in this Mac's Keychain. Substack's Notes endpoints are undocumented.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !settingsStatus.isEmpty {
                            Label(
                                settingsStatus,
                                systemImage: settingsSaveSucceeded
                                    ? "checkmark.circle.fill"
                                    : "exclamationmark.triangle.fill"
                            )
                            .font(.caption.weight(.medium))
                            .foregroundStyle(settingsSaveSucceeded ? .green : .red)
                        }
                    }
                    Spacer()
                    Button("Save Settings") {
                        do {
                            try store.saveConfiguration()
                            settingsSaveSucceeded = true
                            settingsStatus = "Saved \(Date.now.formatted(date: .omitted, time: .shortened))."
                        } catch {
                            settingsSaveSucceeded = false
                            settingsStatus = error.localizedDescription
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gearshape") }

            MCPSettingsView()
                .tabItem { Label("AI Assistants", systemImage: "sparkles") }
        }
        .frame(width: 560, height: 520)
        .onAppear { settingsStatus = "" }
        .sheet(isPresented: $showingSubstackSignIn) {
            SubstackSignInView()
                .environmentObject(store)
        }
    }
}
