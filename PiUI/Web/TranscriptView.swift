import AppKit
import SwiftUI
import WebKit

struct TranscriptView: NSViewRepresentable {
    let messages: [ChatMessage]
    let answer: (String, String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(answer: answer)
    }

    func makeNSView(context: Context) -> WKWebView {
        let settings = WKWebViewConfiguration()
        settings.userContentController.add(context.coordinator, name: "openLink")
        settings.userContentController.add(context.coordinator, name: "permission")

        let web = WKWebView(frame: .zero, configuration: settings)
        web.navigationDelegate = context.coordinator
        web.setValue(false, forKey: "drawsBackground")
        web.loadHTMLString(Self.page, baseURL: nil)

        context.coordinator.web = web
        return web
    }

    func updateNSView(_ web: WKWebView, context: Context) {
        context.coordinator.answer = answer
        context.coordinator.show(messages)
    }

    static let page: String = {
        let css = bundled("transcript", "css")
        let marked = bundled("marked.min", "js")
        let highlight = bundled("highlight.min", "js")
        let script = bundled("transcript", "js")
        return """
        <!doctype html>
        <html><head><meta charset="utf-8">
        <style>\(Stylesheet.rootVariables)</style>
        <style>\(css)</style>
        </head><body><div id="log"></div>
        <script>\(marked)</script>
        <script>\(highlight)</script>
        <script>\(script)</script>
        </body></html>
        """
    }()

    private static func bundled(_ name: String, _ ext: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return text
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var web: WKWebView?
        var answer: (String, String) -> Void
        private var ready = false
        private var pending: [ChatMessage]?

        init(answer: @escaping (String, String) -> Void) {
            self.answer = answer
        }

        func webView(_ web: WKWebView, didFinish navigation: WKNavigation!) {
            ready = true
            if let pending {
                show(pending)
                self.pending = nil
            }
        }

        func show(_ messages: [ChatMessage]) {
            guard ready, let web else {
                pending = messages
                return
            }
            guard let data = try? JSONEncoder().encode(messages),
                  let json = String(data: data, encoding: .utf8)
            else { return }
            web.evaluateJavaScript("piui.render(\(json))")
        }

        func userContentController(
            _ controller: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if message.name == "permission",
               let payload = message.body as? [String: String],
               let id = payload["id"],
               let choice = payload["choice"] {
                answer(id, choice)
                return
            }

            guard message.name == "openLink",
                  let text = message.body as? String,
                  let url = URL(string: text),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https"
            else { return }
            NSWorkspace.shared.open(url)
        }
    }
}
