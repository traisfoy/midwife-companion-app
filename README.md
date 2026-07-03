# Midwife Companion

A two-sided companion tool for home birth and birth center midwives — **not** a full EHR.

- **Patient app**: one-tap contraction timer, water/food/medication logging, recurring
  medication reminders, and push nudges when water or food hasn't been logged recently.
- **Midwife dashboard**: live caseload (alerting patients pinned first), per-patient
  contraction pattern graph + intake history + medication adherence, alert panel with
  drive-time ETA and one-tap acknowledge, and per-patient alert threshold configuration.
- **Alert engine**: every new contraction log is evaluated against the patient's
  configured threshold (default **5-1-1**: contractions ≤ 5 min apart, ≥ 1 min long,
  sustained for 1 hour). When crossed, the assigned midwife gets a push notification and
  a live dashboard alert with the estimated drive time to the patient's address.

> ⚠️ **Prototype only.** Production deployment requires a HIPAA risk assessment and
> signed BAAs with every third-party service before real patient data touches this
> system. See the note at the top of `server/src/index.js`.

## Stack

React (Vite) · Node.js/Express · PostgreSQL · Socket.IO (realtime) · Web Push ·
OpenRouteService (optional, for real driving ETAs and geocoding).

```
/client   React app — patient + midwife views with role-based routing
/server   Express API, alert engine, reminder jobs, Socket.IO
```

## Quick start

Requires Node 20+ and a local PostgreSQL server.

```bash
npm run install:all   # installs root, server, and client deps
npm run db:setup      # creates the midwife_app role + midwife_companion db, applies schema
npm run seed          # 1 midwife + 3 patients with sample data
npm run dev           # starts API (:4000) and client (:5173) together
```

Open http://localhost:5173.

| Role | Email | Password |
|---|---|---|
| Midwife | `sarah@peacefulbeginnings.test` | `midwife123` |
| Patient | `maria@example.test` | `patient123` |
| Patient | `jasmine@example.test` | `patient123` |
| Patient | `emily@example.test` | `patient123` |

`npm run dev` also works from inside `/client` and `/server` individually.

### Trying the full alert flow

1. Sign in as the midwife in one browser window (keep the dashboard open; optionally
   click **Enable push alerts** and **Update my location**).
2. Sign in as `maria@example.test` in a second window (or private window).
3. Log contractions with the timer. The pattern must be *sustained*, so for a quick
   demo either lower Maria's **pattern window** threshold on her detail page (e.g. to
   10 minutes, with 3+ contractions ~4 min apart lasting >60s), or backfill via the API.
4. The alert appears on the open dashboard in real time (Socket.IO, with a 30s polling
   backstop) with the calculated ETA; acknowledge it with one tap.

### Configuration (`server/.env`, optional)

Copy `server/.env.example`. Everything has working local defaults. Set `ORS_API_KEY`
(free at openrouteservice.org) to get real driving ETAs and address geocoding —
without it the app falls back to a straight-line-distance estimate. VAPID keys for Web
Push are auto-generated on first boot and persisted to `server/.vapid.json`.

## How the alert engine works

`server/src/services/alertEngine.js` runs on every new contraction log:

1. Pulls the patient's contraction logs over their pattern window (default 60 min).
2. Computes average frequency (gap between contraction starts) and average duration.
3. Compares against the patient's per-patient thresholds.
4. If crossed — and no unacknowledged alert already exists for the patient — creates an
   Alert, computes the drive-time ETA from the midwife's last known location to the
   patient's address, sends the midwife a Web Push notification, and emits a realtime
   `alert:new` event to her dashboard.

Reminder jobs (`server/src/services/reminders.js`, 60s tick) send water/food nudges
when nothing has been logged within the midwife-configured window (default 4 hours,
re-nudged at most once per window) and fire recurring medication reminders.
