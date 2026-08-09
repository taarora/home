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
  - **Same-origin only:** the app `fetch()`es its own `workshops.json`, and (in
    server mode) its own `/api/*`. These are same-origin, not external calls, and
    all degrade gracefully if the fetch fails. Do not extend this to any
    third-party host.
- Keep the UI in this one file. Companion files are `workshops.json` (reference
  data) and, for the optional sync server, `server.py` + `r.sh` +
  `scripts/setup-tailscale.sh`. The server is **stdlib-only** (no pip deps) — keep
  it that way.

## Two run modes (localStorage vs sync server)

The app runs in one of two modes, auto-detected at startup by `initSync()`:

- **Standalone** (GitHub Pages, or any host without the API): `SYNC.enabled` stays
  false; `localStorage` (`expeditionPlanner.v1`) is the source of truth. This is the
  original behavior and the fallback.
- **Sync server** (served by `server.py`, typically over Tailscale): `initSync()`
  finds `/api/health`, flips `SYNC.enabled` on, and the server's **`trips.json`
  becomes the source of truth**. `localStorage` is then only an offline cache.

Server-mode contract (all same-origin, relative paths — never hardcode a host):
- `GET /api/state` → `{rev, state}` where `rev` is the data file's mtime-ns.
- `PUT /api/state` → `{state}`; returns the new `rev`.
- `persist()` writes localStorage always, and in server mode also debounces a
  `PUT` (`scheduleServerSave`/`pushToServer`). `pollServer()` (every 20s + on
  window focus) adopts a newer `rev` only when there are no unsaved local edits and
  the user isn't mid-interaction (`modalBackdrop.hidden && !dragId`). The
  `applyingRemote` flag suppresses the re-save loop when adopting remote state.
  Conflict resolution is last-write-wins; the `syncBadge` shows the state.
