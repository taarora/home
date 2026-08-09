#!/bin/bash
# Start / restart the Expedition Planner local preview and open it in Chrome.
#
# Expedition Planner is a static single-file app, so this just serves the
# folder over HTTP (needed so the Workshops tab can fetch workshops.json —
# opening index.html via file:// won't work). Live version:
# https://taarora.github.io/home/expedition-planner/

DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=8743
LOG="$DIR/preview.log"
# IMPORTANT: always use the "localhost" origin. The browser keys saved trips
# (localStorage) to the exact origin, and http://localhost and http://127.0.0.1
# are DIFFERENT buckets — opening the wrong one makes your trips look "gone".
URL="http://localhost:${PORT}/"

echo "🔍 Checking for a running preview on port ${PORT}…"

# Two ways in: by the http.server command line, and by whatever holds the port.
PIDS=$(pgrep -f "http.server ${PORT}" 2>/dev/null)
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

echo "🚀 Starting preview…"
cd "$DIR" || exit 1
nohup python3 -m http.server "$PORT" > "$LOG" 2>&1 &

echo "⏳ Waiting for the server…"
for i in $(seq 1 20); do
  sleep 0.5
  if curl -s -o /dev/null "$URL"; then
    echo "✅ Up at $URL  (log: $LOG)"
    open -a "Google Chrome" "$URL" 2>/dev/null || open "$URL" 2>/dev/null
    exit 0
  fi
done

echo "❌ Didn't start in time — check $LOG"
tail -20 "$LOG"
exit 1
