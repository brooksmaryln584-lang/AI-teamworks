"""Local coord viewer. Python 3.10+, standard library only, no mutation RPCs."""
from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from http.client import HTTPException
import json
import os
from pathlib import Path
import re
import threading
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, ProxyHandler, Request, build_opener
import webbrowser

VERSION = "1.2.0"
STATIC = Path(__file__).parent / "static"
LIMIT = 200
MAX_RESPONSE = 4 * 1024 * 1024


def utcnow():
    return datetime.now(timezone.utc)


def clean(value, limit=500):
    if not isinstance(value, (str, int, float)) or isinstance(value, bool):
        return ""
    text = str(value)[:limit]
    text = re.sub(r"(?i)\b(?:sk-[\w-]{12,}|gh[pousr]_[\w]{12,}|github_pat_[\w]+)", "[REDACTED]", text)
    text = re.sub(r"(?i)((?:api[_ -]?key|token|password|authorization)\s*[:=]\s*)\S+", r"\1[REDACTED]", text)
    return text


def parsed_time(value):
    try:
        result = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        return result if result.tzinfo else result.replace(tzinfo=timezone.utc)
    except (ValueError, TypeError):
        return None


def local_coord_url(value):
    parsed = urlsplit(value)
    if (parsed.scheme != "http" or parsed.hostname not in ("127.0.0.1", "localhost")
            or parsed.username or parsed.password or parsed.query or parsed.fragment
            or parsed.path not in ("", "/")):
        raise ValueError("coord URL must be http://127.0.0.1:PORT/ or http://localhost:PORT/")
    port = parsed.port or 80
    if not 1 <= port <= 65535:
        raise ValueError("Invalid port")
    # Pin localhost to IPv4 loopback; ignore machine proxy configuration.
    return f"http://127.0.0.1:{port}/"


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class CoordClient:
    def __init__(self, url, timeout=3):
        self.url = local_coord_url(url)
        self.timeout = timeout
        self.opener = build_opener(ProxyHandler({}), NoRedirect())

    def rpc(self, method, params):
        if method not in ("tasks/list", "agents/list"):
            raise ValueError("Only listing methods are supported")
        body = json.dumps({"jsonrpc": "2.0", "id": "teamworks-view", "method": method, "params": params}).encode()
        request = Request(self.url, data=body, headers={"Content-Type": "application/json"})
        with self.opener.open(request, timeout=self.timeout) as response:
            # Redirects must not move a local query to an external host.
            if response.geturl() != self.url:
                raise ValueError("Unexpected coord redirect")
            raw = response.read(MAX_RESPONSE + 1)
        if len(raw) > MAX_RESPONSE:
            raise ValueError("coord response exceeds size limit")
        data = json.loads(raw)
        if not isinstance(data, dict) or data.get("error") or not isinstance(data.get("result"), list):
            raise ValueError("Unexpected JSON-RPC response")
        if not all(isinstance(row, dict) for row in data["result"]):
            raise ValueError("Unexpected row format")
        return data["result"]

    def read(self):
        return self.rpc("tasks/list", {"limit": LIMIT + 1}), self.rpc("agents/list", {})


def normalize(tasks, agents, now):
    rows = []
    for task in tasks[:LIMIT]:
        row = {key: clean(task.get(key)) for key in
               ("id", "name", "kind", "priority", "state", "claimed_by", "created_at", "updated_at", "lease_until")}
        deadline = parsed_time(task.get("lease_until"))
        row["lease_seconds"] = int((deadline - now).total_seconds()) if deadline else None
        payload = task.get("payload")
        meta = payload.get("teamworks", {}) if isinstance(payload, dict) else {}
        meta = meta if isinstance(meta, dict) else {}
        row["meta"] = {key: clean(meta.get(key)) for key in ("tool", "model", "role", "blocker", "handoff", "project")}
        scope = meta.get("scope", [])
        row["meta"]["scope"] = [clean(item) for item in scope[:20]] if isinstance(scope, list) else []
        # Do not expose arbitrary payload/result: they can contain prompts or credentials.
        rows.append(row)
    people = []
    for agent in agents[:1000]:
        seen = parsed_time(agent.get("last_seen"))
        age = max(0, int((now - seen).total_seconds())) if seen else None
        people.append({**{key: clean(agent.get(key)) for key in ("id", "name", "current_task", "last_seen")},
                       "age_seconds": age, "presence": "unknown" if age is None else "recent" if age < 120 else "stale"})
    return {"tasks": rows, "agents": people, "task_limit": LIMIT, "truncated": len(tasks) > LIMIT,
            "agents_truncated": len(agents) > 1000}


