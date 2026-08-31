# pi-ui roadmap

A native macOS app that wraps the `pi` coding agent in a Cursor-style UI.

## Architecture (fixed for all versions)

- **SwiftUI + AppKit**, one window: sidebar left, conversation right.
- **One `pi --mode rpc` subprocess per open session.** Crash-isolated, and matches how pi
  already models a session.
- **The app keeps its own session index** (`~/Library/Application Support/pi-ui/sessions.json`).
  Pi's `~/.pi/agent/sessions/` holds the *content*; our index holds *what should exist*.
  That gap is what lets the sidebar show a warning when a session file disappears.
- **Transcript renders in a `WKWebView`.** Markdown → HTML via vendored `marked.min.js`.
- **Vendored, not depended on.** `marked` and `highlight.js` are copied from pi's own HTML
  exporter into our bundle as pinned files. No SPM, no npm, nothing to maintain.
- **`PI_PATH` locates pi.** Required, no fallback. A GUI launch does not inherit your shell
  environment, so a Dock launch needs `launchctl setenv PI_PATH ...`. See `AGENTS.md`.

### Protocol notes that will bite if ignored

- Framing is **LF-only**. Split on `\n`, strip a trailing `\r`. Do not use a generic line
  reader — `U+2028`/`U+2029` are legal inside JSON strings.
- `message_update` carries **deltas, not snapshots**. Assemble partial messages yourself
  using `contentIndex`; treat `message_end.message` as authoritative.
- Correlate requests with the optional `id` field; correlate tool events with `toolCallId`.

---

## How pi stores sessions

Verified against pi 0.84.4 and real session files on disk.

### Layout

```
~/.pi/agent/sessions/--Users-andrelas1-workspace-langas-backend--/
    2026-07-20T20-19-49-461Z_019f812f-5055-7b69-be34-66099ea6c15c.jsonl
```

One directory per project, one file per session. The filename is `<timestamp>_<uuid>`; the
UUID is v7, so filenames sort chronologically. Entry ids inside the file are short 8-hex
strings.

The directory name is the cwd, encoded (`session-manager.js:245`):

```js
`--${resolvedCwd.replace(/^[/\\]/, "").replace(/[/\\:]/g, "-")}--`
```

**The encoding is lossy. Never decode the directory name to recover a path.**
`/x/haskell/first-app` and `/x/haskell/first/app` encode identically. The header line stores
`cwd` verbatim — read it from there.

### File contents

Append-only JSONL. Line 1 is the header:

```json
{"type":"session","version":3,"id":"019f812f-…","timestamp":"…","cwd":"/Users/…/backend"}
```

Then one entry per line. Nine entry types: `message`, `model_change`,
`thinking_level_change`, `compaction`, `branch_summary`, `label`, `session_info`, `custom`,
`custom_message`.

### It is a tree, not a transcript

Every entry has `id` and `parentId`. The current position is a leaf. Forking and `/tree`
navigation create siblings **inside the same file** — branching does not make a new file.

So the file is not the conversation. `buildContextEntries()` walks leaf → root and applies
compaction to derive what the model actually sees. Abandoned branches and pre-compaction
history stay in the file forever.

**Render the leaf → root path.** Everything else is tree data for the v3 branch navigator.
Rendering every line shows the user paths they deliberately walked away from.

### The name is an appended entry

There is no name field to update. `set_session_name` appends a `session_info` entry, and
`getSessionName()` reads the latest one. Renaming five times leaves five entries.

### Operational rules

**One process per session file, ever.** Pi locks `auth.json` and `settings.json` with
`proper-lockfile`, but session writes are plain `appendFileSync` with no lock. Two processes
on one file interleave lines and corrupt the tree. The session index enforces this: if a
session is already running, focus it instead of spawning a second `pi`.

**Nothing is ever cleaned up.** `session-manager.js` has no unlink, retention, or expiry.
Sessions live until someone deletes the file. Deletion exists only in the interactive
`/resume` picker (Ctrl+D), which shells out to `trash` when available. Long-lived sessions
are free — the `missing` state is for external causes only.

