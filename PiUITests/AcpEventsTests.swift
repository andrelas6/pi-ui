import Foundation
import Testing

@testable import PiUI

/// The JSON here is copied from a live `claude-agent-acp` run, not invented, so these
/// break if the adapter changes shape.
struct AcpEventsTests {
    private func update(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(
            JSONValue.self,
            from: Data(#"{"jsonrpc":"2.0","method":"session/update","params":{"update":\#(json)}}"#.utf8)
        )
    }

    private func kinds(_ events: [JSONValue]) -> [String] {
        events.map { event in
            event["assistantMessageEvent"]?["type"]?.string ?? event["type"]?.string ?? "?"
        }
    }

    @Test func opensAMessageOnceAndThenOnlyAppends() throws {
        var events = AcpEvents()
        var made: [JSONValue] = []
        for piece in ["Hel", "lo"] {
            made += events.translate(try update(
                #"{"sessionUpdate":"agent_message_chunk","messageId":"m1","content":{"type":"text","text":"\#(piece)"}}"#
            ))
        }

        #expect(kinds(made) == ["text_start", "text_delta", "text_delta"])
        #expect(made[1]["assistantMessageEvent"]?["delta"]?.string == "Hel")
        #expect(made[2]["assistantMessageEvent"]?["delta"]?.string == "lo")
    }

    /// A second assistant message must be its own bubble, not appended to the first.
    @Test func startsAFreshMessageWhenTheIdChanges() throws {
        var events = AcpEvents()
        _ = events.translate(try update(
            #"{"sessionUpdate":"agent_message_chunk","messageId":"m1","content":{"type":"text","text":"one"}}"#
        ))
        let made = events.translate(try update(
            #"{"sessionUpdate":"agent_message_chunk","messageId":"m2","content":{"type":"text","text":"two"}}"#
        ))

        #expect(kinds(made) == ["text_end", "text_start", "text_delta"])
    }

    @Test func ignoresAnEmptyChunk() throws {
        var events = AcpEvents()
        let made = events.translate(try update(
            #"{"sessionUpdate":"agent_message_chunk","messageId":"m1","content":{"type":"text","text":""}}"#
        ))
        #expect(made.isEmpty)
    }

    /// The ACP title is a sentence — "Write hello.txt" — which reads badly as a tool name.
    @Test func namesTheToolFromClaudesOwnMetadata() throws {
        var events = AcpEvents()
        let made = events.translate(try update(
            #"""
            {"_meta":{"claudeCode":{"toolName":"Write"}},"toolCallId":"t1",
             "sessionUpdate":"tool_call","status":"pending","title":"Write hello.txt",
             "rawInput":{"file_path":"/tmp/hello.txt"}}
            """#
        ))

        #expect(kinds(made) == ["tool_execution_start"])
        #expect(made[0]["toolName"]?.string == "Write")
        #expect(made[0]["toolCallId"]?.string == "t1")
        #expect(made[0]["args"]?["file_path"]?.string == "/tmp/hello.txt")
    }

    /// A call is announced before its arguments are known. Showing `{}` on the card was
    /// the bug this guards: the real command only arrives on the updates that follow.
    @Test func saysNothingAboutArgumentsItDoesNotHaveYet() throws {
        var events = AcpEvents()
        let made = events.translate(try update(
            #"""
            {"_meta":{"claudeCode":{"toolName":"Bash"}},"toolCallId":"t1",
             "sessionUpdate":"tool_call","rawInput":{},"status":"pending","title":"Terminal"}
            """#
        ))

        #expect(made[0]["args"] == nil)
    }

    @Test func carriesArgumentsThatArriveLater() throws {
        var events = AcpEvents()
        let made = events.translate(try update(
            #"""
            {"toolCallId":"t1","sessionUpdate":"tool_call_update",
             "rawInput":{"command":"echo hello-from-bash"},"title":"echo hello-from-bash"}
            """#
        ))

        #expect(kinds(made) == ["tool_execution_update"])
        #expect(made[0]["args"]?["command"]?.string == "echo hello-from-bash")
    }

    /// The final update drops `rawInput` entirely; passing that on would wipe the command.
    @Test func doesNotClaimArgumentsTheLastUpdateOmits() throws {
        var events = AcpEvents()
        let made = events.translate(try update(
            #"{"toolCallId":"t1","sessionUpdate":"tool_call_update","status":"completed"}"#
        ))

        #expect(kinds(made) == ["tool_execution_end"])
        #expect(made[0]["args"] == nil)
    }

    @Test func fallsBackToTheTitleWhenThereIsNoToolName() throws {
        var events = AcpEvents()
        let made = events.translate(try update(
            #"{"toolCallId":"t1","sessionUpdate":"tool_call","status":"pending","title":"Searching"}"#
        ))
        #expect(made[0]["toolName"]?.string == "Searching")
    }

    /// A tool starting mid-sentence has to close the open message, or its text keeps
    /// growing behind the card.
    @Test func closesAnOpenMessageWhenAToolStarts() throws {
        var events = AcpEvents()
        _ = events.translate(try update(
            #"{"sessionUpdate":"agent_message_chunk","messageId":"m1","content":{"type":"text","text":"working"}}"#
        ))
        let made = events.translate(try update(
            #"{"toolCallId":"t1","sessionUpdate":"tool_call","status":"pending","title":"Read"}"#
        ))

        #expect(kinds(made) == ["text_end", "tool_execution_start"])
    }

    @Test func reportsProgressWhileAToolRuns() throws {
        var events = AcpEvents()
        let made = events.translate(try update(
            #"""
            {"toolCallId":"t1","sessionUpdate":"tool_call_update","status":"in_progress",
             "content":[{"type":"content","content":{"type":"text","text":"reading…"}}]}
            """#
        ))

        #expect(kinds(made) == ["tool_execution_update"])
        #expect(made[0]["partialResult"]?.contentText == "reading…")
    }

    /// `structuredPatch` lines are already unified-diff format, which is what the
    /// transcript renders and `DiffSummary` counts.
    @Test func takesTheDiffFromTheStructuredPatch() throws {
        var events = AcpEvents()
        let made = events.translate(try update(
            #"""
            {"_meta":{"claudeCode":{"toolName":"Edit","toolResponse":{"structuredPatch":
             [{"oldStart":1,"oldLines":4,"newStart":1,"newLines":4,
               "lines":[" alpha","-bravo","+BRAVO"," charlie"]}]}}},
             "toolCallId":"t1","sessionUpdate":"tool_call_update","status":"completed"}
            """#
        ))

        #expect(kinds(made) == ["tool_execution_end"])
        let diff = made[0]["result"]?["details"]?["diff"]?.string ?? ""
        #expect(diff == " alpha\n-bravo\n+BRAVO\n charlie")
        #expect(DiffSummary.text(diff) == "+1 −1")
        #expect(made[0]["isError"]?.bool == false)
    }

    /// The diff arrives while the call is still running; the update that says "completed"
    /// carries none. Building it only at the end left every edit without a diff.
    @Test func carriesADiffThatArrivesBeforeTheCallEnds() throws {
        var events = AcpEvents()
        let made = events.translate(try update(
            #"""
            {"_meta":{"claudeCode":{"toolResponse":{"structuredPatch":
             [{"lines":[" alpha","-bravo","+BRAVO"]}]}}},
             "toolCallId":"t1","sessionUpdate":"tool_call_update"}
            """#
        ))

        #expect(kinds(made) == ["tool_execution_update"])
        #expect(made[0]["diff"]?.string == " alpha\n-bravo\n+BRAVO")
    }

    @Test func saysNothingAboutADiffOnAnOrdinaryProgressUpdate() throws {
        var events = AcpEvents()
        let made = events.translate(try update(
            #"{"toolCallId":"t1","sessionUpdate":"tool_call_update","status":"in_progress"}"#
        ))
        #expect(made[0]["diff"] == nil)
    }

    /// Without Claude's metadata there is still the portable ACP diff block.
    @Test func fallsBackToTheAcpDiffBlock() throws {
        var events = AcpEvents()
        let made = events.translate(try update(
            #"""
            {"toolCallId":"t1","sessionUpdate":"tool_call_update","status":"completed",
             "content":[{"type":"diff","path":"a.txt","oldText":"one","newText":"two"}]}
            """#
        ))

        #expect(made[0]["result"]?["details"]?["diff"]?.string == "-one\n+two")
    }

    /// A `Write` that creates a file sends an empty `structuredPatch` and a block with no
    /// `oldText` — the whole file is an addition.
    @Test func showsACreatedFileAsAllAdditions() throws {
        var events = AcpEvents()
        let made = events.translate(try update(
            #"""
            {"_meta":{"claudeCode":{"toolResponse":{"structuredPatch":[]}}},
             "toolCallId":"t1","sessionUpdate":"tool_call_update",
             "content":[{"type":"diff","path":"new.txt","oldText":null,"newText":"one\ntwo\nthree\n"}]}
            """#
        ))

        // The trailing newline ends "three"; it must not add an empty "+" row.
        #expect(made[0]["diff"]?.string == "+one\n+two\n+three")
        #expect(DiffSummary.text(made[0]["diff"]?.string ?? "") == "+3 −0")
    }

    @Test func saysNothingAboutADiffThatChangedNothing() throws {
        var events = AcpEvents()
        let made = events.translate(try update(
            #"""
            {"toolCallId":"t1","sessionUpdate":"tool_call_update","status":"completed",
             "content":[{"type":"diff","path":"a.txt","oldText":"same","newText":"same"}]}
            """#
        ))
        #expect(made[0]["result"]?["details"]?["diff"]?.string == "")
    }

    @Test func marksAFailedToolAsAnError() throws {
        var events = AcpEvents()
        let made = events.translate(try update(
            #"{"toolCallId":"t1","sessionUpdate":"tool_call_update","status":"failed"}"#
        ))
        #expect(made[0]["isError"]?.bool == true)
    }

    /// Loading a session replays the user's turns; a live turn does not, which is why the
    /// app echoes its own prompt.
    @Test func rebuildsTheUsersTurnsWhenASessionIsReplayed() throws {
        var events = AcpEvents()
        let made = events.translate(try update(
            #"{"sessionUpdate":"user_message_chunk","content":{"type":"text","text":"do the thing"}}"#
        ))

        #expect(kinds(made) == ["message_start"])
        #expect(made[0]["message"]?["role"]?.string == "user")
        #expect(History.plainText(made[0]["message"]?["content"]) == "do the thing")
    }

    @Test func echoesAPromptTheAppSent() {
        let event = AcpEvents.userMessage("hello")
        #expect(event["type"]?.string == "message_start")
        #expect(event["message"]?["role"]?.string == "user")
        #expect(event["message"]?["timestamp"]?.number ?? 0 > 0)
    }

    /// Replaying a loaded session ends without a turn ending. An answer left open is
    /// drawn as raw streaming text, so its markdown never gets parsed.
    @Test func closesTheLastReplayedAnswer() throws {
        var events = AcpEvents()
        _ = events.translate(try update(
            ###"{"sessionUpdate":"agent_message_chunk","messageId":"m1","content":{"type":"text","text":"## Title"}}"###
        ))

        #expect(kinds(events.closeMessage()) == ["text_end"])
        // Nothing is left open, and closing again must not invent a second end.
        #expect(events.closeMessage().isEmpty)
    }

    /// Closing a replay must not look like a finished turn, or the session is announced
    /// as having just finished work it did days ago.
    @Test func closingAReplayDoesNotSettleTheTurn() throws {
        var events = AcpEvents()
        _ = events.translate(try update(
            #"{"sessionUpdate":"agent_message_chunk","messageId":"m1","content":{"type":"text","text":"hi"}}"#
        ))
        #expect(kinds(events.closeMessage()).contains("agent_settled") == false)
    }

    @Test func settlingClosesWhateverWasOpen() throws {
        var events = AcpEvents()
        _ = events.translate(try update(
            #"{"sessionUpdate":"agent_message_chunk","messageId":"m1","content":{"type":"text","text":"hi"}}"#
        ))
        #expect(kinds(events.settle()) == ["text_end", "agent_settled"])
        // Nothing is open the second time.
        #expect(kinds(events.settle()) == ["agent_settled"])
    }

    /// Plans, usage, commands and mode changes have nowhere to go in this UI yet, and
    /// must not become stray transcript entries.
    @Test func ignoresUpdatesThisUiHasNoHomeFor() throws {
        var events = AcpEvents()
        for kind in ["plan", "usage_update", "available_commands_update", "current_mode_update"] {
            #expect(events.translate(try update(#"{"sessionUpdate":"\#(kind)"}"#)).isEmpty)
        }
        #expect(events.translate(try update(#"{"sessionUpdate":"agent_thought_chunk"}"#)).isEmpty)
    }

    @Test func ignoresAnythingThatIsNotASessionUpdate() throws {
        var events = AcpEvents()
        let other = try JSONDecoder().decode(
            JSONValue.self,
            from: Data(#"{"jsonrpc":"2.0","id":1,"result":{}}"#.utf8)
        )
        #expect(events.translate(other).isEmpty)
    }
}

/// Feeding the translated events into a real `Chat` — the whole chain, minus the process.
@MainActor
struct AcpTranscriptTests {
    private func newChat() -> Chat {
        let index = FileManager.default.temporaryDirectory
            .appending(path: "pi-ui-acp-\(UUID().uuidString).json")
        return Chat(store: SessionStore(file: index))
    }

    private func update(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(
            JSONValue.self,
            from: Data(#"{"jsonrpc":"2.0","method":"session/update","params":{"update":\#(json)}}"#.utf8)
        )
    }

    @Test func buildsATranscriptFromAnAcpTurn() throws {
        let chat = newChat()
        var events = AcpEvents()

        chat.handle(AcpEvents.userMessage("edit the file"))
        for event in events.translate(try update(
            #"{"sessionUpdate":"agent_message_chunk","messageId":"m1","content":{"type":"text","text":"On it."}}"#
        )) { chat.handle(event) }
        for event in events.translate(try update(
            #"""
            {"_meta":{"claudeCode":{"toolName":"Edit"}},"toolCallId":"t1",
             "sessionUpdate":"tool_call","status":"pending","title":"Edit a.txt",
             "rawInput":{"file_path":"a.txt"}}
            """#
        )) { chat.handle(event) }
        for event in events.translate(try update(
            #"""
            {"_meta":{"claudeCode":{"toolResponse":{"structuredPatch":
             [{"lines":[" keep","-old","+new"]}]}}},
             "toolCallId":"t1","sessionUpdate":"tool_call_update","status":"completed"}
            """#
        )) { chat.handle(event) }
        for event in events.settle() { chat.handle(event) }

        #expect(chat.messages.count == 3)
        #expect(chat.messages[0].kind == .user)
        #expect(chat.messages[0].text == "edit the file")
        #expect(chat.messages[1].kind == .assistant)
        #expect(chat.messages[1].text == "On it.")
        #expect(chat.messages[2].kind == .tool)
        #expect(chat.messages[2].tool?.name == "Edit")
        #expect(chat.messages[2].tool?.preview == "a.txt")
        #expect(chat.messages[2].tool?.diff == " keep\n-old\n+new")
        #expect(chat.messages[2].tool?.result == "+1 −1")
        #expect(chat.messages[2].done)
        #expect(chat.isStreaming == false)
    }

    /// The exact sequence a real `echo` produced: an empty announcement, then the command
    /// on later updates, then a final update with no `rawInput` at all.
    @Test func showsTheBashCommandRatherThanEmptyBraces() throws {
        let chat = newChat()
        var events = AcpEvents()

        let sequence = [
            #"""
            {"_meta":{"claudeCode":{"toolName":"Bash"}},"toolCallId":"t1",
             "sessionUpdate":"tool_call","rawInput":{},"status":"pending","title":"Terminal"}
            """#,
            #"""
            {"toolCallId":"t1","sessionUpdate":"tool_call_update",
             "rawInput":{"command":"echo hello-from-bash"}}
            """#,
            #"""
            {"toolCallId":"t1","sessionUpdate":"tool_call_update",
             "rawInput":{"command":"echo hello-from-bash","description":"Echo a test string"}}
            """#,
            #"""
            {"toolCallId":"t1","sessionUpdate":"tool_call_update","status":"completed",
             "content":[{"type":"content","content":{"type":"text","text":"hello-from-bash"}}]}
            """#,
        ]
        for step in sequence {
            for event in events.translate(try update(step)) { chat.handle(event) }
        }

        let tool = try #require(chat.messages.first(where: { $0.kind == .tool })?.tool)
        #expect(tool.name == "Bash")
        #expect(tool.preview == "echo hello-from-bash")
        #expect(tool.arguments.contains("echo hello-from-bash"))
        #expect(tool.arguments != "{}")
        #expect(tool.output == "hello-from-bash")
    }

    /// Until the command arrives there is nothing honest to print.
    @Test func leavesTheArgumentsBlankUntilTheyArrive() throws {
        let chat = newChat()
        var events = AcpEvents()
        for event in events.translate(try update(
            #"""
            {"_meta":{"claudeCode":{"toolName":"Bash"}},"toolCallId":"t1",
             "sessionUpdate":"tool_call","rawInput":{},"status":"pending","title":"Terminal"}
            """#
        )) { chat.handle(event) }

        #expect(chat.messages[0].tool?.arguments == "")
    }

    /// Markdown is only parsed once a message is done, so a replayed answer that stays
    /// open shows its raw source forever.
    @Test func leavesReplayedMarkdownReadyToParse() throws {
        let chat = newChat()
        var events = AcpEvents()

        for step in [
            #"{"sessionUpdate":"user_message_chunk","content":{"type":"text","text":"ask"}}"#,
            ###"{"sessionUpdate":"agent_message_chunk","messageId":"m1","content":{"type":"text","text":"## Title"}}"###,
        ] {
            for event in events.translate(try update(step)) { chat.handle(event) }
        }
        for event in events.closeMessage() { chat.handle(event) }

        let answer = try #require(chat.messages.last(where: { $0.kind == .assistant }))
        #expect(answer.text == "## Title")
        #expect(answer.done)
    }

    /// The exact sequence a real `Edit` produced: the diff lands on an update partway
    /// through, and the completed update carries neither diff nor arguments.
    @Test func showsTheDiffForAnEdit() throws {
        let chat = newChat()
        var events = AcpEvents()

        let sequence = [
            #"""
            {"_meta":{"claudeCode":{"toolName":"Edit"}},"toolCallId":"t1",
             "sessionUpdate":"tool_call","rawInput":{},"status":"pending","title":"Edit"}
            """#,
            #"""
            {"toolCallId":"t1","sessionUpdate":"tool_call_update",
             "rawInput":{"file_path":"edit-me.txt"},
             "content":[{"type":"diff","path":"edit-me.txt","oldText":"bravo","newText":"BRAVO"}]}
            """#,
            #"""
            {"_meta":{"claudeCode":{"toolResponse":{"structuredPatch":
             [{"lines":[" alpha","-bravo","+BRAVO"," charlie"]}]}}},
             "toolCallId":"t1","sessionUpdate":"tool_call_update"}
            """#,
            #"{"toolCallId":"t1","sessionUpdate":"tool_call_update","status":"completed"}"#,
        ]
        for step in sequence {
            for event in events.translate(try update(step)) { chat.handle(event) }
        }

        let tool = try #require(chat.messages.first(where: { $0.kind == .tool })?.tool)
        #expect(tool.name == "Edit")
        // The whole-file patch replaces the fragment seen earlier in the same call.
        #expect(tool.diff == " alpha\n-bravo\n+BRAVO\n charlie")
        #expect(tool.result == "+1 −1")
        #expect(chat.messages[0].done)
    }

    /// A permission request arrives as the same card pi's gate produces.
    @Test func raisesAPermissionCard() throws {
        let chat = newChat()
        chat.handle(try JSONDecoder().decode(JSONValue.self, from: Data(#"""
        {"type":"extension_ui_request","id":"acp-1","method":"confirm",
         "title":"Write","message":"Write hello.txt"}
        """#.utf8)))

        #expect(chat.ask?.method == .confirm)
        #expect(chat.ask?.title == "Write")
        #expect(chat.messages.count == 1)
        #expect(chat.messages[0].kind == .permission)
        #expect(chat.messages[0].request?.tool == "Write")
        #expect(chat.messages[0].request?.detail == "Write hello.txt")
    }
}
