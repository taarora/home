# CLAUDE.md — working notes for AI agents on this repo

Context and constraints that aren't obvious from the code, aimed at anyone (esp.
Claude Code) making changes here. For a human-facing overview see `README.md`.

## The one hard rule: stay single-file and dependency-free

The entire app is **one file**: `expedition-planner/index.html` — HTML, CSS, and
an IIFE-wrapped `<script>` all inline. This is intentional and load-bearing:

- **No build step, no bundler, no package manager, no `node_modules`.** There is
  nothing to compile. Do not introduce a framework, a CSS preprocessor, or an npm
  dependency.
- **No external network requests at runtime** — no CDN scripts, web fonts, or
  remote assets. It must work fully offline and as a static file. Keep it that way
  (font stacks use system fonts only).
- If you add a feature, add it inline in this same file. Do not split it into
  modules unless the human explicitly asks to change this architecture.

## Data model

State is a single object persisted to `localStorage` under the key
**`expeditionPlanner.v1`** (bump the suffix if you ever make a breaking schema
change, and migrate on load). Shape:

```jsonc
{
  "startYear": 2026,              // top-left year of the 3-year view
  "trips": [
    {
      "id": "t_<base36ts>_<rand>",
      "title": "…",
      "status": "idea" | "planned" | "confirmed",
      "year": 2026 | null,        // null + null month => lives in the tray
      "month": 3 | null,          // 1-12
      "dates": "14–24 Mar",       // free text, human-readable
      "groupSize": "…",
      "locations": "line1\nline2",// newline-separated
      "species": ["…"],
      "budget": { "amount": "", "currency": "USD", "notes": "" },
      "links":     [{ "label": "", "url": "" }],
      "operators": [{ "name": "", "url": "", "contact": "" }],
      "refLinks":  [{ "label": "", "url": "" }],
      "photos":    [{ "dataUrl": "data:image/…;base64,…", "caption": "" }],
      "notes": "…"
    }
  ]
}
```

Notes:
- A trip is **unscheduled** (shows in the tray) iff `year` or `month` is falsy.
- `photos` are stored inline as base64 **data URLs** in `localStorage`. This is
  the main storage-bloat risk — a `try/catch` around `persist()` surfaces a toast
  if the quota is blown. Be mindful before adding features that store more blobs.
- On first load with no saved state, `seedData()` populates 7 example trips. The
  human may want these removed for a "ship blank" build — ask before assuming.

## Status → color mapping

Chips are tinted by status via CSS custom properties `--status-idea` (muted
olive/grey), `--status-planned` (orange), `--status-confirmed` (blue). An earlier
"Booked" status was deliberately dropped — don't reintroduce it without being
asked.

## CSV format (Excel interop is a real requirement)

`exportCsv()` / `importCsvText()` implement a hand-rolled RFC-4180-ish CSV:
- Output is prefixed with a **UTF-8 BOM (`﻿`)** so Excel detects encoding and
  doesn't mangle characters like `–`, `‹›`, `°`, accented letters. This was a bug
  fixed in an earlier session — **keep the BOM.**
- Fields containing `" , \r \n` are quoted; embedded quotes are doubled.
- List/pair fields are flattened: array items joined with `"; "`, and
  label/url-style pairs joined with `" - "` (see `joinPairs` / `splitPairs`).
- Header names are matched case-insensitively on import. If you add a trip field,
  update `CSV_HEADERS` **and** both the export row builder and the import mapper,
  or the round-trip will silently drop data.

Always verify CSV changes with a full **export → wipe → import** round-trip,
including a title/notes value containing a comma, a quote, and a non-ASCII dash.

## Testing this app (gotchas learned the hard way)

- **Don't open via `file://`** in the automated browser pane — it has hung the
  pane repeatedly. Serve over HTTP instead:
  `python3 -m http.server 8743 --directory expedition-planner` (there's a
  `.claude/launch.json` config named `expedition-planner` for the preview tool).
- **Drag-and-drop and file pickers are unreliable to drive by pixel coordinates.**
  The reliable way to test is to dispatch DOM events / call the app's flows
  directly via the JS console:
  - Drag: dispatch `dragstart` on the `.chip`, then `dragover` + `drop` on the
    target `.cell[data-year][data-month]` or `#trayRow`, using a shared
    `DataTransfer`.
  - CSV/JSON import: build a `File`, assign it to the hidden `<input>.files` via a
    `DataTransfer`, and dispatch a `change` event. Stub `window.confirm` to
    `() => true` first (import/restore ask for confirmation).
  - To capture an export blob without a real download, temporarily wrap
    `URL.createObjectURL` to grab the `Blob`, then read it with `.text()` /
    `.arrayBuffer()`.
- Verify persistence by reading `localStorage['expeditionPlanner.v1']` after an
  action, not just the DOM.

## Deploy flow

- Hosting is **GitHub Pages, `master` branch, root path**. Pushing to `master`
  auto-rebuilds; the live URL is
  `https://taarora.github.io/home/expedition-planner/`.
- The feature branch `claude/photo-trip-calendar-syrssy` was fast-forward-merged
  into `master`; both currently point at the same commit. Prefer working on a
  branch and fast-forwarding into `master` to publish.
- `test.txt` at the repo root is legacy from when this was a throwaway "home" test
  repo. Harmless; leave it unless asked.

## Data / sync context (lives outside this repo)

- Trip data is **not** committed to the repo — it lives only in each browser's
  `localStorage`. The canonical exported snapshot the human keeps is at
  `~/Documents/Claude/Code/expedition-planner-data/trips.json` (inside iCloud
  Drive so it syncs across their devices). That path is user/machine-specific;
  don't hard-code it into the app.
- There is intentionally **no shared backend**. Cross-device/cross-person sync is
  manual Export/Import JSON via that iCloud folder ("last export wins"). If the
  human asks for real-time multi-user sync, that's a significant architecture
  change (a cloud datastore) and should be discussed, not assumed.

## Auth note for pushing

Local git has no committer identity configured and no `gh` CLI; pushes use a
fine-grained PAT exported as `GITHUB_TOKEN` in `~/.zshrc`. Non-interactive shells
don't auto-source it, so prefix git-over-HTTPS pushes with `source ~/.zshrc`. The
PAT has `Contents: read/write`; enabling GitHub Pages required a manual toggle in
the repo's Settings → Pages (the token lacked `Pages: write`).
