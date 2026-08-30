import Foundation
import Testing

@testable import PiUI

@MainActor
struct TranscriptPageTests {
    /// Guards against the silent failure where the web assets are not copied into the
    /// bundle: the page still builds, but renders blank.
    @Test func inlinesTheVendoredMarkdownParser() {
        #expect(TranscriptPageTests.page.contains("marked"))
        #expect(TranscriptPageTests.page.count > 40_000)
    }

    @Test func inlinesTheStylesheet() {
        #expect(TranscriptPageTests.page.contains(".msg"))
        #expect(TranscriptPageTests.page.contains("prefers-color-scheme"))
    }

    @Test func inlinesTheRenderScript() {
        #expect(TranscriptPageTests.page.contains("window.piui"))
        #expect(TranscriptPageTests.page.contains("marked.parse"))
    }

    @Test func buildsAWholeDocument() {
        #expect(TranscriptPageTests.page.hasPrefix("<!doctype html>"))
        #expect(TranscriptPageTests.page.contains(#"<div id="log">"#))
    }

    @Test func messagesEncodeForTheBridge() throws {
        let messages = [
            ChatMessage(id: "a", kind: .user, text: "hello", done: true),
            ChatMessage(id: "b", kind: .assistant, text: "# hi", done: false),
        ]
        let data = try JSONEncoder().encode(messages)
        let json = String(decoding: data, as: UTF8.self)

        #expect(json.contains(#""kind":"user""#))
        #expect(json.contains(#""kind":"assistant""#))
        #expect(json.contains(#""done":false"#))
    }

    @Test func quotesSurviveEncoding() throws {
        let messages = [ChatMessage(id: "a", kind: .assistant, text: #"say "hi" </script>"#, done: true)]
        let data = try JSONEncoder().encode(messages)
        let json = String(decoding: data, as: UTF8.self)

        #expect(json.contains(#"\"hi\""#))
    }

    private static let page = TranscriptView.page
}
