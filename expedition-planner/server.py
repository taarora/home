#!/usr/bin/env python3
"""Expedition Planner sync server — dependency-free (Python standard library only).

Serves the static app AND a tiny JSON API backed by ONE trips.json, so every
device signed into your tailnet shares a single source of truth (no per-device
localStorage split, no export/import shuffle).

  GET  /api/health -> {"ok": true}
  GET  /api/state  -> {"rev": "<mtime-ns>", "state": {...} | null}
  PUT  /api/state  -> body {"rev"?: "...", "state": {...}} ; writes trips.json,
                      returns {"rev": "<new-mtime-ns>"}
  everything else  -> static files from this directory (index.html, workshops.json)

The data file doubles as a human-readable, import-compatible backup. Run it with
r.sh, and publish it privately over HTTPS with scripts/setup-tailscale.sh.

Binds 127.0.0.1 only — `tailscale serve` is what exposes it to your tailnet.
Env: PORT (default 8743), EXPEDITION_DATA_DIR (default the iCloud data folder).
"""
import json
import os
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

HERE = os.path.dirname(os.path.abspath(__file__))
PORT = int(os.environ.get("PORT", "8743"))
DATA_DIR = os.environ.get(
    "EXPEDITION_DATA_DIR",
    os.path.expanduser("~/Documents/Claude/Code/expedition-planner-data"),
)
DATA_FILE = os.path.join(DATA_DIR, "trips.json")
_lock = threading.Lock()

MIME = {
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".json": "application/json; charset=utf-8",
    ".svg": "image/svg+xml",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".ico": "image/x-icon",
    ".webmanifest": "application/manifest+json",
}


def read_state():
    """Return (state_dict_or_None, rev). rev is the file mtime in ns, as a string."""
    try:
        with open(DATA_FILE, "r", encoding="utf-8") as f:
            state = json.load(f)
        return state, str(os.stat(DATA_FILE).st_mtime_ns)
    except FileNotFoundError:
        return None, "0"
    except Exception as exc:  # corrupt file — surface null rather than crashing
        sys.stderr.write("WARN: could not read %s: %s\n" % (DATA_FILE, exc))
        return None, "0"


def write_state(state):
    """Atomically write trips.json; return the new rev (mtime ns)."""
    os.makedirs(DATA_DIR, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=DATA_DIR, suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(state, f, ensure_ascii=False, indent=2)
        os.replace(tmp, DATA_FILE)  # atomic on the same filesystem
    finally:
        if os.path.exists(tmp):
            try:
                os.remove(tmp)
            except OSError:
                pass
    return str(os.stat(DATA_FILE).st_mtime_ns)


class Handler(BaseHTTPRequestHandler):
    server_version = "ExpeditionPlanner/1.0"

    def _send_json(self, code, obj):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/api/health":
            return self._send_json(200, {"ok": True})
        if path == "/api/state":
            with _lock:
                state, rev = read_state()
            return self._send_json(200, {"rev": rev, "state": state})
        return self._serve_static(path)

    def do_PUT(self):
        path = urlparse(self.path).path
        if path != "/api/state":
            return self._send_json(404, {"error": "not found"})
        length = int(self.headers.get("Content-Length", "0") or "0")
        raw = self.rfile.read(length) if length else b"{}"
        try:
            payload = json.loads(raw.decode("utf-8"))
        except Exception:
            return self._send_json(400, {"error": "bad json"})
        state = payload.get("state", payload)
        if not isinstance(state, dict) or not isinstance(state.get("trips"), list):
            return self._send_json(400, {"error": "state must be an object with a trips array"})
        with _lock:
            rev = write_state(state)
        return self._send_json(200, {"rev": rev})

    def _serve_static(self, path):
        if path in ("/", ""):
            path = "/index.html"
        rel = os.path.normpath(path.lstrip("/"))
        if rel.startswith("..") or os.path.isabs(rel):
            return self._send_json(403, {"error": "forbidden"})
        full = os.path.join(HERE, rel)
        if not os.path.isfile(full):
            self.send_response(404)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.end_headers()
            self.wfile.write(b"Not found")
            return
        ext = os.path.splitext(full)[1].lower()
        try:
            with open(full, "rb") as f:
                data = f.read()
        except Exception:
            self.send_response(500)
            self.end_headers()
            return
        self.send_response(200)
        self.send_header("Content-Type", MIME.get(ext, "application/octet-stream"))
        self.send_header("Content-Length", str(len(data)))
        if ext in (".html", ".json"):
            self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def main():
    os.makedirs(DATA_DIR, exist_ok=True)
    httpd = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    sys.stderr.write(
        "Expedition Planner server on http://127.0.0.1:%d  (data: %s)\n" % (PORT, DATA_FILE)
    )
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