**Directories are created eagerly, files lazily.** An empty project directory means a
session was started there and never wrote anything. "Directory exists" does not mean
"session exists", and an empty directory is not a missing session.

**Append-only means cheap tailing.** Watch by byte offset rather than re-reading. Better
still, once a session is open, `get_entries` with a `since` cursor feeds you incrementally —
parse the file directly only to build the sidebar.

---

## v1 — Sessions, markdown, tool cards

### S1. Project skeleton
**Deliverable:** An Xcode project that builds and launches a window with an empty sidebar
and an empty conversation pane. `AGENTS.md` in place.
**Done when:** `xcodebuild` succeeds and the app opens.

### S2. RPC client
**Deliverable:** A `PiSession` type that spawns `pi --mode rpc` in a given folder, writes
JSONL commands, reads JSONL events, and matches responses to requests by `id`.
**Done when:** a test sends `get_state` and gets back the model, session id, and session
file path. Verified working already:
`echo '{"id":"1","type":"get_state"}' | pi --mode rpc --no-session`

### S3. Walking skeleton
**Deliverable:** A "Pick a folder" button opens `NSOpenPanel` and starts `pi --mode rpc`
there. A composer sends a prompt. Assistant text streams into the pane as **plain text**.
Abort works. One session at a time, nothing persisted — the index and sidebar come next.
When `PI_PATH` is unset or wrong, the app says so plainly instead of failing quietly.
**Done when:** a real prompt round-trips end to end against a real repo.

This is the milestone that proves the design, and the first build that is actually usable.
It runs ahead of the index and sidebar deliberately: three subtasks of scaffolding before
any feedback defers all the risk to the end.

### S4. Session index and disk reconciliation
**Deliverable:** A store that persists the session list across launches and, on startup,
checks each session's `.jsonl` on disk. Sessions get a state: `ok` or `missing`.

Three rules from "How pi stores sessions" are load-bearing here:
- Get `cwd` from the session header line, never by decoding the directory name.
- An empty project directory is not a missing session — the file is written lazily.
- The index tracks which sessions have a live process, so nothing can open one twice.

**Done when:** deleting a session file by hand and relaunching marks that session `missing`
without losing it from the list.

### S5. Sidebar
**Deliverable:** Sidebar listing sessions grouped by folder, with a "New session" button
(opens `NSOpenPanel` to pick a folder), inline rename, and delete. This replaces S3's
throwaway folder button with the real flow. Rename writes to the app index for display and
pushes `set_session_name` to pi when the session is running, so `pi -r` in the terminal
shows the same name. Sessions marked `missing` show a warning icon with a tooltip. Delete
moves the file to Trash via `FileManager.trashItem` and drops it from the index.

Clicking a session that is already running focuses it instead of spawning a second `pi` —
session files have no write lock, so two processes on one file corrupt the tree.

**Done when:** you can create, rename, delete, and relaunch with the list intact.

### S6. Markdown transcript
**Deliverable:** Replace the plain-text pane with a `WKWebView`. Completed messages render
markdown → HTML. Streaming text appends live, then re-renders as markdown at
`message_end`. User and assistant messages are visually distinct. Render the leaf → root
path only — abandoned branches live in the same file and must not appear in the transcript.
**Done when:** a response with headings, lists, bold, links, and a fenced code block reads
correctly (code block unhighlighted until v2).

### S7. Tool call cards
**Deliverable:** Collapsible cards for each tool call, driven by
`tool_execution_start` / `_update` / `_end`. Card shows tool name, arguments, live output,
and a success/error state. `bash` output streams into the card as it arrives.
**Done when:** a prompt that triggers `bash`, `read`, and `edit` renders three correct
cards, and the bash one fills in progressively.

### S8. Permission prompts and the pulsing indicator
**Heads up:** pi ships **no permission popups** — that is a deliberate design decision
("It intentionally does not include ... permission popups"). Nothing will ever ask you for
approval out of the box. So this subtask has two halves.

