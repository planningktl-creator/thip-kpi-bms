"""Cumulative/SPC UI regression using synthetic registered-query aggregates only."""
import asyncio
import csv
import io
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path
from playwright.async_api import async_playwright, expect
from step_browser_smoke import fixtures

BASE = os.environ.get('THIP_SMOKE_BASE_URL', 'http://127.0.0.1:5173')
OUT = Path(__file__).resolve().parents[1] / 'tmp' / 'kpi-analysis'
OUT.mkdir(parents=True, exist_ok=True)


async def main():
    checks, errors = [], []
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        for width in [1440, 800, 390, 320]:
            context = await browser.new_context(viewport={'width': width, 'height': 1000})
            await context.route('https://**', lambda route: route.abort())
            calls = await fixtures(context)
            own_calls = []

            async def aggregates(route):
                if route.request.method == 'OPTIONS':
                    await route.fallback()
                    return
                payload = route.request.post_data_json
                if not re.search(r"'DH0101' AS indicator_code", payload['sql']):
                    await route.fallback()
                    return
                year = int(payload['params']['end_date']['value'][:4])
                own_calls.append(year)
                rows = []
                for month in range(1, 13):
                    numerator, denominator = (10, 100) if month == 1 else (10, 20) if month == 2 else (40, 100) if month == 9 else (5, 200) if month == 10 else (5, 100)
                    missing = month == 11
                    rows.append({
                        'indicator_code': 'DH0101', 'fiscal_year': year, 'fiscal_month': month,
                        'period_start': f'{year - 1 if month <= 3 else year}-{month + 9 if month <= 3 else month - 3:02d}-01',
                        'numerator': None if missing else numerator,
                        'denominator': None if missing else denominator,
                        'value': None if missing else numerator / denominator * 100,
                        'fact_present': not missing,
                    })
                await route.fulfill(json={'result': rows}, headers={'Access-Control-Allow-Origin': '*'})

            await context.route('https://step.mock.invalid/**', aggregates)
            page = await context.new_page()
            page.on('pageerror', lambda error: errors.append(str(error)))
            await page.clock.set_fixed_time(datetime(2026, 10, 1, tzinfo=timezone.utc))
            await page.goto(BASE + '/?fy=2026&bms-session-id=SYNTHETIC_ANALYSIS', wait_until='domcontentloaded')
            cell = page.locator('#monitoring-DH0101-2')
            await expect(cell.locator('strong')).to_have_text('50')
            await page.get_by_role('button', name='พัก', exact=True).click()
            await expect(page.get_by_role('button', name='ต่อ', exact=True)).to_be_enabled()
            count = len(calls)
            await page.get_by_label('ค้นหารหัสหรือชื่อ KPI').fill('DH0101')
            await page.get_by_role('button', name='สะสมตั้งแต่ ต.ค.', exact=True).click()
            await expect(cell.locator('strong')).to_have_text('16.67')
            await expect(cell).to_contain_text('สะสมสอบทาน')
            await expect(page.locator('#monitoring-DH0101-12')).to_contain_text('สะสมไม่ได้')
            assert await page.locator('.monitoring-scroll').evaluate('(e)=>e.scrollWidth<=e.clientWidth && e.scrollHeight<=e.clientHeight')
            await page.locator('.monitoring-matrix').scroll_into_view_if_needed()
            if width in [1440, 390]:
                await page.screenshot(path=str(OUT / f'cumulative-{width}.png'))
            await cell.focus()
            await page.keyboard.press('ArrowRight')
            await expect(page.locator('#monitoring-DH0101-3')).to_be_focused()
            await cell.click()
            await expect(page.locator('dialog[open]')).to_contain_text('16.6667')
            await expect(page.locator('dialog[open]')).to_contain_text('ยังไม่ยืนยันความครบช่วง')
            await page.get_by_role('button', name='ดูทุกงวดของ DH0101', exact=True).click()
            await expect(page.get_by_role('button', name='สะสมตั้งแต่ ต.ค.', exact=True)).to_have_attribute('aria-pressed', 'true')
            await expect(page.locator('.kpi-detail-periods [data-month="2"]')).to_contain_text('16.67')
            await expect(page.locator('.kpi-trend circle[data-month="2"] title')).to_contain_text('16.67')
            await page.get_by_role('button', name='Control chart', exact=True).click()
            await expect(page.locator('.kpi-control-chart')).to_contain_text('p-chart')
            await expect(page.locator('.kpi-control-chart circle[data-month="2"] title')).to_contain_text('50 %')
            assert await page.locator('.kpi-control-chart circle[data-month="11"]').count() == 0
            assert (await page.locator('.kpi-control-chart .kpi-chart-value').get_attribute('d')).count('M') == 2
            assert await page.locator('.kpi-chart-limit').count() == 2
            assert await page.locator('circle[data-signal="beyond-limits"]').count() > 0
            await page.locator('.kpi-control-chart').scroll_into_view_if_needed()
            if width in [1440, 800, 390]:
                await page.screenshot(path=str(OUT / f'control-{width}.png'))
            await page.get_by_text('ค่าที่ใช้ใน Control chart', exact=True).click()
            assert await page.locator('.kpi-chart-facts tbody tr').count() == 12
            assert await page.evaluate('document.documentElement.scrollWidth<=innerWidth')
            await page.get_by_role('button', name='รายเดือน / งวด', exact=True).click()
            await expect(page.locator('.kpi-detail-table').last.locator('[data-month="2"]')).to_contain_text('50')
            await page.get_by_role('button', name='สะสมตั้งแต่ ต.ค.', exact=True).click()
            async with page.expect_download() as download:
                await page.get_by_role('button', name='CSV สอบทาน', exact=True).click()
            artifact = await download.value
            data = list(csv.DictReader(io.StringIO(Path(await artifact.path()).read_text(encoding='utf-8-sig'))))
            assert len(data) == 12 and float(data[1]['value']) == 50
            assert abs(float(data[1]['ytd_value']) - 16.6666667) < .00001
            assert data[1]['ytd_basis'] == 'period-facts' and data[1]['ytd_complete'] == 'false'
            assert data[11]['ytd_value'] == ''
            assert len(calls) == count and own_calls == [2026], 'Analysis triggered another query'
            assert 'SYNTHETIC_ANALYSIS' not in page.url
            await page.reload(wait_until='domcontentloaded')
            await expect(page.get_by_role('button', name='สะสมตั้งแต่ ต.ค.', exact=True)).to_have_attribute('aria-pressed', 'true')
            await page.go_back(wait_until='domcontentloaded')
            await expect(page.get_by_role('button', name='รายเดือน / งวด', exact=True)).to_have_attribute('aria-pressed', 'true')
            checks.append(f'{width}px: weighted YTD, gap, keyboard, details, monthly SPC, limits/signals, CSV, URL/history, no extra queries/overflow')
            print(checks[-1], flush=True)
            await context.close()
        await browser.close()
    assert not errors, errors
    (OUT / 'result.json').write_text(json.dumps({'passed': checks, 'pageErrors': errors, 'realBmsCalls': 0}, ensure_ascii=False, indent=2), encoding='utf-8')


if __name__ == '__main__':
    asyncio.run(main())
