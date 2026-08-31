# Handoff: Foreman — multi-session agent workspace

## Overview
A desktop three-pane workspace for running several coding-agent sessions at once: a sessions rail on the left, the agent conversation in the middle, the working-copy file tree on the right. The design's job is to make the state of every session legible at a glance (done / working / needs input), make switching instant (⌘1…⌘N), and keep the composer dense so the conversation dominates the window.

## About the design files
The files in this bundle are **design references created in HTML** — a prototype showing intended look and behavior, not production code to copy. `Agent Workspace.dc.html` is a streaming-template format (`{{ hole }}` values are supplied by the small logic class at the bottom of the file); read it as markup + intent, not as a component to import. **Recreate it in the target codebase's own environment** (Electron + React, Tauri, SwiftUI, etc.) using that codebase's established component and styling patterns. If no environment exists yet, pick the framework that fits the app and implement there.

`styles.css` is the "Industry" design system token sheet the design consumes; `design-system-guide.md` is its written rulebook. Port the tokens (or map them onto the codebase's existing tokens) rather than hard-coding the hexes ad hoc.

## Fidelity
**High-fidelity.** Colors, type, spacing, and the interaction states are final. Recreate the UI closely; the pixel values below are the source of truth.

## Layout shell
- Root: `height: 100vh`, `display: flex; flex-direction: column`, background `--color-bg` (#f2f2f3), text `--color-text` (#1d1f20), body font Barlow 14px, `overflow: hidden`.
- **Title bar**: 38px tall, full width, background `--color-neutral-100` (#f5f5f8), bottom border 1px `--color-divider`. Contents left→right: app name "FOREMAN" (Barlow Condensed 700, 13px, uppercase, letter-spacing .14em); current path `~/work/<session>` (mono 11px, `--color-neutral-600`); right-aligned meta group (Barlow Condensed 11px uppercase, letter-spacing .1em): "5 SESSIONS" in `--color-neutral-600`, "1 NEEDS INPUT" in `--color-accent-700`.
- Below it a `flex: 1` row with `min-height: 0` holding the three panes: sessions `width: 272px; flex: none`, main `flex: 1; min-width: 520px`, files `width: 264px; flex: none`. Vertical 1px `--color-divider` rules between panes. Each pane scrolls independently.

## Pane 1 — Sessions rail (272px)
Header row: label "SESSIONS" (Barlow Condensed 600, 12px, uppercase, letter-spacing .16em, `--color-neutral-700`), padding `13.6px 13.6px 10.2px`.

Session rows (button, full width, `cursor: pointer`, `text-align: left`):
- Padding `10.2px 10.2px` (a compact variant at `6.8px 10.2px` exists behind a `denseSessions` flag).
- Bottom border 1px `--color-divider`. Left border 2px: `--color-accent` when active, transparent otherwise.
- Active row: background `--color-accent-100` (#eef6ff) plus the design system's four `+` corner registration marks.
- Hover (inactive): background `--color-accent-100`.
- Three columns: **status dot** (14px wide × 22px tall centering box) · **text block** (flex column, gap 3px) · **hotkey** (mono 11px, `--color-neutral-500`, plain text — no border/badge, 22px tall so it sits on the title row).
- Text block: folder name (Barlow Condensed 600, 16px, on a 22px-tall row, ellipsis on overflow); branch line (mono 10.5px, `--color-neutral-600`) preceded by a 11px Lucide `git-branch` icon at stroke-width 1.5. No status text label — the dot carries status.

**Status dot** — 8×8px square, no scaling animation, opacity only:
| Status | Fill | Animation |
| --- | --- | --- |
| Done | `--color-neutral-400` (#b7b7ba) | none |
| Working | `--color-accent` (#5980a6) | `opacity 1 → .28 → 1`, 2s ease-in-out infinite |
| Needs input | `#b07d2e` (muted ochre — the one deliberate step outside the steel palette) | `opacity 1 → .3 → 1`, 1.6s ease-in-out infinite |

Rail footer (optional, behind a `showLegend` flag): top border 1px divider, padding `10.2px 13.6px`, three legend rows at 11px `--color-neutral-700`, each a 7px swatch (with the same animation) + label: Done / Working / Needs input.

Sample data used in the mock:
1. api-gateway · feat/rate-limits · done
2. dashboard-web · fix/settings-draft · working (active)
3. billing-service · fix/proration-bug · needs input
4. infra-terraform · chore/tf-1.9 · done
5. docs-site · main · done

## Pane 2 — Conversation
**Header** (padding 13.6px, bottom border 1px divider, all items `flex: none; white-space: nowrap`): session name as `h1` (Barlow Condensed 700, 24px); branch as an outlined tag (`.tag .tag-outline`, mono); meta "18 MSGS · 4M 12S" (Barlow Condensed 11px uppercase, letter-spacing .12em, `--color-neutral-600`); right-aligned two ghost icon buttons (diff, terminal), Lucide 16px stroke 1.5.

**Message log** — `flex: 1`, scrolls, padding `27.2px 27.2px 13.6px`, flex column, gap 27.2px, content column capped at 760px.
- *User message*: kicker "YOU · 14:02" (Barlow Condensed 11px uppercase, letter-spacing .18em, `--color-neutral-600`); body indented behind a 2px `--color-accent` left rule, padding-left 13.6px, line-height 1.55.
- *Agent message*: kicker "AGENT · OPUS 4.6" in `--color-accent-700`; prose at line-height 1.6; inline code = mono 12.5px on `--color-neutral-200`, padding 1px 4px.
- *Tool-call rows*: stacked 1px-divider-bordered rows, mono 12px, padding `6.8px 10.2px`, `--color-neutral-700`; a 13px Lucide icon, the call text, and a right-aligned result ("7 hits", "+34 −6" in `--color-accent-700`).
- *Diff block*: blueprint-framed (1px divider + corner marks), mono 12px, line-height 1.7. Header strip (11px, `--color-neutral-600`, bottom border) shows file path and hunk range. Added lines: background `--color-accent-200` (#d6ebff), text `--color-accent-900`. Removed lines: background `--color-neutral-200`, text `--color-neutral-700`. Context lines: `--color-neutral-600`.
- *Permission request* (shown only when the active session status is "needs input"): blueprint card, 1px `#b07d2e` border, `--shadow-sm`, padding 13.6px, gap 10.2px. Row 1: 8px ochre dot with the needs-input animation + "PERMISSION REQUESTED" (Barlow Condensed 12px uppercase, letter-spacing .16em, `#7d5719`). Row 2: the request sentence with the command in inline code. Row 3: primary button "Allow once" (solid accent, square, corner marks) · secondary "Always allow" · ghost "Deny" · right-aligned hint "⌘⏎ / ⎋" (mono 11px, `--color-neutral-500`).
- *Processing indicator* (shown only when status is "working"): 14px Lucide arc spinning `rotate(360deg)` 1.4s linear infinite in `--color-accent`; rotating label (Barlow Condensed 15px uppercase, letter-spacing .08em, `--color-accent-700`, `min-width: 220px` so the row doesn't jitter) cycling every 1.6s through: `processing…`, `cooking`, `getting there…`, `reading the diff`, `thinking it through`, `almost`; then elapsed time + "esc to interrupt" (mono 11px, `--color-neutral-500`), counting up each second.

**Composer** — outer padding `13.6px 27.2px 20.4px`. Blueprint frame: 1px `--color-neutral-400`, background `--color-neutral-100`, corner marks.
- Row 1 (padding `13.6px 13.6px 10.2px`): mono `>` prompt in `--color-accent-700`; placeholder "Ask, or describe the next change…" in `--color-neutral-600`; a 1×15px blinking caret (1.1s steps(1,end)).
- Row 2 — deliberately **compact, ~26px tall**: padding `1px 10.2px`, top border 1px divider, items 24px tall.
  - Model button: ghost, `height: 24px`, padding `0 6.8px`, Barlow Condensed 12px uppercase letter-spacing .06em, Lucide box icon + label + chevron. Opens a popover above it: blueprint panel, 250px wide, `--color-neutral-100`, 1px `--color-neutral-400`, `--shadow-lg`, header "MODEL", then rows (padding `6.8px 10.2px`, hover `--color-accent-100`) with name + note and a 14px accent check on the selected one. Models: Opus 4.6 "Deepest reasoning · slowest"; Sonnet 4.6 "Balanced · default"; Haiku 4.5 "Fast edits, small diffs"; Local · qwen-coder "Offline, no context limit".
  - Right group: mic icon button (ghost, 24×24, Lucide `mic` 16px) and primary "Send" (solid accent, `height: 24px`, padding `0 10.2px`, 12px, corner marks, 13px up-arrow icon).

## Pane 3 — File tree (264px)
Header: "FILES" (same kicker style as SESSIONS) with right-aligned "3 changed" (mono 11px, `--color-accent-700`).

Rows: mono 12px, padding `3px 13.6px 3px (8 + depth × 13)px`, gap 6px, hover `--color-accent-100`, `cursor: pointer`. Folders in `--color-text` with a 12px Lucide chevron rotated 90° when open; files in `--color-neutral-700` with a 12px spacer instead of a chevron. Change badge on the right when present: 10px, `--color-accent-800` on a 1px `--color-accent-400` border, padding `0 3px` — "M" modified, "A" added.

Tree in the mock (depth · kind · name · badge): 0 folder dashboard-web (open) → 1 folder src (open) → 2 folder settings (open) → 3 SettingsPanel.tsx [M], store.ts [M], schema.ts → 2 folder routes (closed), lib (closed), file main.tsx → 1 folder tests (open) → 2 settings.spec.ts [A] → 1 folder public (closed), package.json, pnpm-lock.yaml, vite.config.ts, README.md.

Footer: top border 1px divider, padding `10.2px 13.6px`, mono 11px — branch name left, "+41 −7" right in `--color-accent-700`.

## Interactions & behavior
- **⌘1…⌘5 / Ctrl+1…5** (window-level keydown, `preventDefault`) selects the Nth session; clicking a row does the same. Selecting a session updates the title-bar path, the conversation header name and branch, the file-tree footer branch, and which state block (processing indicator vs permission card) renders.
- Model button toggles the popover; picking a model sets it and closes.
- Rotating processing phrase: 1600ms interval. Elapsed timer: 1000ms interval. Both cleared on unmount.
- Status dot animations run continuously; they must not restart on re-render (keep the dot's DOM identity stable).
- Focus: 2px `--color-accent` `:focus-visible` outline with 2px offset everywhere — never the browser default.
- Not designed yet (out of scope for this pass): resizable pane dividers, expand/collapse on tree rows, empty/idle session state, terminal pane, scroll-to-bottom behavior on new messages.

## State
`activeSessionIndex` (int), `phraseIndex` (int, ticked), `elapsedSeconds` (int, ticked), `modelPopoverOpen` (bool), `selectedModel` (string). Per-session data: `{ folderName, branch, status: 'done'|'working'|'asking' }`. Real implementation additionally needs the message list, tool-call/diff payloads, the pending-permission object, and the file tree with per-node open/changed flags. Presentation flags in the prototype: `showLegend` (bool, default true), `denseSessions` (bool, default false).

## Design tokens (from styles.css)
- Ground `--color-bg` #f2f2f3 · surface #e9e9ea · text #1d1f20 · divider `#1d1f20` at 16% · accent #5980a6.
- Neutral ramp 100→900: #f5f5f8, #e7e7ea, #d4d4d7, #b7b7ba, #98989b, #7a7a7d, #5d5d60, #424244, #2b2b2d.
- Accent ramp 100→900: #eef6ff, #d6ebff, #b5d9fd, #94bce3, #749dc4, #597ea3, #416180, #2c455d, #1d2d3d.
- One color outside the sheet: `#b07d2e` (needs-input signal) with `#7d5719` for its text. Everything else must come from the tokens.
- Type: headings "Barlow Condensed" 600/700; body "Barlow" 400/500. Code/paths/branches use a system mono stack (`ui-monospace, Menlo, monospace`) — the design system ships no mono face, so substitute the codebase's mono.
- Spacing scale (0.85× density): 3.4 / 6.8 / 10.2 / 13.6 / 20.4 / 27.2 px. Radii: 2 / 4 / 7 px — but this UI is square-cornered throughout; do not round cards, buttons, or figures.
- Shadows: sm `0 1px 2px #2b2b2d@14%`, md `0 3px 10px @16%`, lg `0 12px 32px @22%`.
- Blueprint frame: 1px hairline border + four `+` registration marks at the corners (`.blueprint` + `.corner tl/tr/bl/br` in styles.css). Cards and figures stay transparent line drawings; the solid accent primary button is the single filled object.

## Assets
No images. All icons are inline SVG in the Lucide style at stroke-width 1.5: `git-branch`, `search`, `file`, `plus`, `terminal`, `box`, `chevron-down`, `chevron-right`, `check`, `mic`, `arrow-up`, and a partial-circle spinner. Use the real Lucide package in the implementation.

## Files in this bundle
- `Agent Workspace.dc.html` — the design prototype (markup + the small logic class driving state).
- `styles.css` — Industry design system tokens and component classes.
- `design-system-guide.md` — the design system's rules (framing, color, type, interaction states).
