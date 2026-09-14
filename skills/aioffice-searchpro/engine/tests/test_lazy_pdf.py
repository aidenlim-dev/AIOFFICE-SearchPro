"""Fresh-process checks for optional PDF parser loading."""
import json
import os
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class LazyPdfTests(unittest.TestCase):
    def probe(self, source: str):
        result = subprocess.run(
            [sys.executable, "-c", source], cwd=ROOT,
            env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
            capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_html_engine_startup_does_not_load_pdf_parsers(self) -> None:
        result = self.probe(
            "import engine, json, sys\n"
            "print(json.dumps([name for name in ('pypdf','pdfplumber') if name in sys.modules]))"
        )
        self.assertEqual(result, [])

    def test_oversized_pdf_rejects_before_loading_parsers(self) -> None:
        result = self.probe(
            "import engine.fetch_chain as fc, json, sys\n"
            "fc._PDF_MAX_BYTES=2\n"
            "result=fc._extract_pdf(b'%PDF-body','https://example.com/document.pdf')\n"
            "print(json.dumps({'error':result[3],'loaded':[n for n in ('pypdf','pdfplumber') if n in sys.modules]}))"
        )
        self.assertEqual(result["error"], "pdf_too_large")
        self.assertEqual(result["loaded"], [])

    def test_missing_optional_parsers_keep_unavailable_result(self) -> None:
        result = self.probe(
            "import sys,json\n"
            "sys.modules['pypdf']=None\n"
            "sys.modules['pdfplumber']=None\n"
            "import engine.fetch_chain as fc\n"
            "print(json.dumps(fc._extract_pdf(b'%PDF-body','https://example.com/document.pdf')))"
        )
        self.assertEqual(result, ["", "", 0.0, "pdf_no_extractor"])


if __name__ == "__main__":
    unittest.main()
