"""Production chunk failure/retry regression; only localhost and mocked BMS."""
import asyncio
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.request
from playwright.async_api import async_playwright, expect
from step_browser_smoke import fixtures

ROOT = Path(__file__).resolve().parents[1]
BASE = 'http://127.0.0.1:5186'

async def check():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        ctx = await browser.new_context(viewport={'width':1440,'height':1000})
        await ctx.route('https://**', lambda route: route.abort())
        calls = await fixtures(ctx)
        page = await ctx.new_page()
        navigations = []
        page.on('request', lambda request: navigations.append(True) if request.resource_type == 'document' else None)
        await page.goto(BASE+'/?view=monitoring&fy=2026',wait_until='networkidle')
        initial = len(navigations)
        attempts = 0
        async def fail_once(route):
            nonlocal attempts
            attempts += 1
            if attempts == 1: await route.abort()
            else: await route.continue_()
        await ctx.route('**/assets/StepValidationPage-*.js',fail_once)
        await page.locator('.sidebar-nav-item').filter(has_text='ตรวจข้อมูลทีละ KPI').click()
        await expect(page.get_by_role('alert').filter(has_text='โหลดหน้าจอไม่สำเร็จ')).to_be_visible()
        await page.wait_for_timeout(500)
        assert attempts == 1 and len(navigations) == initial, {'attempts':attempts,'documents':len(navigations),'initial':initial}
        await page.get_by_label('BMS Session ID').fill('SYNTHETIC_CHUNK_RECOVERY')
        await page.get_by_role('button',name='ลองโหลดหน้าจออีกครั้ง',exact=True).click()
        await expect(page.locator('.step-page')).to_be_visible()
        await expect(page.get_by_label('BMS Session ID')).to_have_value('SYNTHETIC_CHUNK_RECOVERY')
        assert len(navigations) == initial and not calls
        await page.get_by_role('button',name='เชื่อมต่อ',exact=True).click()
        await expect(page.locator('[data-code="DH0101"]')).to_contain_text('query สำเร็จ')
        await page.get_by_role('button',name='พัก',exact=True).click()
        await expect(page.get_by_role('button',name='ต่อ',exact=True)).to_be_enabled()
        result = {'chunkFailureVisible':True,'explicitRetry':True,'reloads':0,'sessionInputPreserved':True,'hospitalQueries':0}
        out=ROOT/'tmp/performance';out.mkdir(parents=True,exist_ok=True)
        (out/'chunk-result.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
        print(json.dumps(result))
        await browser.close()

def main():
    proc=subprocess.Popen(['node','scripts/performance-server.mjs'],cwd=ROOT,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,creationflags=0x08000000 if os.name=='nt' else 0)
    try:
        for _ in range(100):
            if proc.poll() is not None:raise RuntimeError('Local production server failed')
            try:urllib.request.urlopen(BASE,timeout=.2).close();break
            except OSError:time.sleep(.1)
        asyncio.run(check())
    finally:proc.terminate();proc.wait(timeout=10)

if __name__=='__main__':main()
