"""CLIs must not drop fetched content on a legacy console codepage (Windows cp949)."""
from __future__ import annotations

import os
import subprocess
import sys
import unittest
from pathlib import Path

ENGINE_ROOT = str(Path(__file__).resolve().parents[2])
TEXT = "fixture – \U0001F600"  # en dash and emoji: neither is encodable in cp949

ENGINE_CLI = f"""
import sys
from engine import FetchResult, __main__ as cli
cli.fetch = lambda *a, **k: FetchResult(ok=True, content={TEXT!r}, final_url="https://example.com/")
sys.exit(cli.main(["https://example.com/"]))
"""

X_SEARCH_CLI = f"""
import sys
from engine import x_search
from engine.x_search_types import XSearchResult
x_search.search_x = lambda *a, **k: XSearchResult(True, "q", (), (), {TEXT!r}, {{}}, ())
sys.argv = ["x_search", "q"]
sys.exit(x_search.main())
"""


def _run(code: str) -> subprocess.CompletedProcess[bytes]:
    env = dict(os.environ, PYTHONIOENCODING="cp949", PYTHONPATH=ENGINE_ROOT)
    env.pop("PYTHONUTF8", None)
    return subprocess.run([sys.executable, "-c", code], env=env, capture_output=True, timeout=60)


class ConsoleEncodingTests(unittest.TestCase):
    def test_engine_cli_prints_content_on_cp949_console(self) -> None:
        proc = _run(ENGINE_CLI)
        self.assertNotIn(b"UnicodeEncodeError", proc.stderr, proc.stderr.decode("utf-8", "replace"))
        self.assertIn(TEXT, proc.stdout.decode("utf-8"))

    def test_x_search_cli_prints_json_on_cp949_console(self) -> None:
        proc = _run(X_SEARCH_CLI)
        self.assertEqual(proc.returncode, 0, proc.stderr.decode("utf-8", "replace"))
        self.assertIn(TEXT, proc.stdout.decode("utf-8"))


if __name__ == "__main__":
    unittest.main()
