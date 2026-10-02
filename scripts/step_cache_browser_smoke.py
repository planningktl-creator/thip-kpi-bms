"""Real browser IndexedDB/persistent-profile tests; every BMS endpoint is mocked."""
import asyncio
import json
import tempfile
from pathlib import Path
from playwright.async_api import async_playwright, expect
from step_browser_smoke import BASE, OUT, fixtures

READ = """async () => {
 const db = await new Promise((resolve,reject) => { const r=indexedDB.open('thip-candidate-cache',2); r.onsuccess=()=>resolve(r.result); r.onerror=reject; });
 const rows = await new Promise((resolve,reject) => { const r=db.transaction('entries').objectStore('entries').getAll(); r.onsuccess=()=>resolve(r.result); r.onerror=reject; });
 db.close(); return rows;
}"""

async def pause(page):
    button = page.get_by_role('button', name='พัก', exact=True)
    if await button.is_enabled(): await button.click()
    await expect(page.get_by_role('button', name='ต่อ', exact=True)).to_be_enabled()

async def main():
    checks, errors = [], []
    # Chromium locks profile files; keep them outside Vite's workspace watcher.
    profile = tempfile.mkdtemp(prefix='thip-cache-profile-')
    async with async_playwright() as p:
        ctx = await p.chromium.launch_persistent_context(profile, headless=True, viewport={'width':1440,'height':1000})
        calls = await fixtures(ctx)
        page = ctx.pages[0]
        page.on('pageerror', lambda error: errors.append(str(error)))
        launch = f'{BASE}/?view=validation&fy=2026&bms-session-id=SYNTHETIC_CACHE_SESSION'
        await page.goto(launch, wait_until='networkidle')
        await expect(page.locator('[data-code="DH0101"]')).to_contain_text('query สำเร็จ')
        await pause(page)
        stored = await page.evaluate(READ)
        assert len(stored) >= 1 and stored[0]['version'] == 2
        assert stored[0]['expiresAt'] - __import__('datetime').datetime.fromisoformat(stored[0]['observedAt'].replace('Z','+00:00')).timestamp()*1000 == 86400000
        assert not any(word in json.dumps(stored) for word in ['SYNTHETIC_', 'bearerToken', 'marketplaceToken', 'step.mock.invalid', 'patient', 'hn', 'vn'])
        count = sum(c['code']=='DH0101' for c in calls)
        await page.reload(wait_until='networkidle')
        await expect(page.locator('.kpi-session-panel')).to_contain_text('รอเชื่อมต่อ')
        await expect(page.locator('[data-code="DH0101"]')).not_to_contain_text('จาก cache')
        await page.get_by_label('BMS Session ID').fill('SYNTHETIC_CACHE_SESSION')
        await page.get_by_role('button', name='เชื่อมต่อ', exact=True).click()
        await expect(page.locator('[data-code="DH0101"]')).to_contain_text('จาก cache')
        await pause(page)
        assert sum(c['code']=='DH0101' for c in calls) == count
        await expect(page.locator('.step-counts')).to_contain_text('จาก cache')
        await page.screenshot(path=str(OUT/'cache-desktop.png'))
        checks += ['validated aggregates persisted without credentials', '24-hour TTL', 'session required before cache display', 'refresh skips cached query']
        await ctx.close()

        ctx = await p.chromium.launch_persistent_context(profile, headless=True, viewport={'width':390,'height':844})
        calls = await fixtures(ctx)
        page = ctx.pages[0]
        page.on('pageerror', lambda error: errors.append(str(error)))
        await page.goto(launch, wait_until='networkidle')
        await expect(page.locator('[data-code="DH0101"]')).to_contain_text('จาก cache')
        await pause(page)
        assert not any(c['code']=='DH0101' for c in calls)
        assert await page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        await page.screenshot(path=str(OUT/'cache-mobile.png'))
        checks += ['browser close/reopen retains cache', 'mobile cache controls without overflow']
        await page.locator('.kpi-cache-menu').evaluate('(element)=>element.open=true')
        await page.get_by_role('button', name='โหลดใหม่ทั้งคิว', exact=True).click()
        await expect(page.locator('[data-code="DH0101"]')).not_to_contain_text('จาก cache')
        await expect(page.locator('[data-code="DH0101"]')).to_contain_text('query สำเร็จ')
        await pause(page)
        assert sum(c['code']=='DH0101' for c in calls)==1, {'calls':calls, 'row':await page.locator('[data-code="DH0101"]').inner_text()}
        await expect(page.locator('[data-code="DH0101"]')).not_to_contain_text('จาก cache')
        checks.append('force reload bypasses cache')

        await page.goto(launch.replace('SYNTHETIC_CACHE_SESSION','SYNTHETIC_OTHER_SESSION'), wait_until='networkidle')
        await expect(page.locator('[data-code="DH0101"]')).to_contain_text('query สำเร็จ')
        await pause(page)
        await expect(page.locator('[data-code="DH0101"]')).not_to_contain_text('จาก cache')
        assert sum(c['code']=='DH0101' for c in calls)==2
        checks.append('session namespaces isolated')
        await page.get_by_label('เลือกปีงบประมาณ').select_option('2027')
        await expect(page.locator('[data-code="DH0101"]')).to_contain_text('query สำเร็จ')
        await pause(page)
        await expect(page.locator('[data-code="DH0101"]')).not_to_contain_text('จาก cache')
        await page.get_by_label('เลือกปีงบประมาณ').select_option('2026')
        await expect(page.locator('[data-code="DH0101"]')).to_contain_text('จาก cache')
        await pause(page)
        checks.append('year isolation and return to cached year')

        await page.evaluate("""async () => {
          const r=indexedDB.open('thip-candidate-cache',2);
          const db=await new Promise(resolve=>r.onsuccess=()=>resolve(r.result));
          await new Promise((resolve,reject)=>{const tx=db.transaction('entries','readwrite'); tx.oncomplete=resolve; tx.onabort=reject;
            tx.objectStore('entries').openCursor().onsuccess=e=>{const c=e.target.result;if(!c)return; c.update({...c.value,expiresAt:Date.now()-1});c.continue();};});db.close();
        }""")
        before = len(calls)
        await page.goto(launch.replace('SYNTHETIC_CACHE_SESSION','SYNTHETIC_OTHER_SESSION'), wait_until='networkidle')
        await expect(page.locator('[data-code="DH0101"]')).to_contain_text('query สำเร็จ')
        await pause(page)
        assert len(calls)>before
        await expect(page.locator('[data-code="DH0101"]')).not_to_contain_text('จาก cache')
        checks.append('expired disk entries refetched')
        await page.locator('.kpi-cache-menu').evaluate('(element)=>element.open=true')
        await page.get_by_role('button', name='ล้าง cache ทั้งหมด', exact=True).click()
        await expect(page.locator('.kpi-load-bar')).to_contain_text('ล้าง cache แล้ว')
        await expect(page.get_by_role('button', name='โหลดใหม่ทั้งคิว', exact=True)).to_be_enabled()
        assert await page.evaluate(READ)==[]
        before=len(calls); await asyncio.sleep(1.3); assert len(calls)==before
        await expect(page.locator('[data-code="DH0101"]')).not_to_contain_text('query สำเร็จ')
        checks.append('clear-all aborts and waits for manual restart')
        await ctx.close()

        # Upgrade the old schema without trusting its obsolete fingerprints.
        migration = await p.chromium.launch(headless=True)
        tab = await migration.new_context()
        await tab.route('https://**', lambda route: route.abort())
        migration_calls = await fixtures(tab)
        page = await tab.new_page()
        await page.goto(f'{BASE}/?fy=2026',wait_until='networkidle')
        await page.evaluate("""async () => {
          const db=await new Promise((resolve,reject)=>{const r=indexedDB.open('thip-candidate-cache',1);r.onupgradeneeded=()=>r.result.createObjectStore('entries',{keyPath:'key'});r.onsuccess=()=>resolve(r.result);r.onerror=reject;});
          await new Promise((resolve,reject)=>{const tx=db.transaction('entries','readwrite');tx.oncomplete=resolve;tx.onabort=reject;tx.objectStore('entries').put({key:'obsolete-aggregate',version:1,facts:[]});});db.close();
        }""")
        await page.goto(launch,wait_until='networkidle')
        await expect(page.locator('[data-code="DH0101"]')).to_contain_text('query สำเร็จ')
        await pause(page)
        stored = await page.evaluate(READ)
        assert any(c['code']=='DH0101' for c in migration_calls)
        assert stored and all(row['version']==2 and row['key']!='obsolete-aggregate' for row in stored)
        checks.append('v1 schema invalidated and upgraded before query')
        await migration.close()

        ctx = await p.chromium.launch(headless=True)
        tab = await ctx.new_context()
        await tab.add_init_script("Object.defineProperty(window,'indexedDB',{value:{open(){throw new Error('SYNTHETIC_STORAGE_DENIED')}}});")
        await fixtures(tab)
        page=await tab.new_page()
        page.on('pageerror',lambda error:errors.append(str(error)))
        await page.goto(launch, wait_until='networkidle')
        await expect(page.locator('[data-code="DH0101"]')).to_contain_text('query สำเร็จ')
        await expect(page.locator('.kpi-load-bar')).to_contain_text('Cache ข้าม refresh ไม่พร้อม')
        await pause(page)
        checks.append('storage denied falls back without stopping queue')
        await page.locator('.kpi-cache-menu').evaluate('(element)=>element.open=true')
        await page.get_by_role('button', name='ล้าง cache ทั้งหมด', exact=True).click()
        await expect(page.locator('.kpi-load-bar')).to_contain_text('cache บนเครื่องยังล้างไม่ได้')
        await expect(page.get_by_role('button', name='โหลดใหม่ทั้งคิว', exact=True)).to_be_enabled()
        await page.locator('.kpi-cache-menu').evaluate('(element)=>element.open=true')
        await page.get_by_role('button', name='โหลดใหม่ทั้งคิว', exact=True).click()
        await expect(page.locator('[data-code="DH0101"]')).to_contain_text('query สำเร็จ')
        await pause(page)
        checks.append('failed disk clear is explicit and restart still works')
        await ctx.close()
    assert not errors, errors
    result={'passed':checks,'pageErrors':errors,'realBmsCalls':0}
    (OUT/'cache-result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(result,ensure_ascii=False))

if __name__=='__main__': asyncio.run(main())
