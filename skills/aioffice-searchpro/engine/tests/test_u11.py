#!/usr/bin/env python3
"""U11 regression tests for shared Node dependencies and browser defaults."""
from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
from types import SimpleNamespace
from unittest.mock import patch

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, ROOT)

from engine import executor as ex  # noqa: E402
from engine.waf_detector import load_profile  # noqa: E402


def run() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        templates = os.path.join(tmp, "templates")
        shared = os.path.join(tmp, "shared")
        os.makedirs(os.path.join(shared, "node_modules", "playwright"))
        os.makedirs(templates)
        package = {"name": "test", "dependencies": {"playwright": "1.0.0"}}
        for root in (templates, shared):
            with open(os.path.join(root, "package-lock.json"), "w", encoding="utf-8") as file:
                json.dump(package, file)

        with patch.object(ex, "TEMPLATES_DIR", templates):
            with open(os.path.join(shared, ex.NODE_DEPS_STAMP), "w", encoding="ascii") as stamp:
                stamp.write(ex._node_manifest_fingerprint())
            assert ex._shared_node_deps_current(shared)

        template = os.path.join(templates, "probe.js")
        with open(template, "w", encoding="utf-8") as file:
            file.write("process.stdout.write('ok')")
        completed = SimpleNamespace(returncode=0, stdout="ok", stderr="")
        with patch.object(ex, "TEMPLATES_DIR", templates), \
             patch("engine.executor.subprocess.run", return_value=completed) as run_node:
            rc, stdout, stderr = ex._run_node_template("probe.js", {}, deps_root=shared)
        assert (rc, stdout, stderr) == (0, "ok", "")
        assert run_node.call_args.kwargs["env"]["NODE_PATH"].split(os.pathsep)[0] == os.path.join(
            shared, "node_modules",
        )

    with patch.dict(os.environ, {"AIOFFICE_SEARCHPRO_NODE_DEPS_DIR": "/tmp/aioffice-node"}):
        assert ex._default_node_deps_dir() == "/tmp/aioffice-node"

    profile = load_profile("unknown_challenge")
    assert profile["fallback_when_challenge"] == [
        "playwright_mcp", "protocol_stealth_chrome", "playwright_real_chrome",
    ]

    template_root = os.path.join(ROOT, "engine", "templates")
    with open(os.path.join(template_root, "nodriver_fetch.py"), encoding="utf-8") as file:
        assert 'args.get("headless", False)' in file.read()
    with open(os.path.join(template_root, "patchright_fetch.py"), encoding="utf-8") as file:
        assert 'args.get("headless", False)' in file.read()

    rendered = "<html><body>" + ("content " * 1000) + "</body></html>"
    completed = (0, rendered, "")
    with patch("engine.executor._resolve_node_deps", return_value="/tmp/deps"), \
         patch("engine.executor._run_node_template", return_value=completed) as run_node:
        ex.run_playwright_fallback(
            "https://example.com", profile_id="unknown_challenge",
            force_executor="playwright_real_chrome", headless=True,
        )
    assert run_node.call_args.args[1]["headless"] is True

    assert shutil.which("node") is not None
    print("7 passed, 0 failed")


if __name__ == "__main__":
    run()
