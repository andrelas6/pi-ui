# AGENTS.md

Rules for any agent or person working in this repo. These override default habits.

## What this project is

A native macOS app (Swift / SwiftUI) that gives the `pi` coding agent a Cursor-style UI:
a sidebar of long-lived sessions on the left, a conversation pane on the right.

The app never reimplements the agent. It drives `pi --mode rpc` as a subprocess — one
process per open session — and speaks pi's JSONL protocol over stdin/stdout.

## Running it

**`PI_PATH` is required.** It must point at the pi executable. The app reads it and nothing
else — there is no search, no fallback, no bundled copy. Without it, sessions cannot start.

```sh
export PI_PATH=/path/to/pi
```

A Dock, Finder, or Spotlight launch does not see your shell environment. For those, set it
where launchd can see it:

```sh
launchctl setenv PI_PATH /path/to/pi
```

**`ACP_PATH` is required for Claude sessions**, and only for those. It points at an ACP
adapter — the app speaks the Agent Client Protocol, so any adapter that does the same would
work, but the one this was built against is Claude's:

```sh
npm install -g @agentclientprotocol/claude-agent-acp
export ACP_PATH=$(which claude-agent-acp)
```

Install it globally rather than into a project. The adapter is a `#!/usr/bin/env node`
script, and the app prepends only the executable's own directory to `PATH` — a global install
puts the adapter next to the node that runs it, which a `node_modules/.bin` does not. Get this
wrong and the adapter dies with `env: node: No such file or directory`, which the app now
reports verbatim.

pi sessions do not read `ACP_PATH`, and Claude sessions do not read `PI_PATH`. Either can be
unset if you only use the other.

**Tests need `TEST_RUNNER_PI_PATH`, not `PI_PATH`.** `xcodebuild` does not forward shell
environment to the test host; it forwards variables prefixed with `TEST_RUNNER_`, stripping
the prefix. Get this wrong and the integration tests silently *skip* while the run still
reports success.

```sh
TEST_RUNNER_PI_PATH=/path/to/pi TEST_RUNNER_ACP_PATH=/path/to/claude-agent-acp \
  xcodebuild -project PiUI.xcodeproj -scheme PiUI test
```

## Code style

**No comments unless the code genuinely isn't clear.** If a comment is needed, make it one
line. Don't narrate what the code already says.

**Name things the way you'd say them in Slack.** `loadSessions()`, `startSession()`,
`sendPrompt()`, `isWaitingForUser`. Not `hydrateSessionSeam()`, `feedTranscriptSink()`,
`materializeDescriptor()`. If you wouldn't say the word out loud to a coworker, don't use
it in a function name.

## Dependencies

**Prefer Apple's frameworks and the Swift standard library.** SwiftUI, Foundation, WebKit,
AppKit, `Process`, `JSONDecoder`, `FileManager`. There is almost always a native answer.

**Keep external libraries as close to zero as possible.** This project should not carry a
maintenance burden. A dependency needs a reason that outlives the afternoon it was added.

**If you think you need an external library, don't just add it. Write it up first:**

- What it is
- Why we need it
- What it costs us to *not* use it (how much code we'd write and maintain instead)

Then let the repo owner decide. Prefer vendoring a small pinned file over adding a package
manager dependency — a checked-in file doesn't resolve, update, or break on its own.

Current external code, all vendored as pinned files in the app bundle (no SPM, no npm):

| File | What | Why | License |
|---|---|---|---|
| `marked.min.js` | Markdown → HTML | Transcript rendering | MIT |
| `highlight.min.js` | Syntax highlighting | Code blocks | BSD-3-Clause |

Both are copied from pi's own HTML exporter, so they match how pi renders sessions.

## Git

**Do not add a co-author trailer to commits.** No `Co-Authored-By`, no
`Generated with` footer. Commit messages are plain.
