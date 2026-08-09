# Usage

Day-to-day operation of the Expedition Planner across your Mac, iPhone, and iPad.

There are two ways to run it, and it matters which one you're on:

- **Sync server (recommended)** — served from the Mac Studio over Tailscale. One
  shared `trips.json`; every device sees the same calendar live. Badge reads
  **✓ Synced**.
- **Standalone** — the GitHub Pages URL. Trips live only in that one browser
  (`localStorage`); nothing syncs. Badge reads **Local only**.

For what the tool is and how it's built, see [README.md](../README.md). For notes
aimed at future edits, see [CLAUDE.md](../CLAUDE.md).

---

## Contents

- [The one rule that prevents "my trips vanished"](#the-one-rule-that-prevents-my-trips-vanished)
- [Every time you use it (desktop)](#every-time-you-use-it-desktop)
- [Reaching it from iPhone / iPad](#reaching-it-from-iphone--ipad)
- [Using the calendar](#using-the-calendar)
- [The Workshops tab](#the-workshops-tab)
- [Backups](#backups)
- [Refreshing the workshop catalog](#refreshing-the-workshop-catalog)
- [Troubleshooting](#troubleshooting)
- [What this tool will not do](#what-this-tool-will-not-do)

---

## The one rule that prevents "my trips vanished"

Trips are stored **per URL and per browser**. These are all *separate* buckets:

- `http://localhost:8743` (the Mac, via the server)
- `http://127.0.0.1:8743` (a *different* bucket — don't use it)
- `https://taruns-mac-studio.tail1ee8a6.ts.net:8443` (the server, from other devices)
- `https://taarora.github.io/home/expedition-planner/` (standalone, localStorage)

The **server** URLs (`localhost:8743` and the `:8443` tailnet URL) all read the
**same** `trips.json`, so they're genuinely in sync. The **GitHub Pages** URL is a
separate, unsynced copy. Pick the server for real use.

Two things that DO erase data — avoid them:

- **"Clear Website Data"** in the browser wipes that site's trips. Don't.
- Editing on the **standalone** URL and expecting it on other devices — it won't
  sync (that's localStorage, not the server).

---

## Every time you use it (desktop)

```bash
~/Documents/Claude/Code/repos/home/expedition-planner/r.sh
```

That restarts the sync server and opens Chrome fresh (with a cache-buster so you
never get a stale tab). You should see:

```
✅ Up at http://localhost:8743/
🗂  Shared trips.json: <N> trip(s)
📱 Other devices: https://taruns-mac-studio.tail1ee8a6.ts.net:8443
```

The **✓ Synced** badge under the title confirms you're on the shared server. If it
says **Local only**, you opened the GitHub Pages URL instead — switch to
`http://localhost:8743`.

Keep the Mac Studio awake (System Settings → Energy) — when it sleeps, the phone
and iPad can't reach the data.

---

## Reaching it from iPhone / iPad

One-time, per device:

1. Install **Tailscale** and sign in with the same account (`taarora@`).
2. Open **`https://taruns-mac-studio.tail1ee8a6.ts.net:8443`** in Safari.
   (Real HTTPS via Tailscale — no certificate warning; tailnet-only, nothing
   public.)
3. **Share → Add to Home Screen** for an app-like icon; open it from there.

Daily: just open the icon. Keep Tailscale connected. Anything you add appears on
the Mac (and the other device) within ~20 seconds, or immediately when you switch
back to the app.

If it won't load: the Mac Studio is asleep/off, or Tailscale is disconnected on
the phone.

---

## Using the calendar

- **Three-year grid**, one row per month. Move the window with ‹ / › , the
  year-range dropdown, or **Today**.
- **Add a trip**: **+ New Trip**, or hover a month cell and click **+**.
- **Edit**: click a trip chip. A trip with a workshop origin shows a **◇** marker
  and a "Source" line.
- **Reschedule**: drag a chip between months. **Unschedule**: drag it into the
  **Ideas** column (far right); drag it back onto a month to schedule it again.
- **Filters** (Region / trip type / species / year / month) narrow the grid and
  the Ideas column. Set a trip's Region in its modal so the Domestic/International
  filter works (it's auto-set for workshop trips and inferred from the location
  otherwise).
- **Status** colors: Idea (grey), Planned (orange), Confirmed (blue).

Everything saves automatically. In server mode the badge flickers **Saving…** then
**✓ Synced**.

---

## The Workshops tab

Toggle **Workshops** in the header to browse ~100 real photography workshops.

- **Filter** by Region / trip type / species / year / month.
- **Grid**: every *dated* workshop as a chip in its month — click a chip to add it.
- **List below**: only the *undated* ("dates by request") workshops.
- **Add**: choose Idea / Planned / Confirmed. Dates, location, species, region,
  price (→ budget), and operator (→ tour operator + reference link) carry over.
  Undated ones land in the Ideas column. Already-added workshops show an "Added"
  badge.

Prices and dates are a dated snapshot — **confirm with the operator before
booking.**

---

## Backups

Even with the server, take a snapshot after big edits:

- **Data ▾ → Export JSON.** In Chrome/Edge on the Mac a Save dialog lets you pick a
  folder — save into `~/Documents/Claude/Code/expedition-planner-data/`. (Safari /
  iPad send it to Files/Downloads instead.)
- To restore: **Data ▾ → Import JSON** on the server app — that write becomes the
  shared source of truth for every device.
- The server also keeps the live file at
  `expedition-planner-data/trips.json`, and `r.sh`/migrations leave
  `trips.backup-*.json` alongside it.

**Excel:** Data ▾ → Export CSV / Import CSV round-trips cleanly (UTF-8 BOM so Excel
opens it correctly). `origin` isn't a CSV column — use JSON to preserve it.

---

## Refreshing the workshop catalog

`workshops.json` is a dated snapshot compiled from the operator sites in
`Data/Workshop Calendars.rtf`. To refresh, re-extract from those pages and replace
`expedition-planner/workshops.json` (keep `generatedAt`, `providersCovered`,
`providersSkipped` accurate). If the app can't load it, **Data ▾ → Import
workshops** loads one manually.

---

## Troubleshooting

- **Badge says "Local only" on the Mac** — you're on the GitHub Pages URL, or the
  server isn't running. Run `r.sh` and use `http://localhost:8743`.
- **Chrome shows a stale view** — `r.sh` now opens with a cache-buster; if an old
  tab lingers, close it or `⌘⇧R`. (A hard refresh never erases data; "Clear
  Website Data" does.)
- **Phone/iPad can't connect** — Mac Studio asleep/off, or Tailscale off on the
  device. Wake the Mac; toggle Tailscale on.
- **Badge stuck on "Offline — will sync"** — the app can't reach the server;
  edits are held in the local cache and pushed when it's back.
- **"my trips vanished"** — almost always the wrong URL/bucket. Check
  `localhost:8743` (server) vs the GitHub Pages URL. See the rule at the top.
- **Stop serving to the tailnet**:
  `/Applications/Tailscale.app/Contents/MacOS/Tailscale serve --https=8443 off`

---

## What this tool will not do

- **Sync when the Mac Studio is off.** The single source of truth lives on that
  Mac; wake it and the phone/iPad reconnect. (There is no cloud copy by design.)
- **Merge simultaneous edits.** Conflict handling is last-write-wins; the ~20s poll
  makes devices converge. Fine for a couple of people rarely editing at the same
  instant.
- **Book anything.** Workshop prices/dates are a snapshot — confirm and book with
  the operator yourself.