**Deliverable A:** A small TypeScript extension bundled with the app, loaded via
`pi --mode rpc -e <bundled>/permission-gate.ts`. It hooks `tool_call` (which can block),
calls `ctx.ui.confirm()` for writes and shell commands, and returns
`{ block: true, reason }` on deny. Pi ships a `permission-gate.ts` example doing exactly
this — start from it.

**Deliverable B:** The app answers `extension_ui_request` (`confirm`, `select`, `input`,
`editor`) with a native sheet and replies `extension_ui_response`. While a request is
outstanding on a session, that session's sidebar row shows a pulsing dot. `notify`,
`setStatus`, and `setTitle` are handled as fire-and-forget.

**Done when:** asking the agent to edit a file pops a native dialog, denying it actually
stops the edit, and the sidebar pulses while the dialog is unanswered on a background
session.

### S9. Composer
**Deliverable:** Send, abort, and queueing. While streaming, a prompt goes out as `steer`
or `follow_up`. Pending queue is visible and clearable via `clear_queue` / `queue_update`.
**Done when:** you can steer a running agent mid-turn and see the queue empty out.

**v1 external dependencies:** `marked.min.js` only, vendored.

---

## v2 — UX polish

Small things that make it pleasant to live in. v1 works; this makes it quick.

### S10. New session on ⌘T
**Deliverable:** ⌘T opens the folder picker and starts a session, from anywhere in the app.
A File menu item carries the shortcut so it is discoverable rather than hidden.
**Done when:** ⌘T opens the picker with the sidebar unfocused.

### S11. Tool cards open by default
**Deliverable:** Tool cards stay expanded after they finish. Today they fold themselves on
completion, which hides the output you were reading.
**Done when:** a finished bash card still shows its output without a click.

### S12. Jump to a session with ⌘1–⌘9
**Deliverable:** ⌘1 selects the first session in the sidebar, ⌘2 the second, up to ⌘9.

This requires **stable sidebar order**, which is a change: sessions and folders currently
sort by most recently used, so rows move under you and ⌘2 would mean something different
each time. Order becomes oldest first — new sessions append at the bottom and nothing above
them shifts.

**Done when:** ⌘3 selects the same session before and after using another one.

---

## v3 — Code rendering

### S13. Syntax highlighting
**Deliverable:** `highlight.min.js` vendored; fenced code blocks highlighted, themed for
light and dark.

### S14. Diffs
**Deliverable:** `edit` and `write` tool cards render a real diff instead of raw arguments.
Pi's own `template.js` already does line diffing for its HTML export — port that logic
rather than inventing it.

### S15. Git branch in the sidebar
**Deliverable:** Each session row shows the current branch of its folder, read by shelling
out to `git` with `Process` (no git library). Refreshes when the session becomes active and
after the agent finishes a turn.

---

## v4 — Sessions that keep working

### S16. Sessions keep running in the background
**Deliverable:** One `Chat` per session instead of one for the app. Switching changes which
session is shown, not which exists. The sidebar marks a session busy while its agent works.

Before this, `open()` called `close()`, so switching sessions terminated the running pi
process and abandoned the turn. It also made S8's pulsing dot decorative: a request could
only ever belong to the session already on screen.

**Done when:** starting a long turn, switching away, and coming back shows it finished.

### S17. Remember a permission answer
**Deliverable:** The approval sheet gains "Always in this session". Later requests for that
tool are answered without a dialog.

Asking every single time is what makes people stop reading the question, which is worse
than not asking. Memory lasts for the session only — a standing yes that outlived the
window would be a permission nobody granted.

**Done when:** allowing bash once stops the prompts for bash, and edit still asks.

---

## v5 — Everything pi exposes that we haven't used yet

Grouped by what pi gives us, so you can pick by appetite rather than by category.

### Session tree and history
- **Branch navigator** — `get_tree` returns the full session tree; render it and jump to any
  node. Pi's TUI does this as `/tree`; a graphical version is strictly nicer.
- **Fork from any message** — `get_fork_messages` + `fork`, so you can retry a prompt down a
  new path without losing the old one.
