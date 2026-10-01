"""Sequential loader browser verification. All BMS calls are synthetic and intercepted."""
import asyncio
import json
import os
import re
import time
from pathlib import Path
from playwright.async_api import async_playwright, expect

BASE = os.environ.get('THIP_STEP_SMOKE_URL', 'http://127.0.0.1:5183')
OUT = Path(__file__).resolve().parents[1] / 'tmp' / 'step-browser'
OUT.mkdir(parents=True, exist_ok=True)

async def fixtures(context, scenario='normal'):
    calls = []
    async def paste(route):
        await route.fulfill(json={'result': {'user_info': {'hospital_code': '10929', 'bms_url': 'https://step.mock.invalid/', 'bms_session_code': 'SYNTHETIC_STEP_TOKEN', 'bms_database_type': 'PostgreSQL'}}}, headers={'Access-Control-Allow-Origin': '*'})
    async def api(route):
        headers = {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'Authorization, Content-Type', 'Access-Control-Allow-Methods': 'POST, OPTIONS'}
        if route.request.method == 'OPTIONS':
            await route.fulfill(status=204, headers=headers)
            return
        payload = route.request.post_data_json
        sql = payload['sql']
        assert not re.search(r'\b(INSERT|DELETE|UPDATE|CREATE|DROP)\b', sql, re.I)
        if 'SELECT VERSION()' in sql:
            await route.fulfill(json={'result': [{'version': 'PostgreSQL 16 SYNTHETIC'}]}, headers=headers)
            return
        codes = re.findall(r"'([A-Z]{2}\d{4}(?:\.\d)?)' AS indicator_code", sql)
        assert len(codes) == 1
        code = codes[0]
        start = payload['params']['start_date']['value']
        end = payload['params']['end_date']['value']
        assert end == f'{int(start[:4]) + 1}-10-01'
        call = {'code': code, 'start': start, 'at': time.monotonic(), 'end': None}
        calls.append(call)
        try:
            await asyncio.sleep(2 if scenario == 'stale' and start == '2025-10-01' else .25)
            if scenario == 'auth':
                await route.fulfill(status=501, json={'MessageCode': 401, 'Message': 'SYNTHETIC_SECRET_ERROR'}, headers=headers)
            elif scenario == 'rate':
                await route.fulfill(status=429, json={}, headers={**headers, 'Retry-After': '2'})
            elif code == 'AA0101' and sum(c['code'] == code for c in calls) == 1:
                await route.fulfill(status=404, json={}, headers=headers)
            else:
                numerator, denominator, value = (1, 10, 10) if code != 'DH0112' else (20, 4, 5)
                if code.startswith('AA'): value = 10000
                if scenario == 'stale': numerator, denominator, value = (9, 10, 90) if start == '2025-10-01' else (2, 10, 20)
                await route.fulfill(json={'result': [{'indicator_code': code, 'fiscal_year': int(end[:4]), 'fiscal_month': 1, 'period_start': start, 'numerator': numerator, 'denominator': denominator, 'value': value, 'fact_present': True}]}, headers=headers)
        except Exception:
            if not context.pages or all(page.is_closed() for page in context.pages): return
            # A cancelled request may have already been removed from the browser.
            if scenario != 'stale': raise
        finally:
            call['end'] = time.monotonic()
    await context.route('https://hosxp.net/phapi/PasteJSON**', paste)
    await context.route('https://step.mock.invalid/**', api)
    await context.route('https://fonts.googleapis.com/**', lambda route: route.abort())
    return calls