- `server.py` binds `127.0.0.1`; `tailscale serve --https=8443` (NOT 443 — 443 is
  the trading app) exposes it tailnet-only. Data file:
  `~/Documents/Claude/Code/expedition-planner-data/trips.json` (also an
  import-compatible backup), written atomically.

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
      "year": 2026 | null,        // null + null month => lives in the Ideas column
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
      "notes": "…",
      "origin": "manual" | "workshop",
      "region": "" | "US" | "International",  // "" = unspecified; inferred at filter time
      "types": ["…"],                          // trip types; empty for manual trips
      // present only when origin === "workshop":
      "sourceProvider": "…", "sourceUrl": "…", "workshopId": "w_…"
    }
  ]
}
```

Notes:
- A trip is **unscheduled** (shows in the **Ideas column** — the spanning cell on
  the right of the grid) iff `year` or `month` is falsy. There is no separate tray
  anymore; the Ideas column is a normal `.cell` drop target with no
  `data-year`/`data-month`, so dropping a chip there unschedules it.
- `photos` are stored inline as base64 **data URLs** in `localStorage`. This is
  the main storage-bloat risk — a `try/catch` around `persist()` surfaces a toast
  if the quota is blown. Be mindful before adding features that store more blobs.
- On first load with no saved state, `seedData()` populates 7 example trips. The
  human may want these removed for a "ship blank" build — ask before assuming.
- **`origin`** distinguishes hand-created trips (`"manual"`) from ones added via
  the Workshops view (`"workshop"`). `normalizeState()` backfills it to `"manual"`
  on load for older saves and seed data, so additive — **no key bump needed.**
  Workshop-origin trips also carry `sourceProvider` / `sourceUrl` / `workshopId`
  and render a ◇ marker on the chip + a "Source" line in the modal
  (`fieldGroupSource`). `workshopId` is what powers the "already added" guard.
- **`region` / `types`** power the Calendar filter bar, which mirrors the Workshops
  filters (Region/type/species/year/month) over the user's own trips via
  `calMatch` / `calFilters` / `populateCalFilters`. `region` is set from the
  workshop on add, editable in the modal, and falls back to `tripRegion()` which
  infers US vs International from the locations text (`US_REGION_RE`). Both are
  backfilled by `normalizeState` — additive, no key bump. `types` is only
  populated on workshop-added trips (manual trips have `[]`).
- The month × year grid is built by `gridHtml(years, headCountFn, cellFn, ideas)`;
  the optional `ideas` arg adds the spanning Ideas column and is passed only by the
  calendar (the Workshops grid omits it).

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

The four export/import actions live in the header **Data ▾** dropdown but keep
their original element IDs (`exportBtn`, `importBtn`, `exportCsvBtn`,
`importCsvBtn`) and handlers — the dropdown is just markup around them. `origin`
is intentionally **not** a CSV column (CSV is for human/Excel interop); it
survives via JSON export/restore only.

## Workshops view

Second view, toggled by the header Calendar/Workshops buttons (`setView`). It is a
browse-and-add surface over a **pre-built catalog**, `workshops.json`:

- **Data**: `workshopsData` is loaded at startup via `loadWorkshops()` (same-origin
  `fetch`), held in memory only — **never** written to `localStorage`. On fetch
  failure it shows a note and offers **Data ▸ Import workshops** (`applyWorkshopsData`).
  Schema per workshop: `id, provider, providerUrl, name, location, country,
  region ("US"|"International"), startDate, endDate, year, month, types[],
  species[], price (string), availability, notes`. `year`/`month` may be `null`
  (undated catalog entries) — those show in the list under "Dates by request" and
  are excluded from the grid.
- **Regeneration**: the file is a dated snapshot compiled by fetching the operator
  URLs in `expedition-planner/Data/Workshop Calendars.rtf` (WebFetch). It goes
  stale — re-run extraction and replace the file; keep `generatedAt`,
  `providersCovered`, and `providersSkipped` accurate. Some providers can't be
  fetched (JS calendars, tracker redirects, image-only PDFs) — record them in
  `providersSkipped` rather than dropping them silently.
- **Grid reuse**: both views share `gridHtml(years, headCountFn, cellFn)`. Don't
  fork the grid skeleton — parameterize it.
- **Add flow**: a single floating status menu (created in JS) is anchored to
  whichever `[data-wk-add]` element (grid chip or list "Add" button) was clicked;
  `[data-wk-status]` items call `addWorkshopToCalendar(id, status)` →
  `mapWorkshopToTrip` (sets `origin:"workshop"` + source fields; parses a leading
  number out of `price` into `budget.amount`, currency inferred from € / £ / $).
  A workshop already on the calendar (matched by `workshopId`) shows an "Added"
  badge instead of the button.
- **Testing**: drive it with dispatched events — click `[data-wk-add="<id>"]`,
  then `[data-wk-status="idea|planned|confirmed"]`; assert on
  `localStorage['expeditionPlanner.v1']`. Test the fetch-fail path by renaming
  `workshops.json` and reloading.

## Testing this app (gotchas learned the hard way)

- **Don't open via `file://`** in the automated browser pane — it has hung the
  pane repeatedly. Serve over HTTP instead:
  `python3 -m http.server 8743 --directory expedition-planner` (there's a
  `.claude/launch.json` config named `expedition-planner` for the preview tool).
- **Drag-and-drop and file pickers are unreliable to drive by pixel coordinates.**
  The reliable way to test is to dispatch DOM events / call the app's flows
  directly via the JS console:
  - Drag: dispatch `dragstart` on the `.chip`, then `dragover` + `drop` on the
    target `.cell[data-year][data-month]` or the Ideas cell (`.cal-ideas-cell`,
    no data-year/month), using a shared
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
- Prefer working on a feature branch and fast-forwarding into `master` to publish
  (that's how the calendar and workshops features landed).
- `expedition-planner/workshops.json` **is served** (the app fetches it) — keep it
  next to `index.html`. `expedition-planner/Data/` is source material only (the
  provider URL list, any supplied PDFs); it's fine that it ships but nothing loads
  it at runtime.
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