- **Clone** the active branch into a fresh session.
- **Incremental sync** — `get_entries` takes a `since` cursor and includes abandoned
  branches and pre-compaction history, so the app can rebuild a transcript after a restart
  without replaying anything.
- **Labels / checkpoints** — `LabelEntry` lets you bookmark a point in the tree.
- **Session lineage** — sessions record `parentSession`, so forks can be drawn as a graph.
- **Export & share** — `export_html`, and pi's `/share` uploads a session as a private gist.

### Models and thinking
- **Per-session model picker** — `get_available_models`, `set_model`, `cycle_model`.
- **Thinking level control** — off / minimal / low / medium / high / xhigh / max, via
  `set_thinking_level` and `get_available_thinking_levels`. A slider in the composer.
- **Multi-provider** — anthropic, openai, google, openrouter, bedrock, scaleway, and local
  llama.cpp. Extensions can register entirely custom providers.
- **Live cost and context meters** — `get_session_stats` returns tokens, cost, and
  `contextUsage.percent`. A context gauge and a running cost readout per session.

### Context management
- **Compact button** — `compact` with optional custom instructions, plus
  `compaction_start` / `_end` events for a progress state.
- **Auto-compaction toggle** — `set_auto_compaction`.
- **Branch summaries** — pi can summarize an abandoned branch when you navigate away.

### Reliability
- **Retry UI** — `auto_retry_start` / `_end` and `abort_retry` give you a "retrying after a
  transient error" banner instead of a silent stall.
- **Error surfacing** — `extension_error` events.
- **Done notifications** — `agent_settled` fires when a session is fully finished. Native
  notification + dock badge when a background session completes.

### A real terminal
- **Built-in shell panel** — RPC has a direct `bash` command with streaming
  `bash_execution_update` and `abort_bash`, independent of the agent. That's a terminal tab
  per session, for free.

### Tools
- **Per-session tool toggles** — enable/disable `read`, `bash`, `edit`, `write`, `grep`,
  `find`, `ls` from the UI.
- **App-provided custom tools** — an extension can `registerTool`, so the agent could call
  into the app: "open this file in Xcode", "show me this diff in the UI", "reveal in Finder".
- **Policy engine** — the blocking `tool_call` hook supports protected paths, command
  allowlists, and auto-approve rules. A proper permissions settings screen.
- **Remote execution** — pi's `ssh.ts` example routes tool execution to a remote host.

### Commands, skills, packages
- **Command palette (⌘K)** — `get_commands` lists every extension command, prompt template,
  and skill with descriptions and source paths. Invoke by sending `/name`.
- **Skill browser** — pi reads skills from `~/.pi/agent/skills`, `~/.agents/skills`, and can
  be pointed at `~/.claude/skills` too.
- **Package manager GUI** — `pi install` / `list` / `update` over npm, git, and local paths.

### Input
- **Images** — `prompt`, `steer`, and `follow_up` all accept base64 images. Drag-and-drop or
  paste a screenshot straight into the composer.
- **File mentions** — pi accepts `@file` arguments.
- **Editor prefill** — `set_editor_text` lets an extension push text into the composer.

### Multi-session
- **Parallel agents** — separate processes means several sessions can run at once. The
  sidebar becomes a live dashboard: streaming, waiting-on-you, done, errored.
- **Widgets and status** — `setWidget`, `setStatus`, `setTitle` come through the same
  channel and can drive per-session badges.

### Safety
- **Sandboxed sessions** — pi documents containerization and Gondolin micro-VM routing.
  A per-session "run sandboxed" toggle.
- **Project trust UI** — `--approve` / `--no-approve` per run. Note that RPC mode never
  shows a trust prompt on its own, so the app would own this decision.
- **Credential status** — `pi auth` reports which providers are ready.

### Not available without building it
- **MCP** — pi has no built-in MCP support. It would have to be an extension.
- **Sub-agents, plan mode, to-dos, background bash** — also deliberately absent from pi
  core, also extension territory.
