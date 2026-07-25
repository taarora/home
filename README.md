# Expedition Planner

A self-contained, single-file web app for planning photography expeditions across
a multi-year horizon. Live at **<https://taarora.github.io/home/expedition-planner/>**.

![status: live on GitHub Pages](https://img.shields.io/badge/status-live-2b5a56)

## What it does

Expedition Planner is a visual, drag-and-drop calendar for scheduling and
researching wildlife/photography trips over a rolling three-year window.

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
- **Excel-compatible CSV import/export** — round-trips cleanly, including
  quoted/multi-line fields and UTF-8 characters (a UTF-8 BOM is written so Excel
  opens it correctly).
- **JSON backup/restore** — full-fidelity export and import of all trip data.
- **Light and dark themes** — follows the OS setting.

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
README.md
```
