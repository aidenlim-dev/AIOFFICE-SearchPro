#!/usr/bin/env python3
"""U9 tests - Playwright tier routing and failure-gate diagnostics.

Network-free. Locks in the two-tier Playwright model:
  * MCP is an agent-driven JS tier, not the universal final fallback
  * real-TLS profiles report local Chrome setup/runtime issues instead
  * MCP handoff markers do not consume the local browser attempt budget

Run:  python3 engine/tests/test_u9.py
"""
from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, ROOT)

from engine import fetch_chain as fc  # noqa: E402
from engine.fetch_chain import Attempt, _fallback_order_for_profile, _untried_routes  # noqa: E402
from engine.validators import Verdict  # noqa: E402


REAL_TLS_PROFILE = {
    "capabilities_needed": ["needs_real_tls_stack", "needs_js_exec"],
    "fallback_when_challenge": ["curl_grid_exhaust", "playwright_real_chrome"],
}

JS_ONLY_PROFILE = {
    "capabilities_needed": ["needs_js_exec"],
    "fallback_when_challenge": ["playwright_mcp", "playwright_real_chrome"],
}


def t_real_tls_profile_does_not_require_mcp() -> None:
    trace = [
        Attempt(
            phase="fallback",
            executor="playwright_real_chrome",
            url="https://example.test/",
            url_transform="original",
            impersonate=None,
            referer="",
            verdict=Verdict.UNKNOWN.value,
            error="missing local Playwright dependency",
        )
    ]
    routes, must_mcp = _untried_routes(
        "exhausted", True, profile=REAL_TLS_PROFILE, trace=trace)

    assert must_mcp is False, routes
    assert not any("playwright_mcp" in r for r in routes), routes
    assert any("local Playwright setup/runtime failed" in r for r in routes), routes
    print("  ok real-TLS profile reports local Chrome, not mandatory MCP")


def t_js_only_profile_requires_mcp_handoff() -> None:
    routes, must_mcp = _untried_routes(
        "exhausted", True, profile=JS_ONLY_PROFILE, trace=[])

    assert must_mcp is True, routes
    assert any("playwright_mcp" in r for r in routes), routes
    print("  ok JS-only profile exposes MCP handoff")


def t_empty_profile_matches_runtime_default() -> None:
    assert _fallback_order_for_profile({}) == ["playwright_real_chrome"]
    print("  ok empty profile defaults to local real-Chrome fallback")


class _Resp:
    status_code = 200
    text = "<html>" + ("x" * 5000) + "Just a moment..." + "</html>"
    headers = {}
    cookies = type("C", (), {"jar": iter(())})()
    url = "https://example.test/"


class _Hit:
    profile_id = "cloudflare_turnstile"
    confidence = 0.9
    signals = ["body:Just a moment..."]


def t_mcp_stub_does_not_consume_local_browser_budget() -> None:
    old_run_attempt = fc._run_attempt
    old_build_plan = fc._build_plan
    old_detect = fc.detect

    import engine.executor as ex
    old_pw = ex.run_playwright_fallback

    calls: list[str] = []

    def fake_run_attempt(*_args, phase="probe", **_kwargs):
        return (
            Attempt(
                phase=phase,
                executor="curl_cffi",
                url="https://example.test/",
                url_transform="original",
                impersonate="safari",
                referer="self_root",
                status=200,
                body_size=len(_Resp.text),
                verdict=Verdict.CHALLENGE.value,
            ),
            _Resp(),
        )

    def fake_pw(url, *, force_executor=None, **_kwargs):
        calls.append(force_executor or "")
        if (force_executor or "").startswith("playwright_mcp"):
            return (
                Attempt(
                    phase="fallback",
                    executor=force_executor or "playwright_mcp",
                    url=url,
                    url_transform="original",
                    impersonate=None,
                    referer="",
                    verdict=Verdict.UNKNOWN.value,
                    error="Playwright MCP must be invoked from the Claude session",
                ),
                "",
            )
        return (
            Attempt(
                phase="fallback",
                executor=force_executor or "playwright_real_chrome",
                url=url,
                url_transform="original",
                impersonate=None,
                referer="",
                status=200,
                body_size=5000,
                verdict=Verdict.STRONG_OK.value,
            ),
            "<html><main>ok</main>" + ("x" * 5000) + "</html>",
        )

    try:
        fc._run_attempt = fake_run_attempt
        fc._build_plan = lambda *_args, **_kwargs: []
        fc.detect = lambda *_args, **_kwargs: [_Hit()]
        ex.run_playwright_fallback = fake_pw

        result = fc._fetch_core(
            "https://example.test/",
            success_selectors=None,
            timeout=1,
            max_attempts=1,
            max_browser_attempts=1,
            enable_playwright=True,
            enable_phase0=False,
        )
    finally:
        fc._run_attempt = old_run_attempt
        fc._build_plan = old_build_plan
        fc.detect = old_detect
        ex.run_playwright_fallback = old_pw

    assert result.ok, result.summary
    assert calls == ["playwright_mcp", "playwright_real_chrome"], calls
    print("  ok MCP handoff marker does not consume real-Chrome attempt budget")


ALL = [
    ("real_tls_profile_does_not_require_mcp", t_real_tls_profile_does_not_require_mcp),
    ("js_only_profile_requires_mcp_handoff", t_js_only_profile_requires_mcp_handoff),
    ("empty_profile_matches_runtime_default", t_empty_profile_matches_runtime_default),
    ("mcp_stub_does_not_consume_local_browser_budget", t_mcp_stub_does_not_consume_local_browser_budget),
]


def main() -> int:
    p = f = 0
    for name, fn in ALL:
        try:
            print(f"[{name}]")
            fn()
            p += 1
        except AssertionError as e:
            f += 1
            print(f"  x FAIL: {e}")
        except Exception as e:
            f += 1
            print(f"  x ERROR: {type(e).__name__}: {e}")
    print(f"\n{p} passed, {f} failed")
    return 0 if f == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
