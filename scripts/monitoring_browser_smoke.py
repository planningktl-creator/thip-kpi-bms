"""Local-only browser regression. All BMS/session responses are mocked."""
import csv
import io
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from playwright.sync_api import sync_playwright, expect
from visual_smoke import mock_bms_routes, allow_cors_headers

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'tmp' / 'monitoring-release'
OUT.mkdir(parents=True, exist_ok=True)
NORMAL = os.environ.get('THIP_SMOKE_BASE_URL', 'http://127.0.0.1:5173')
PREVIEW = os.environ.get('THIP_PREVIEW_BASE_URL', 'http://127.0.0.1:5174')
SOURCE = os.environ.get('THIP_SOURCE_BASE_URL', 'http://127.0.0.1:5175')

def main():
    errors = []
    checks = []
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={'width': 1440, 'height': 1000}, timezone_id='America/New_York')
        page.clock.set_fixed_time(datetime(2026, 10, 1, 0, 0, tzinfo=timezone.utc))
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.goto(f'{PREVIEW}/?fy=2026', wait_until='networkidle')
        expect(page.locator('.monitoring-matrix tbody tr:not([hidden])')).to_have_count(232)
        expect(page.locator('.monitoring-matrix tbody tr:not([hidden]) .monitoring-cell')).to_have_count(2784)
        expect(page.locator('.monitoring-preview').first).to_contain_text('ข้อมูลสังเคราะห์')
        page.get_by_label('กรองสถานะข้อมูล').select_option('measured')
        expect(page.locator('.monitoring-matrix tbody tr:not([hidden])')).to_have_count(7)
        page.screenshot(path=str(OUT / 'preview-measured-desktop.png'), full_page=True)
        page.get_by_label('กรองผลเทียบเป้า').select_option('watch')
        assert page.locator('.monitoring-matrix tbody tr:not([hidden])').count() > 0
        for row in page.locator('.monitoring-matrix tbody tr:not([hidden])').all():
            assert row.locator('.assessment-watch').count() > 0
            assert row.locator('.monitoring-cell').count() == 12
        page.get_by_label('กรองผลเทียบเป้า').select_option('all')
        checks += ['assessment filter preserves all twelve months']
        page.get_by_label('ค้นหารหัสหรือชื่อ KPI').fill('DH0101')
        expect(page.locator('.monitoring-matrix tbody tr:not([hidden])')).to_have_count(1)
        cell = page.locator('.monitoring-matrix tbody tr:not([hidden]) .monitoring-cell').first
        cell.focus(); cell.press('ArrowRight')
        expect(page.locator('.monitoring-matrix tbody tr:not([hidden]) .monitoring-cell').nth(1)).to_be_focused()
        page.keyboard.press('Enter')
        expect(page.locator('dialog')).to_be_visible()
        expect(page.locator('dialog')).to_contain_text('synthetic-preview-1')
        expect(page.locator('dialog')).to_contain_text('ไม่มีเป้าหมาย')
        expect(page.locator('dialog')).to_contain_text('1 พ.ย. พ.ศ. 2568 ถึง 1 ธ.ค. พ.ศ. 2568')
        expect(page.locator('dialog .monitoring-facts')).not_to_contain_text('2025-11-01')
        expect(page.locator('dialog')).to_contain_text('1 ต.ค. พ.ศ. 2569 07:00:00')
        page.screenshot(path=str(OUT / 'preview-detail-desktop.png'), full_page=True)
        page.keyboard.press('Escape')
        expect(page.locator('dialog')).not_to_be_visible()
        expect(page.locator('.monitoring-matrix tbody tr:not([hidden]) .monitoring-cell').nth(1)).to_be_focused()
        page.keyboard.press('ArrowLeft'); page.keyboard.press('Enter')
        expect(page.locator('dialog')).to_contain_text('1 ต.ค. พ.ศ. 2568 ถึง 1 พ.ย. พ.ศ. 2568')
        expect(page.locator('dialog')).to_contain_text('31 ต.ค. พ.ศ. 2568')
        assert '2025-10-01' not in page.locator('dialog').inner_text()
        page.keyboard.press('Escape')
        with page.expect_download() as download_info:
            page.get_by_role('button', name='ส่งออก CSV', exact=True).click()
        download = download_info.value
        assert download.suggested_filename == 'thip-monthly-monitoring-2569-synthetic-preview.csv'
        content = Path(download.path()).read_text(encoding='utf-8-sig')
        rows = list(csv.DictReader(io.StringIO(content)))
        assert len(rows) == 12 and rows[5]['data_status'] == 'missing-source'
        assert rows[0]['period_start'] == '2025-10-01'
        assert rows[0]['period_start_be'] == '1 ต.ค. พ.ศ. 2568'
        assert all(row['series'] == 'monthly-monitoring' and 'ข้อมูลสังเคราะห์' in row['data_label'] for row in rows)
        checks += ['232×12', 'preview label', 'any-month filter', 'keyboard + focus restore', 'CSV all twelve cells']
        url = page.url
        page.reload(wait_until='networkidle')
        assert page.url == url
        expect(page.get_by_label('ค้นหารหัสหรือชื่อ KPI')).to_have_value('DH0101')
        expect(page.get_by_label('กรองสถานะข้อมูล')).to_have_value('measured')
        page.get_by_label('กรองกลุ่ม KPI').select_option('S')
        expect(page.locator('.monitoring-matrix tbody tr:not([hidden])')).to_have_count(0)
        page.go_back(wait_until='networkidle')
        expect(page.get_by_label('กรองกลุ่ม KPI')).to_have_value('all')
        expect(page.locator('.monitoring-matrix tbody tr:not([hidden])')).to_have_count(1)
        page.go_forward(wait_until='networkidle')
        expect(page.get_by_label('กรองกลุ่ม KPI')).to_have_value('S')
        page.get_by_role('button',name='ล้างตัวกรอง').click()
        expect(page.locator('.monitoring-matrix tbody tr:not([hidden])')).to_have_count(232)
        page.get_by_label('เลือกปีงบประมาณ').select_option('2027')
        expect(page.locator('.state-future')).to_have_count(2552)
        page.get_by_label('เลือกปีงบประมาณ').select_option('2026')
        checks += ['Bangkok current fiscal year future months']
        checks += ['URL refresh/back/forward', 'empty and reset']
        mobile = browser.new_page(viewport={'width':390,'height':844})
        mobile.goto(f'{PREVIEW}/?fy=2026&data=measured',wait_until='networkidle')
        assert mobile.evaluate('document.documentElement.scrollWidth') == 390
        assert mobile.locator('aside').evaluate('(element)=>element.inert')
        mobile.get_by_role('button',name='เปิดเมนู').click()
        mobile.keyboard.press('Escape')
        expect(mobile.get_by_role('button',name='เปิดเมนู')).to_be_focused()
        expect(mobile.locator('aside')).not_to_have_class('app-sidebar is-open')
        scroll = mobile.locator('.monitoring-scroll')
        assert scroll.evaluate('(element)=>element.scrollWidth<=element.clientWidth && element.scrollHeight<=element.clientHeight')
        assert mobile.locator('.monitoring-matrix tbody tr:not([hidden])').first.locator('td[data-month-label]').count() == 12
        mobile.screenshot(path=str(OUT/'preview-measured-mobile.png'),full_page=True)
        mobile.locator('.monitoring-matrix tbody tr:not([hidden]) .monitoring-cell').first.click()
        expect(mobile.locator('dialog')).to_be_visible()
        mobile.screenshot(path=str(OUT/'preview-detail-mobile.png'),full_page=True)
        mobile.keyboard.press('Escape')
        checks += ['mobile months reflow without inner scrolling', 'mobile drawer inert + Escape', 'mobile details']
        tablet = browser.new_page(viewport={'width':800,'height':1000})
        tablet.goto(f'{PREVIEW}/?fy=2026',wait_until='networkidle')
        expect(tablet.locator('aside')).to_be_visible()
        assert not tablet.locator('aside').evaluate('(element)=>element.inert')
        expect(tablet.get_by_role('button',name='เปิดเมนู')).not_to_be_visible()
        expect(tablet.locator('.sidebar-nav-item').filter(has_text='ภาพรวมคุณภาพ')).to_be_enabled()
        tablet.screenshot(path=str(OUT/'preview-tablet.png'),full_page=True)
        checks += ['tablet visible sidebar remains interactive at 800px']
        unavailable = browser.new_page()
        unavailable.goto(f'{NORMAL}/?fy=2026&series=monthly-monitoring&mode=approved',wait_until='networkidle')
        expect(unavailable.locator('.monitoring-matrix tbody tr:not([hidden]) .monitoring-cell')).to_have_count(2784)
        unavailable.locator('.monitoring-cell').first.click()
        expect(unavailable.locator('dialog')).to_contain_text('population denominator')
        unavailable.keyboard.press('Escape')
        checks += ['no source preserves NULL and reasons']
        # Slow/partial configured source and cross-route cache are exercised by
        # shared_kpi_browser_smoke.py through the central queue.
        rejected = browser.new_page()
        rejected.route('https://**', lambda route: route.abort())
        rejected.route('https://hosxp.net/phapi/PasteJSON**', lambda route: route.fulfill(status=401, json={}))
        rejected.goto(f'{SOURCE}/?fy=2026&bms-session-id=synthetic-expired-session', wait_until='networkidle')
        expect(rejected.locator('.connection-banner-error')).to_be_visible()
        expect(rejected.locator('.monitoring-cell')).to_have_count(2784)
        assert 'synthetic-expired-session' not in rejected.url
        checks += ['expired session retains grid and strips launch capability']
        browser.close()
    assert not errors, errors
    (OUT/'browser-checks.json').write_text(json.dumps({'passed':checks,'pageErrors':errors},ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'Monitoring browser smoke passed: {len(checks)} checks')

if __name__=='__main__': main()
