import SwiftUI
import WebKit

struct SubstackSignInView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @State private var status = "Sign in to Substack below."

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Connect Substack")
                        .font(.headline)
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
            }
            .padding()

            Divider()

            SubstackWebView { cookie in
                do {
                    try store.saveSubstackSession(cookie)
                    status = "Substack connected. You can close this window."
                    Task {
                        try? await Task.sleep(for: .milliseconds(700))
                        dismiss()
                    }
                } catch {
                    status = error.localizedDescription
                }
            }
        }
        .frame(minWidth: 760, minHeight: 680)
    }
}

private struct SubstackWebView: NSViewRepresentable {
    let onSessionCookie: @MainActor (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSessionCookie: onSessionCookie)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: URL(string: "https://substack.com/sign-in")!))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onSessionCookie: @MainActor (String) -> Void
        private var capturedCookie = false

        init(onSessionCookie: @escaping @MainActor (String) -> Void) {
            self.onSessionCookie = onSessionCookie
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !capturedCookie else { return }
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self,
                      let cookie = cookies.first(where: {
                          $0.name == "substack.sid" && $0.domain.contains("substack.com")
                      }),
                      !cookie.value.isEmpty else {
                    return
                }
                Task { @MainActor in
                    guard !self.capturedCookie else { return }
                    self.capturedCookie = true
                    self.onSessionCookie(cookie.value)
                }
            }
        }
    }
}
