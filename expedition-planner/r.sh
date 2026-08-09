#!/bin/bash
# Start / restart the Expedition Planner sync server (server.py) and open it.
#
# server.py serves the app AND a tiny JSON API backed by one trips.json, so every
# device on your tailnet shares one source of truth. Run this on the always-on Mac
# (the Mac Studio). Publish it privately over HTTPS with scripts/setup-tailscale.sh.
# Live standalone (localStorage-only) copy: https://taarora.github.io/home/expedition-planner/

DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=8743
LOG="$DIR/preview.log"
# Always the "localhost" origin — http://localhost and http://127.0.0.1 are separate
# localStorage buckets, and opening the wrong one makes saved trips look "gone".
URL="http://localhost:${PORT}/"

echo "🔍 Checking for a running server on port ${PORT}…"
PIDS=$(pgrep -f "$DIR/server.py" 2>/dev/null)
PORT_PIDS=$(lsof -ti tcp:${PORT} 2>/dev/null)
ALL=$(echo "$PIDS $PORT_PIDS" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)

if [ -n "$ALL" ]; then
  echo "🛑 Stopping process(es): $ALL"
  kill $ALL 2>/dev/null
  sleep 1
  STILL=$(lsof -ti tcp:${PORT} 2>/dev/null)
  if [ -n "$STILL" ]; then
    echo "   …still up, forcing: $STILL"
    kill -9 $STILL 2>/dev/null
    sleep 0.5
  fi
  echo "✅ Stopped."
else
  echo "ℹ️  Nothing running."
fi

echo "🚀 Starting sync server…"
cd "$DIR" || exit 1
nohup python3 server.py > "$LOG" 2>&1 &

echo "⏳ Waiting for the server…"
for i in $(seq 1 20); do
  sleep 0.5
  if curl -s -o /dev/null "http://127.0.0.1:${PORT}/api/health"; then
    echo "✅ Up at $URL  (log: $LOG)"

    # Trip count from the shared store, so a wrong data path is obvious immediately.
    COUNT=$(curl -s "http://127.0.0.1:${PORT}/api/state" 2>/dev/null \
            | python3 -c "import json,sys;s=json.load(sys.stdin).get('state') or {};print(len(s.get('trips',[])))" 2>/dev/null)
    [ -n "$COUNT" ] && echo "🗂  Shared trips.json: $COUNT trip(s)"

    # Where other devices reach it (the whole point of the sync server).
    TS=""
    if command -v tailscale >/dev/null 2>&1; then TS=tailscale
    elif [ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then TS=/Applications/Tailscale.app/Contents/MacOS/Tailscale; fi
    if [ -n "$TS" ] && "$TS" status >/dev/null 2>&1; then
      TSNAME=$("$TS" status --json 2>/dev/null \
               | python3 -c "import json,sys;print(json.load(sys.stdin)['Self']['DNSName'].rstrip('.'))" 2>/dev/null)
      if [ -n "$TSNAME" ] && "$TS" serve status 2>/dev/null | grep -q "127.0.0.1:$PORT"; then
        echo "📱 Other devices: https://$TSNAME:8443"
      elif [ -n "$TSNAME" ]; then
        echo "📱 Tailscale up but not serving yet — run ./scripts/setup-tailscale.sh once"
      fi
    fi

    # Cache-buster so Chrome loads a FRESH page instead of re-focusing a stale tab.
    # Same origin (only the query differs), so saved data / sync are unaffected.
    FRESH="${URL}?t=$(date +%s)"
    open -a "Google Chrome" "$FRESH" 2>/dev/null || open "$FRESH" 2>/dev/null
    exit 0
  fi
done

echo "❌ Didn't start in time — check $LOG"
tail -20 "$LOG"
exit 1
