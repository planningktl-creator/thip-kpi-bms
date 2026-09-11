import json
import os
from pathlib import Path

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "tmp" / "browser"
ARTIFACTS.mkdir(parents=True, exist_ok=True)
BASE_URL = os.environ.get("THIP_SMOKE_BASE_URL", "http://127.0.0.1:5173").rstrip("/")


def allow_cors_headers(request) -> dict[str, str]:
    origin = request.headers.get("origin", "*")
    return {
        "Access-Control-Allow-Origin": origin,
        "Access-Control-Allow-Headers": "Authorization, Content-Type",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Vary": "Origin",
    }


def mock_bms_routes(page) -> None:
    def paste_json(route) -> None:
        route.fulfill(
            status=200,
            headers={**allow_cors_headers(route.request), "Content-Type": "application/json"},
            body=json.dumps({
                "result": {
                    "user_info": {
                        "name": "Smoke User",
                        "hospital_code": "10929",
                        "bms_url": "https://bms.smoke.test",
                        "bms_session_code": "smoke-session-token",
                        "bms_database_type": "postgresql",
                    }
                }
            }),
        )

    def bms_sql(route) -> None:
        request = route.request
        headers = allow_cors_headers(request)
        if request.method == "OPTIONS":
            route.fulfill(status=204, headers=headers)
            return
        if request.method != "POST":
            route.fallback()
            return

        body = json.loads(request.post_data or "{}")
        sql = str(body.get("sql", ""))
        if "SELECT VERSION()" in sql:
            payload = {"data": [{"version": "PostgreSQL 16.4"}]}
        else:
            payload = {
                "result": [
                    {"indicator_code": "DH0101", "period_start": "2025-10-01", "fiscal_year": 2026, "fiscal_month": 1, "numerator": 1, "denominator": 4, "value": 25},
                    {"indicator_code": "DN0101", "period_start": "2025-10-01", "fiscal_year": 2026, "fiscal_month": 1, "numerator": 2, "denominator": 8, "value": 25},
                    {"indicator_code": "DR0101", "period_start": "2025-10-01", "fiscal_year": 2026, "fiscal_month": 1, "numerator": 1, "denominator": 10, "value": 10},
                    {"indicator_code": "CE0101", "period_start": "2025-10-01", "fiscal_year": 2026, "fiscal_month": 1, "numerator": 12, "denominator": 20, "value": 60},
                    {"indicator_code": "CI0101", "period_start": "2025-10-01", "fiscal_year": 2026, "fiscal_month": 1, "numerator": 3, "denominator": 20, "value": 15},
                    {"indicator_code": "DH0102", "period_start": "2025-10-01", "fiscal_year": 2026, "fiscal_month": 1, "numerator": 18, "denominator": 20, "value": 90},
                    {"indicator_code": "DG0202", "period_start": "2025-10-01", "fiscal_year": 2026, "fiscal_month": 1, "numerator": 1, "denominator": 25, "value": 4},
                    {"indicator_code": "DR0403", "period_start": "2025-10-01", "fiscal_year": 2026, "fiscal_month": 1, "numerator": 3, "denominator": 40, "value": 7.5},
                    {"indicator_code": "DR0102", "period_start": "2025-10-01", "fiscal_year": 2026, "fiscal_month": 1, "numerator": 1, "denominator": 9, "value": 11.11},
                    {"indicator_code": "DN0107", "period_start": "2025-10-01", "fiscal_year": 2026, "fiscal_month": 1, "numerator": 2, "denominator": 7, "value": 28.57},
                    {"indicator_code": "DH0112", "period_start": "2025-10-01", "fiscal_year": 2026, "fiscal_month": 1, "numerator": 28, "denominator": 4, "value": 7},
                    {"indicator_code": "DN0109", "period_start": "2025-10-01", "fiscal_year": 2026, "fiscal_month": 1, "numerator": 48, "denominator": 8, "value": 6},
                    {"indicator_code": "DN0302", "period_start": "2025-10-01", "fiscal_year": 2026, "fiscal_month": 1, "numerator": 1, "denominator": 3, "value": 33.33},
                ]
            }
        route.fulfill(status=200, headers={**headers, "Content-Type": "application/json"}, body=json.dumps(payload))

    page.route("https://hosxp.net/phapi/PasteJSON**", paste_json)
    page.route("https://bms.smoke.test/**", bms_sql)


