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
        #expect(TranscriptPageTests.page.contains(":root {"))
    }

    /// Both themes ship in the one document, so the transcript follows the appearance
    /// without being rebuilt — the page is built once at launch.
    @Test func inlinesBothThemes() {
        #expect(TranscriptPageTests.page.contains("--color-bg: \(Theme.light.bg);"))
        #expect(TranscriptPageTests.page.contains("--color-bg: \(Theme.dark.bg);"))
        #expect(TranscriptPageTests.page.contains("@media (prefers-color-scheme: dark)"))
    }

    /// Tool cards open on request. A card that printed its whole output pushed the
    /// conversation off the screen — a `find` with five hits buried the reply.
    @Test func leavesToolCardsClosedUntilAsked() {
        let page = TranscriptPageTests.page
        // Opening it at build time was what made every card print itself in full.
        #expect(page.contains(#"card.className = "card";"#))
        #expect(page.contains("card.className = \"card\";\n        card.open = true;") == false)
        #expect(page.contains(#"<span class="toggle">"#))
        // A diff still opens itself, but only once, so a closed card stays closed.
        #expect(page.contains("card.dataset.shown"))
    }

    /// Opening one has to be visibly possible, or the output looks lost rather than folded.
    @Test func marksACardAsSomethingToOpen() {
        let page = TranscriptPageTests.page
        #expect(page.contains(".call .toggle::before"))
        #expect(page.contains("cursor: pointer"))
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