async def main():
    errors, logs, checks = [], [], []
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(viewport={'width': 1440, 'height': 1000})
        calls = await fixtures(context)
        page = await context.new_page()
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.on('console', lambda message: logs.append(message.text))
        await page.goto(f'{BASE}/?view=validation&fy=2026&bms-session-id=SYNTHETIC_LAUNCH', wait_until='networkidle')
        await expect(page.locator('.step-table > tbody > tr')).to_have_count(232)
        await expect(page.locator('[data-code="DH0101"]')).to_contain_text('query สำเร็จ')
        assert len(calls) == 1 and 'bms-session-id' not in page.url
        await page.get_by_role('button', name='พัก', exact=True).click()
        await expect(page.get_by_role('button', name='ต่อ', exact=True)).to_be_enabled()
        count = len(calls); await asyncio.sleep(1.2); assert len(calls) == count
        await page.locator('[data-code="DH0101"] summary').click()
        await expect(page.locator('[data-code="DH0101"] details table')).to_contain_text('2025-10-01')
        await expect(page.locator('.step-disclaimer')).to_contain_text('สูตรยังไม่รับรอง')
        await page.screenshot(path=str(OUT / 'desktop-details.png'))
        await page.evaluate('scrollTo(0, 0)')
        await page.screenshot(path=str(OUT / 'desktop.png'))
        await page.get_by_role('button', name='ต่อ', exact=True).click()
        await expect(page.locator('[data-code="DH0112"]')).to_contain_text('query สำเร็จ')
        await expect(page.locator('[data-code="AA0101"]')).to_contain_text('ล้มเหลว', timeout=10000)
        await page.get_by_role('button', name='พัก', exact=True).click()
        await expect(page.get_by_role('button', name='ต่อ', exact=True)).to_be_enabled()
        await page.get_by_role('button', name='ลองใหม่ AA0101', exact=True).click()
        await expect(page.locator('[data-code="AA0101"]')).to_contain_text('query สำเร็จ')
        await page.get_by_role('button', name='ยกเลิก', exact=True).click()
        assert sum(c['code'] == 'DH0101' for c in calls) == 1
        assert sum(c['code'] == 'DH0112' for c in calls) == 1
        for before, after in zip(calls, calls[1:]): assert after['at'] - before['end'] >= .95
        count = len(calls); await asyncio.sleep(1.2); assert len(calls) == count
        await page.get_by_label('ค้นหารหัสหรือชื่อ KPI').fill('DH0101')
        await expect(page.locator('.step-table > tbody > tr')).to_have_count(3)
        await page.get_by_label('ค้นหารหัสหรือชื่อ KPI').fill('')
        await page.get_by_label('เลือกปีงบประมาณ').select_option('2027')
        await expect(page.locator('[data-code="DH0101"]')).to_contain_text('query สำเร็จ')
        await page.get_by_role('button', name='พัก', exact=True).click()
        await page.locator('[data-code="DH0101"] summary').click()
        await expect(page.locator('[data-code="DH0101"] details table')).not_to_contain_text('2025-10-01')
        assert await page.evaluate("!JSON.stringify({...localStorage,...sessionStorage}).includes('SYNTHETIC_')")
        await page.reload(wait_until='networkidle')
        await expect(page.locator('.step-page')).to_contain_text('รอเชื่อมต่อ')
        await page.get_by_label('BMS Session ID').fill('SYNTHETIC_MANUAL')
        await page.get_by_role('button', name='เชื่อมต่อ', exact=True).click()
        await expect(page.locator('[data-code="DH0101"]')).to_contain_text('query สำเร็จ')
        assert await page.get_by_label('BMS Session ID').input_value() == ''
        await page.get_by_role('button', name='ยกเลิก', exact=True).click()
        checks += ['232 rows', 'first result before completion', '1 second gap / sequential', 'pause/resume/cancel', 'retry failed only', 'search', 'FY reset', 'manual session / refresh memory only']
        await context.close()

        mobile = await browser.new_context(viewport={'width': 390, 'height': 844})
        await fixtures(mobile)
        page = await mobile.new_page()
        await page.goto(f'{BASE}/?view=validation&fy=2026&bms-session-id=SYNTHETIC_MOBILE', wait_until='networkidle')
        await expect(page.locator('[data-code="DH0101"]')).to_contain_text('query สำเร็จ')
        await page.get_by_role('button', name='พัก', exact=True).click()
        assert await page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        await page.locator('[data-code="DH0101"] summary').focus()
        await page.keyboard.press('Enter')
        await expect(page.locator('[data-code="DH0101"] details')).to_have_attribute('open', '')
        await page.screenshot(path=str(OUT / 'mobile-details.png'))
        await page.evaluate('scrollTo(0, 0)')
        await page.screenshot(path=str(OUT / 'mobile.png'))
        checks += ['mobile no page overflow', 'keyboard details']
        await mobile.close()

        for scenario in ['auth', 'rate', 'stale']:
            ctx = await browser.new_context(viewport={'width': 1100, 'height': 900})
            scenario_calls = await fixtures(ctx, scenario)
            page = await ctx.new_page()
            page.on('pageerror', lambda error: errors.append(str(error)))
            await page.goto(f'{BASE}/?view=validation&fy=2026&bms-session-id=SYNTHETIC_CASE', wait_until='domcontentloaded')
            if scenario == 'stale':
                while not scenario_calls: await asyncio.sleep(.02)
                await page.get_by_label('เลือกปีงบประมาณ').select_option('2027')
                await expect(page.locator('[data-code="DH0101"]')).to_contain_text('query สำเร็จ')
                await page.get_by_role('button', name='พัก', exact=True).click()
                await asyncio.sleep(2)
                await page.locator('[data-code="DH0101"] summary').click()
                await expect(page.locator('[data-code="DH0101"] details')).to_contain_text('2026-10-01')
                await expect(page.locator('[data-code="DH0101"] details')).not_to_contain_text('2025-10-01')
            else:
                await expect(page.locator('[data-code="DH0101"]')).to_contain_text('ล้มเหลว')
                await expect(page.get_by_role('button', name='ต่อ', exact=True)).to_be_disabled()
                await asyncio.sleep(2.2)
                assert len(scenario_calls) == 1
                if scenario == 'rate': await expect(page.get_by_role('button', name='ต่อ', exact=True)).to_be_enabled()
                assert 'SYNTHETIC_SECRET_ERROR' not in await page.locator('.step-page').inner_text()
            checks.append(scenario)
            await ctx.close()
        assert not errors, errors
        assert not any('SYNTHETIC_STEP_TOKEN' in item or 'SYNTHETIC_SECRET_ERROR' in item for item in logs)
        await browser.close()
    result = {'passed': checks, 'pageErrors': errors, 'realBmsCalls': 0}
    (OUT / 'result.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(result, ensure_ascii=False))

if __name__ == '__main__': asyncio.run(main())
