from pathlib import Path

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "tmp" / "browser"
ARTIFACTS.mkdir(parents=True, exist_ok=True)


def main() -> None:
    console_errors: list[str] = []
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(headless=True)
        desktop = browser.new_page(viewport={"width": 1440, "height": 1000}, device_scale_factor=1)
        desktop.on("console", lambda message: console_errors.append(message.text) if message.type == "error" else None)
        desktop.goto("http://127.0.0.1:5173", wait_until="networkidle")
        desktop.screenshot(path=str(ARTIFACTS / "dashboard-desktop.png"), full_page=True)
        assert desktop.get_by_text("ภาพรวมคุณภาพ", exact=True).count() >= 1
        assert desktop.get_by_text("สัญญาณที่ควรดูเดือนนี้", exact=True).count() == 1
        assert desktop.locator(".indicator-table tbody tr").count() == 12

        desktop.locator(".indicator-table tbody tr").first.click()
        desktop.wait_for_load_state("networkidle")
        desktop.screenshot(path=str(ARTIFACTS / "detail-desktop.png"), full_page=True)
        assert desktop.get_by_text("ตัวตั้ง ตัวหาร และสถานะของทุกเดือน", exact=True).count() == 1
        assert desktop.locator(".monthly-table tbody tr").count() == 12
        assert desktop.get_by_text("DH0101", exact=True).count() >= 1

        catalog = browser.new_page(viewport={"width": 1440, "height": 1000}, device_scale_factor=1)
        catalog.goto("http://127.0.0.1:5173/?view=catalog", wait_until="networkidle")
        catalog.screenshot(path=str(ARTIFACTS / "catalog-desktop.png"), full_page=True)
        assert catalog.locator(".catalog-page").count() == 1
        assert catalog.locator(".catalog-table tbody tr").count() == 232
        pending_row = catalog.locator(".catalog-table tbody tr", has=catalog.locator(".catalog-state-pending")).first
        assert pending_row.count() == 1
        pending_row.click()
        catalog.wait_for_selector(".monthly-detail-panel")
        assert catalog.locator(".monthly-table tbody tr").count() == 12
        assert catalog.locator(".status-muted").count() >= 1

        mobile = browser.new_page(viewport={"width": 390, "height": 844}, device_scale_factor=1)
        mobile.goto("http://127.0.0.1:5173", wait_until="networkidle")
        mobile.screenshot(path=str(ARTIFACTS / "dashboard-mobile.png"), full_page=True)
        mobile.locator(".mobile-menu-button").click()
        assert mobile.locator(".app-sidebar.is-open").count() == 1
        mobile.locator(".sidebar-close").click()
        assert mobile.locator(".app-sidebar.is-open").count() == 0

        browser.close()

    if console_errors:
        raise AssertionError(f"Browser console errors: {console_errors}")


if __name__ == "__main__":
    main()