def demo_data(now):
    def ago(seconds):
        return (now - timedelta(seconds=seconds)).isoformat()
    def task(number, name, state, tool, model, scope, **extra):
        return {"id": f"demo-task-{number}", "name": name, "state": state, "priority": "normal",
                "kind": "task", "claimed_by": f"demo-{tool}" if state == "claimed" else None,
                "created_at": ago(900), "updated_at": ago(20),
                "lease_until": (now + timedelta(seconds=240)).isoformat() if state == "claimed" else None,
                "payload": {"teamworks": {"tool": tool, "model": model, "role": "executor", "scope": [scope], **extra}}}
    tasks = [task(1, "补充搜索接口与边界检查", "claimed", "opencode", "DeepSeek（示例）", "src/search/**"),
             task(2, "整理设置页交互与可访问性", "claimed", "zcode", "GLM（示例）", "src/settings/**"),
             task(3, "复核接口契约", "pending", "codex", "用户选择", "tests/**", blocker="等待执行者交接"),
             task(4, "项目结构与实施计划", "completed", "claude", "用户选择", "docs/plan.md", handoff="reports/demo-handoff.md")]
    agents = [{"id": f"demo-{tool}", "name": name, "last_seen": ago(age), "current_task": task_id}
              for tool, name, age, task_id in [("opencode", "OpenCode · 执行", 12, "demo-task-1"),
                                             ("zcode", "ZCode · 执行", 30, "demo-task-2"),
                                             ("codex", "Codex · 复核", 70, None),
                                             ("claude", "Claude Code · 规划", 360, None)]]
    return tasks, agents


class Snapshot:
    def __init__(self, client, demo=False):
        self.client, self.demo = client, demo
        self.lock = threading.Lock()
        self.cached = None
        self.at = 0

    def get(self):
        with self.lock:
            if self.cached is not None and time.monotonic() - self.at < 2:
                return self.cached
            now = utcnow()
            base = {"version": VERSION, "mode": "demo" if self.demo else "live", "source": self.client.url,
                    "observed_at": now.isoformat()}
            try:
                tasks, agents = demo_data(now) if self.demo else self.client.read()
                result = {**base, "connected": True, **normalize(tasks, agents, now)}
            except (OSError, ValueError, URLError, HTTPError, HTTPException):
                result = {**base, "connected": False, "error": "coord 连接失败或响应格式不兼容，请确认服务地址与版本。"}
            self.cached, self.at = result, time.monotonic()
            return result


def make_server(port, snapshot):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass  # Never log task payloads or URLs containing user input.

        def send_body(self, code, body, content_type):
            self.send_response(code)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'")
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            allowed = {f"127.0.0.1:{self.server.server_port}", f"localhost:{self.server.server_port}"}
            host = self.headers.get("Host", "")
            origin = self.headers.get("Origin")
            if host not in allowed or (origin and origin not in {"http://" + h for h in allowed}):
                return self.send_body(403, b"Forbidden", "text/plain")
            path = urlsplit(self.path).path
            if path == "/api/snapshot":
                result = snapshot.get()
                return self.send_body(200 if result["connected"] else 503,
                                      json.dumps(result, ensure_ascii=False).encode(), "application/json; charset=utf-8")
            assets = {"/": ("index.html", "text/html"), "/app.js": ("app.js", "text/javascript"),
                      "/style.css": ("style.css", "text/css")}
            if path not in assets:
                return self.send_body(404, b"Not found", "text/plain")
            filename, mime = assets[path]
            self.send_body(200, (STATIC / filename).read_bytes(), mime + "; charset=utf-8")

    return ThreadingHTTPServer(("127.0.0.1", port), Handler)


def main():
    parser = argparse.ArgumentParser(description="AI-teamworks local coord dashboard")
    parser.add_argument("--coord-url", default="http://127.0.0.1:7777/")
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--demo", action="store_true", help="Use clearly labeled synthetic data; never query coord")
    parser.add_argument("--open", action="store_true", help="Open the local dashboard in your browser")
    parser.add_argument("--process-file", type=Path, help="Write this server's actual PID to a new local JSON file")
    args = parser.parse_args()
    try:
        client = CoordClient(args.coord_url)
        if not 1 <= args.port <= 65535:
            raise ValueError("Invalid dashboard port")
        server = make_server(args.port, Snapshot(client, args.demo))
    except (ValueError, OSError) as exc:
        parser.error(str(exc))
    url = f"http://127.0.0.1:{server.server_port}/"
    if args.process_file:
        try:
            with args.process_file.open("x", encoding="utf-8") as record:
                json.dump({"pid": os.getpid(), "port": server.server_port}, record)
        except OSError as exc:
            server.server_close()
            parser.error(f"Cannot create process record: {exc}")
    print(f"AI-teamworks {VERSION}: {url} ({'DEMO' if args.demo else 'LIVE'})", flush=True)
    if args.open:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