def main() -> None:
    console_errors: list[str] = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        desktop = browser.new_page(viewport={"width": 1440, "height": 1000}, device_scale_factor=1)
        desktop.on("console", lambda message: console_errors.append(message.text) if message.type == "error" else None)
        desktop.goto(BASE_URL, wait_until="networkidle")
        desktop.screenshot(path=str(ARTIFACTS / "dashboard-desktop.png"), full_page=True)
        assert desktop.get_by_role("link", name="ข้ามไปยังเนื้อหาหลัก").count() == 1
        assert desktop.get_by_label("ค้นหารหัสหรือชื่อตัวชี้วัด").count() == 1
        assert desktop.get_by_label("เลือกเดือนงบประมาณ").count() == 1
        assert desktop.get_by_label("เลือกปีงบประมาณ").count() == 1
        assert desktop.get_by_text("ภาพรวมคุณภาพ", exact=True).count() >= 1
        assert desktop.get_by_text("สัญญาณที่ควรดูในงวดนี้", exact=True).count() == 1
        assert desktop.locator(".indicator-table tbody tr").count() == 232

        desktop.locator(".indicator-table tbody tr").first.click()
        desktop.wait_for_load_state("networkidle")
        desktop.screenshot(path=str(ARTIFACTS / "detail-desktop.png"), full_page=True)
        assert desktop.get_by_text("ตัวตั้ง ตัวหาร และสถานะของทุกงวดรายงาน", exact=True).count() == 1
        assert desktop.locator(".monthly-table tbody tr").count() == 12
        assert desktop.get_by_text("AA0101", exact=True).count() >= 1
        assert desktop.get_by_text("ปีงบประมาณ 2569", exact=False).count() >= 1
        assert desktop.locator("[data-testid='monthly-bar-chart']").count() == 1
        assert desktop.get_by_text("ต.ค. 2568", exact=True).count() >= 1
        assert desktop.get_by_text("ก.ย. 2569", exact=True).count() >= 1
        desktop.get_by_role("tab", name="แนวโน้ม").click()
        assert desktop.locator("[data-testid='monthly-line-chart']").count() == 1
        desktop.get_by_role("tab", name="กราฟแท่ง").click()
        assert desktop.locator("[data-testid='monthly-bar-chart']").count() == 1

        overview = browser.new_page(viewport={"width": 1440, "height": 1000}, device_scale_factor=1)
        overview.goto(BASE_URL, wait_until="networkidle")
        overview.get_by_role("button", name="ดูทั้งหมด").click()
        overview.wait_for_selector(".catalog-page")

        annual = browser.new_page(viewport={"width": 1440, "height": 1000}, device_scale_factor=1)
        annual.goto(f"{BASE_URL}/?view=detail&indicator=AA0101", wait_until="networkidle")
        assert annual.get_by_text("ยังไม่มีข้อมูลจริง", exact=True).count() >= 1
        assert annual.get_by_text("a/b x 100,000", exact=True).count() == 1
        assert annual.get_by_text("ผลงานล่าสุด · ต.ค. 2568", exact=True).count() == 1

        catalog = browser.new_page(viewport={"width": 1440, "height": 1000}, device_scale_factor=1)
        catalog.goto(f"{BASE_URL}/?view=catalog", wait_until="networkidle")
        catalog.screenshot(path=str(ARTIFACTS / "catalog-desktop.png"), full_page=True)
        assert catalog.locator(".catalog-page").count() == 1
        assert catalog.locator(".catalog-table tbody tr").count() == 232
        pending_row = catalog.locator(".catalog-table tbody tr", has=catalog.locator(".catalog-state-pending")).first
        assert pending_row.count() == 1
        pending_row.focus()
        pending_row.press("Enter")
        catalog.wait_for_selector(".monthly-detail-panel")
        catalog.screenshot(path=str(ARTIFACTS / "catalog-pending-detail-desktop.png"), full_page=True)
        assert catalog.locator(".monthly-table tbody tr").count() == 12
        assert catalog.locator(".status-muted").count() >= 1
        assert catalog.locator(".chart-empty-state").count() == 1

        mobile = browser.new_page(viewport={"width": 390, "height": 844}, device_scale_factor=1)
        mobile.goto(BASE_URL, wait_until="networkidle")
        mobile.screenshot(path=str(ARTIFACTS / "dashboard-mobile.png"), full_page=True)
        mobile.locator(".mobile-menu-button").click()
        assert mobile.locator(".app-sidebar.is-open").count() == 1
        mobile.locator(".sidebar-close").click()
        assert mobile.locator(".app-sidebar.is-open").count() == 0

        live = browser.new_page(viewport={"width": 1440, "height": 1000}, device_scale_factor=1)
        live.on("console", lambda message: console_errors.append(message.text) if message.type == "error" else None)
        mock_bms_routes(live)
        live.goto(f"{BASE_URL}/?bms-session-id=smoke-session", wait_until="networkidle")
        live.get_by_text("BMS live data บางส่วน", exact=True).wait_for()
        assert live.get_by_text("Live data บางส่วน", exact=True).count() == 1
        assert live.get_by_text("อ่านข้อมูลจริง 13/232 ตัวชี้วัด", exact=False).count() == 1
        assert live.get_by_role("button", name="รีเฟรชข้อมูล").count() == 1
        assert live.get_by_text("ยังไม่กำหนดเป้าหมาย", exact=False).count() >= 1
        assert live.locator(".indicator-table tbody tr").count() == 232
        assert live.get_by_text("DH0101", exact=False).count() >= 1
        assert live.get_by_text("CE0101", exact=False).count() >= 1
        assert live.get_by_text("DH0102", exact=False).count() >= 1
        assert live.get_by_text("DG0202", exact=False).count() >= 1
        assert live.get_by_text("DR0403", exact=False).count() >= 1
        assert live.get_by_text("DR0102", exact=False).count() >= 1
        assert live.get_by_text("DN0107", exact=False).count() >= 1
        assert live.get_by_text("DH0112", exact=False).count() >= 1
        assert live.get_by_text("DN0109", exact=False).count() >= 1
        assert live.get_by_text("DN0302", exact=False).count() >= 1
        assert live.evaluate("window.localStorage.length") == 0
        assert live.evaluate("window.sessionStorage.length") == 0

        browser.close()

    if console_errors:
        raise AssertionError(f"Browser console errors: {console_errors}")


if __name__ == "__main__":
    main()
