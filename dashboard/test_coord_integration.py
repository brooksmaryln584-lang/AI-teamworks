"""Optional real-coord integration; creates and stops its own isolated daemon."""
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import time
import unittest
from urllib.request import ProxyHandler, Request, build_opener
from uuid import uuid4

from dashboard.server import CoordClient, Snapshot


@unittest.skipUnless(shutil.which("coord"), "coord executable is not installed")
class Integration(unittest.TestCase):
    def test_real_task_lifecycle(self):
        run = uuid4().hex
        directory = Path(__file__).resolve().parents[1] / "runs" / ("coord-integration-" + run)
        directory.mkdir(parents=True)
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        url = f"http://127.0.0.1:{port}/"
        opener = build_opener(ProxyHandler({}))

        def rpc(method, params):
            body = json.dumps({"jsonrpc": "2.0", "id": run, "method": method, "params": params}).encode()
            with opener.open(Request(url, data=body, headers={"Content-Type": "application/json"}), timeout=2) as response:
                result = json.load(response)
            self.assertNotIn("error", result)
            return result["result"]

        with (directory / "daemon.log").open("w") as log:
            process = subprocess.Popen([shutil.which("coord"), "serve", "--addr", f"127.0.0.1:{port}", "--db", str(directory / "state.sqlite")], stdout=log, stderr=log, creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
            try:
                client = CoordClient(url, timeout=1)
                for _ in range(40):
                    try:
                        client.read()
                        break
                    except OSError:
                        if process.poll() is not None:
                            self.fail("coord exited during startup")
                        time.sleep(.1)
                else:
                    self.fail("coord did not start")
                identity = "test-only-" + run
                rpc("agents/heartbeat", {"id": identity, "name": "Isolated integration fixture"})
                created = rpc("tasks/send", {"name": "Dashboard fixture <script>not HTML</script>", "payload": {"teamworks": {"tool": "opencode", "model": "test-fixture", "scope": ["src/example/**"], "handoff": "reports/example.md"}}})
                task_id = created["id"]
                self.assertEqual(Snapshot(client).get()["tasks"][0]["state"], "pending")
                rpc("tasks/claim", {"id": task_id, "agentId": identity, "leaseSeconds": 120})
                claimed = Snapshot(client).get()
                self.assertEqual(claimed["tasks"][0]["claimed_by"], identity)
                self.assertEqual(claimed["tasks"][0]["state"], "claimed")
                self.assertEqual(claimed["tasks"][0]["meta"]["tool"], "opencode")
                self.assertGreater(claimed["tasks"][0]["lease_seconds"], 0)
                self.assertEqual(claimed["agents"][0]["id"], identity)
                rpc("tasks/complete", {"id": task_id})
                self.assertEqual(Snapshot(client).get()["tasks"][0]["state"], "completed")
            finally:
                process.terminate()
                process.wait(timeout=5)
        self.assertFalse(Snapshot(client).get()["connected"])


if __name__ == "__main__":
    unittest.main()
