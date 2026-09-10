from __future__ import annotations

import json
import os
import sys
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlsplit
from urllib.request import Request, urlopen


class SmokeFailure(RuntimeError):
    pass


def request_json(url: str, method: str, headers: dict[str, str], body: bytes | None = None) -> tuple[int, dict[str, str], Any]:
    request = Request(url, data=body, headers=headers, method=method)
    try:
        with urlopen(request, timeout=20) as response:
            raw = response.read()
            status = response.status
            response_headers = {key.lower(): value for key, value in response.headers.items()}
    except HTTPError as error:
        raw = error.read()
        status = error.code
        response_headers = {key.lower(): value for key, value in error.headers.items()}
    except URLError as error:
        raise SmokeFailure(f"{method} {safe_origin(url)} failed: {error.reason}") from error

    if not raw.strip():
        return status, response_headers, None
    try:
        return status, response_headers, json.loads(raw)
    except json.JSONDecodeError:
        return status, response_headers, raw.decode("utf-8", errors="replace")


def safe_origin(url: str) -> str:
    parsed = urlsplit(url)
    return f"{parsed.scheme}://{parsed.netloc}"


def require_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SmokeFailure(f"missing required environment variable: {name}")
    return value


def main() -> int:
    session_id = require_env("THIP_BMS_SESSION_ID")
    app_origin = os.environ.get(
        "THIP_APP_ORIGIN",
        "https://thip-kpi-10929.kube.bmscloud.in.th",
    ).strip()
    app_identifier = os.environ.get("THIP_BMS_APP_IDENTIFIER", "THIP.KPI.BMS").strip()
    paste_json_url = os.environ.get("THIP_PASTE_JSON_URL", "https://hosxp.net/phapi/PasteJSON").strip()

    session_status, _, session_payload = request_json(
        f"{paste_json_url}?Action=GET&code={quote(session_id)}",
        "GET",
        {"Accept": "application/json"},
    )
    if session_status != 200 or not isinstance(session_payload, dict):
        raise SmokeFailure(f"PasteJSON returned HTTP {session_status}")

    result = session_payload.get("result") or {}
    info = result.get("user_info") or {}
    api_url = str(info.get("bms_url") or "").strip().rstrip("/")
    bearer = str(info.get("bms_session_code") or result.get("key_value") or "").strip()
    if not api_url or not bearer:
        raise SmokeFailure("PasteJSON response has no BMS API URL or session token")

    api_sql_url = f"{api_url}/api/sql"
    preflight_status, preflight_headers, _ = request_json(
        api_sql_url,
        "OPTIONS",
        {
            "Origin": app_origin,
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "authorization,content-type",
        },
    )
    allow_origin = preflight_headers.get("access-control-allow-origin", "")
    allow_methods = preflight_headers.get("access-control-allow-methods", "").lower()
    allow_headers = preflight_headers.get("access-control-allow-headers", "").lower()
    vary = preflight_headers.get("vary", "").lower()
    if preflight_status not in (200, 204):
        raise SmokeFailure(f"CORS preflight returned HTTP {preflight_status} from {safe_origin(api_url)}")
    if allow_origin != app_origin:
        raise SmokeFailure("CORS preflight did not allow the THIP app origin")
    if "post" not in allow_methods or "authorization" not in allow_headers or "content-type" not in allow_headers:
        raise SmokeFailure("CORS preflight does not allow the required method or headers")
    if "origin" not in vary:
        raise SmokeFailure("CORS preflight did not include Vary: Origin")

    probe_body = json.dumps({"sql": "SELECT VERSION() AS version", "app": app_identifier}).encode("utf-8")
    probe_status, probe_headers, probe_payload = request_json(
        api_sql_url,
        "POST",
        {
            "Origin": app_origin,
            "Authorization": f"Bearer {bearer}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        probe_body,
    )
    if probe_status != 200 or not isinstance(probe_payload, dict):
        raise SmokeFailure(f"BMS /api/sql probe returned HTTP {probe_status}")
    message_code = probe_payload.get("MessageCode")
    if isinstance(message_code, int) and message_code >= 400:
        raise SmokeFailure("BMS /api/sql rejected the read-only probe")
    if probe_headers.get("access-control-allow-origin") != app_origin:
        raise SmokeFailure("BMS /api/sql response did not include the THIP app origin")
    if "origin" not in probe_headers.get("vary", "").lower():
        raise SmokeFailure("BMS /api/sql response did not include Vary: Origin")

    print(json.dumps({
        "status": "passed",
        "app_origin": app_origin,
        "api_origin": safe_origin(api_url),
        "app_identifier": app_identifier,
        "preflight_status": preflight_status,
        "probe_status": probe_status,
    }))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SmokeFailure as error:
        print(f"BMS connectivity smoke failed: {error}", file=sys.stderr)
        raise SystemExit(1)
