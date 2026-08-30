# pi-ui

A native macOS app that wraps the [pi](https://github.com/earendil-works/pi) coding agent in
a Cursor-style interface: a sidebar of long-lived sessions on the left, a conversation pane
on the right.

The app does not reimplement the agent. It drives `pi --mode rpc` as a subprocess — one per
open session — and speaks pi's JSONL protocol over stdin/stdout.

## Requirements

- macOS 14 or later
- Xcode 26 or later
- `pi` installed and working (`pi --version`)

## Setup

**`PI_PATH` is required.** It must point at your `pi` executable. The app reads that variable
and nothing else — there is no search and no fallback, so without it sessions cannot start.

Find your pi and set it:

```sh
which pi
export PI_PATH=/path/to/pi
```

Add the `export` line to your `~/.zshrc` so it survives new terminals.

### Launching from the Dock or Finder

A Dock, Finder, or Spotlight launch does **not** inherit your shell environment, so `PI_PATH`
from `~/.zshrc` is invisible to it. Register the variable with launchd instead:

```sh
launchctl setenv PI_PATH /path/to/pi
```

To make that survive a reboot, put it in a LaunchAgent. Launching from a terminal
(`open PiUI.app`) or from Xcode picks up your shell environment as-is and needs nothing extra.

## Build and run

```sh
xcodebuild -project PiUI.xcodeproj -scheme PiUI -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/PiUI-*/Build/Products/Debug/PiUI.app
```

Or open `PiUI.xcodeproj` in Xcode and hit Run.

## Tests

Tests need `TEST_RUNNER_PI_PATH`, **not** `PI_PATH`. `xcodebuild` does not forward your shell
environment to the test host; it forwards variables prefixed with `TEST_RUNNER_` and strips
the prefix.

```sh
TEST_RUNNER_PI_PATH=/path/to/pi xcodebuild -project PiUI.xcodeproj -scheme PiUI test
```

Get this wrong and the integration tests **skip silently** while the run still reports
success. If a test run finishes suspiciously fast, that is what happened — check for `➜`
skip markers in the output.

## Layout

```
PiUI/            App sources
  RPC/           pi process management and the JSONL protocol
PiUITests/       Unit and integration tests
docs/plans/      Roadmap and subtask breakdown
AGENTS.md        Rules for agents and people working in this repo
```

## Status

Working through v1. See [docs/plans/roadmap.md](docs/plans/roadmap.md) for the full plan.

- **S1** — project skeleton, sidebar and conversation panes ✅
- **S2** — RPC client: process spawning, JSONL framing, request/response correlation ✅
- **S3** — walking skeleton: pick a folder, send a prompt, stream a reply — next
- **S4** — session index and disk reconciliation
- **S5** — sidebar: create, rename, delete sessions
