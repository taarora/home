#!/usr/bin/env bash
#
# Publish the Expedition Planner sync server on your tailnet over HTTPS, so your
# laptop, iPad, and your wife's device all reach the SAME trips — with no domain
# name and nothing exposed to the public internet.
#
# WHY TAILSCALE (not a public tunnel). Tailscale makes the app reachable only from
# devices signed into YOUR tailnet, so the default state is private rather than
# public-with-a-lock. Nothing to leave misconfigured, no router port opened, and
# the data never leaves your Mac. Free for personal use.
#
# Run this ONCE on the always-on Mac (the Mac Studio) after starting the server
# with ./r.sh. It is INTERACTIVE the first time — it may need you to sign in.
#
#   ./scripts/setup-tailscale.sh
set -euo pipefail

PORT=8743        # local backend (server.py)
HTTPS_PORT=8443  # tailnet HTTPS port for the planner. NOT 443 — that's already
                 # serving the trading app; a dedicated port keeps both working.

# The Mac App Store build doesn't put `tailscale` on PATH, so "not on PATH" and
# "not installed" are different problems.
TS=""
if command -v tailscale >/dev/null 2>&1; then
  TS=tailscale
elif [ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then
  TS=/Applications/Tailscale.app/Contents/MacOS/Tailscale
  echo "==> Using the CLI inside Tailscale.app (not on PATH)"
fi

if [ -z "$TS" ]; then
  cat <<'TEXT'
Tailscale is not installed. Install it, then re-run this script:

    brew install --cask tailscale

Then open /Applications/Tailscale.app once and sign in (Google, GitHub, Microsoft
or email — no domain, no card).
TEXT
  exit 1
fi

echo "==> Checking the local server is up on 127.0.0.1:$PORT"
if ! curl -s -o /dev/null "http://127.0.0.1:$PORT/api/health"; then
  echo "    Not running. Start it first:  ./r.sh"
  exit 1
fi

echo "==> Checking you are signed in"
if ! "$TS" status >/dev/null 2>&1; then
  echo "    not signed in — running 'tailscale up'"
  "$TS" up
fi

DNSNAME=$("$TS" status --json | python3 -c '
import json,sys
print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))')
echo "    this Mac is $DNSNAME"

TSIP=$("$TS" status --json | python3 -c '
import json,sys
ips = json.load(sys.stdin)["Self"].get("TailscaleIPs") or []
print(next((i for i in ips if ":" not in i), ""))')

# HTTPS certs are a TAILNET setting, and `tailscale serve --https` BLOCKS when they
# are off rather than failing — so check first, otherwise Safari just says "cannot
# connect" and points at the wrong problem.
echo "==> Checking HTTPS certificates are enabled for this tailnet"
if ! "$TS" cert "$DNSNAME" >/dev/null 2>&1; then
  cat <<TEXT

    HTTPS certificates are NOT enabled on your tailnet. Enable it once, then
    re-run this script:

        https://login.tailscale.com/admin/dns  ->  "HTTPS Certificates"  ->  Enable

    IN THE MEANTIME the planner is already reachable from any device on your
    tailnet over plain HTTP:

        http://$TSIP:$PORT

TEXT
  exit 1
fi

echo "==> Publishing the planner on HTTPS port $HTTPS_PORT inside your tailnet"
# --bg survives this shell and returns after a reboot. Serve (not Funnel):
# tailnet-only, never the public internet. A dedicated port ($HTTPS_PORT) is used so
# this does NOT disturb anything already served on 443 (e.g. the trading app).
"$TS" serve --bg --https=$HTTPS_PORT "http://127.0.0.1:$PORT"

echo
"$TS" serve status || true

cat <<TEXT

Done. The shared planner is at:

    https://$DNSNAME:$HTTPS_PORT

Reachable ONLY from devices signed into your tailnet. Every device that opens
this URL reads and writes the SAME trips.json on this Mac — one source of truth.

ON EACH OTHER DEVICE (laptop, iPad, your wife's device)
  1. Install Tailscale and sign in with the same account (invite her as a shared
     user if it's her own account).
  2. Open https://$DNSNAME:$HTTPS_PORT  (add to Home Screen on iPad for an app icon).

Keep this Mac awake (System Settings -> Energy) — when it sleeps, the shared data
is unreachable until it wakes.

TO STOP SERVING
    $TS serve --https=$HTTPS_PORT off
TEXT
