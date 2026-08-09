# Expedition Planner

A self-contained, single-file web app for planning photography expeditions across
a multi-year horizon. Live at **<https://taarora.github.io/home/expedition-planner/>**.

![status: live on GitHub Pages](https://img.shields.io/badge/status-live-2b5a56)

## What it does

Expedition Planner is a visual, drag-and-drop calendar for scheduling and
researching wildlife/photography trips over a rolling three-year window. It has
two views, toggled in the header: a personal **Calendar** and a **Workshops**
browser you can add trips from.

### Calendar view

- **Month × year grid** — three years shown side by side, one row per month.
  Navigate with prev/next arrows, a year-range jump dropdown, or the **Today**
  button.
- **Unscheduled ideas tray** — trips without a date live in a tray above the
  calendar. Drag a trip onto any month to schedule it, or drag it back into the
  tray to unschedule it.
- **Rich per-trip detail** — each trip opens a modal with:
  - Status (**Idea / Planned / Confirmed**), shown as color-coded chips
  - Specific dates, group size, and multiple locations
  - Key species (tag input)
  - Structured budget (amount, currency, notes)
  - Useful links, tour operators (with contact info), and reference links
  - Uploaded **inspiration photos** with a click-to-zoom lightbox
  - Free-form notes
- **Provenance marker** — trips added from the Workshops view are marked with a
  ◇ diamond on their chip and a "Source" line in the detail modal, so you can
  always tell them apart from trips you created by hand.
- **Data menu** — Export/Import JSON, Export/Import CSV, and Import workshops are
  grouped under a single **Data ▾** dropdown in the header.
  - **Excel-compatible CSV import/export** — round-trips cleanly, including
    quoted/multi-line fields and UTF-8 characters (a UTF-8 BOM is written so Excel
    opens it correctly).
  - **JSON backup/restore** — full-fidelity export and import of all trip data.
- **Light and dark themes** — follows the OS setting.

### Workshops view

A browsable, filterable catalog of real photography workshops, so you can turn
operator schedules into planned trips without retyping anything.

- **Filter** by region (US / International), trip type, species, year, and month.
- **Two ways to browse** — the same month × year grid (read-only workshop chips)
  plus a filterable list grouped by month, with an entry for undated
  ("dates by request") trips.
- **Add to your calendar** — each workshop has an **Add** control that lets you
  drop it onto the Calendar as an **Idea**, **Planned**, or **Confirmed** trip.
  Dates, location, species, price (→ budget), and the operator (→ tour operator +
  reference link) are carried over automatically. Undated workshops are added as
  unscheduled ideas (they land in the tray). Already-added workshops show an
  "Added" badge instead of the button.
- **Data source** — the catalog is a pre-built snapshot in
  [`expedition-planner/workshops.json`](expedition-planner/workshops.json),
  loaded at startup. See *Workshops data* below.

## How it was built

- **Vanilla HTML/CSS/JS in a single file** — [`expedition-planner/index.html`](expedition-planner/index.html).
  No frameworks, no build step, no dependencies, no network calls. The entire app
  (markup, styles, and an IIFE-wrapped script) lives in one file so it can be
  served as a static asset or even opened locally.
- **Persistence** is browser `localStorage` (key `expeditionPlanner.v1`). Data is
  per-device / per-browser — see *Data & sync* below.
- **Hosting** is GitHub Pages, served from the `master` branch root. Any push to
  `master` re-deploys automatically.
- Built iteratively with **Claude Code**.

## Data & sync

Because trips are stored in the browser's `localStorage`, each device keeps its
own independent copy — there is no shared backend. To move data between devices
(desktop ↔ iPad, or to share with another person):

1. **Export JSON** on the device with the latest data.
2. Save it to a shared/synced location (e.g. an iCloud Drive folder).
3. **Import JSON** on the other device.

This is a manual, "last export wins" workflow. On iPad/iOS Safari, Import/Export
is the only sync mechanism (mobile browsers can't auto-read a file on disk).

## Workshops data

The Workshops view reads `expedition-planner/workshops.json` — a **dated,
best-effort snapshot** compiled from the operator sites listed in
`expedition-planner/Data/Workshop Calendars.rtf`. It is not live: operators
change prices and schedules constantly, so **always confirm details on the
provider site before booking**. The file records the sites that were covered and
the ones that were skipped (and why). To refresh it, re-extract from the provider
pages and replace the file; if the app can't load it, use **Data ▸ Import
workshops** to load one manually. Some entries (e.g. catalog-only providers) are
undated and appear only in the list under "Dates by request."

## Running locally

Open `expedition-planner/index.html` through a local web server (recommended over
`file://`, which some browsers restrict):

```bash
python3 -m http.server 8743 --directory expedition-planner
# then visit http://localhost:8743
```

## Repository layout

```
expedition-planner/
  index.html        # the entire app
  workshops.json    # pre-built workshop catalog for the Workshops view
  Data/             # source material (provider URL list); not served
README.md
CLAUDE.md           # working notes for AI agents on this repo
```
