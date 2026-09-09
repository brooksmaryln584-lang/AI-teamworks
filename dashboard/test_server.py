"""Behavior and HTTP boundary checks. Run: python -m unittest dashboard.test_server -v"""
from contextlib import contextmanager
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import threading
import unittest
from urllib.error import HTTPError
from urllib.request import ProxyHandler, Request, build_opener

from dashboard.server import CoordClient, Snapshot, clean, local_coord_url, make_server, normalize


@contextmanager
def running(server):
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield f"http://127.0.0.1:{server.server_port}"
    finally:
        server.shutdown()
        server.server_close()
        thread.join(3)


class FakeClient:
    url = "http://127.0.0.1:7777/"

    def read(self):
        return [], []


class Tests(unittest.TestCase):
    def test_target_restrictions(self):
        self.assertEqual(local_coord_url("http://localhost:7777"), "http://127.0.0.1:7777/")
        for target in ["https://example.com", "http://0.0.0.0:7777", "http://user:pass@localhost", "http://localhost/secrets", "http://localhost/?target=x"]:
            with self.subTest(target=target), self.assertRaises(ValueError):
                local_coord_url(target)

    def test_projection_does_not_leak_raw_payload_or_results(self):
        data = normalize([{"id": "1", "name": "Task", "payload": {"api_key": "private", "prompt": "secret", "teamworks": {"tool": "opencode", "model": "DeepSeek", "scope": ["src/**"]}}, "result": {"secret": "private"}}], [], datetime.now(timezone.utc))
        self.assertNotIn("private", json.dumps(data))
        self.assertNotIn("prompt", json.dumps(data))
        self.assertEqual(data["tasks"][0]["meta"]["tool"], "opencode")

    def test_redacts_recognizable_secrets(self):
        self.assertNotIn("very-secret", clean("token=very-secret"))
        self.assertIn("[REDACTED]", clean("ghp_" + "x" * 30))

    def test_unknown_times_and_stale_heartbeat(self):
        now = datetime(2026, 9, 9, tzinfo=timezone.utc)
        data = normalize([{"lease_until": "bad"}], [{"last_seen": "bad"}, {"last_seen": "2020-01-01T00:00:00Z"}], now)
        self.assertIsNone(data["tasks"][0]["lease_seconds"])
        self.assertEqual([a["presence"] for a in data["agents"]], ["unknown", "stale"])

    def test_recent_window_is_explicit(self):
        result = normalize([{} for _ in range(201)], [], datetime.now(timezone.utc))
        self.assertEqual(len(result["tasks"]), 200)
        self.assertTrue(result["truncated"])

    def test_failure_is_not_empty_success(self):
        class Broken(FakeClient):
            def read(self):
                raise OSError("private internal detail")
        data = Snapshot(Broken()).get()
        self.assertFalse(data["connected"])
        self.assertNotIn("tasks", data)
        self.assertNotIn("private", json.dumps(data))

    def test_demo_never_queries_coord(self):
        class Never(FakeClient):
            def read(self):
                raise AssertionError("Demo called live service")
        data = Snapshot(Never(), demo=True).get()
        self.assertEqual(data["mode"], "demo")
        self.assertEqual(len(data["tasks"]), 4)

    def test_real_rpc_contract_and_no_mutations(self):
        calls = []
        class Upstream(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass
            def do_POST(self):
                body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                calls.append(body)
                self.send_response(200)
                self.end_headers()
                self.wfile.write(json.dumps({"jsonrpc": "2.0", "id": body["id"], "result": []}).encode())
        with running(ThreadingHTTPServer(("127.0.0.1", 0), Upstream)) as url:
            client = CoordClient(url)
            self.assertEqual(client.read(), ([], []))
            with self.assertRaises(ValueError):
                client.rpc("tasks/complete", {})
        self.assertEqual([c["method"] for c in calls], ["tasks/list", "agents/list"])

    def test_bad_rpc_and_redirect_rejected(self):
        for redirect in [False, True]:
            class Upstream(BaseHTTPRequestHandler):
                def log_message(self, *_):
                    pass
                def do_POST(self):
                    self.rfile.read(int(self.headers["Content-Length"]))
                    self.send_response(302 if redirect else 200)
                    if redirect:
                        self.send_header("Location", "http://example.invalid/")
                    self.send_header("Content-Length", "14")
                    self.end_headers()
                    self.wfile.write(b'{"result": {}}')
            with running(ThreadingHTTPServer(("127.0.0.1", 0), Upstream)) as url:
                with self.assertRaises((ValueError, HTTPError)):
                    CoordClient(url).read()

    def test_http_surface_blocks_wrong_host_origin_and_mutations(self):
        opener = build_opener(ProxyHandler({}))
        with running(make_server(0, Snapshot(FakeClient()))) as url:
            with opener.open(url + "/api/snapshot") as response:
                self.assertTrue(json.load(response)["connected"])
                self.assertEqual(response.headers["Cache-Control"], "no-store")
            for headers in [{"Host": "evil.example"}, {"Origin": "https://evil.example"}]:
                with self.assertRaises(HTTPError) as raised:
                    opener.open(Request(url + "/api/snapshot", headers=headers))
                self.assertEqual(raised.exception.code, 403)
            for path in ["/../LICENSE", "/api/complete", "/runs/private.json"]:
                with self.assertRaises(HTTPError) as raised:
                    opener.open(url + path)
                self.assertEqual(raised.exception.code, 404)
            with self.assertRaises(HTTPError) as raised:
                opener.open(Request(url + "/api/snapshot", data=b"{}"))
            self.assertEqual(raised.exception.code, 501)
            with opener.open(url) as response:
                self.assertIn("AI-teamworks", response.read().decode())


if __name__ == "__main__":
    unittest.main()
