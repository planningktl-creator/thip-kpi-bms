"""Desktop/mobile profile, shared queue and real IndexedDB smoke with intercepted BMS."""
import asyncio
import json
from pathlib import Path
from playwright.async_api import async_playwright, expect
from step_browser_smoke import fixtures, BASE

OUT = Path(__file__).resolve().parents[1]/'tmp/cohort-browser'
OUT.mkdir(parents=True,exist_ok=True)
ENTRIES = """async () => {const db=await new Promise(resolve=>{const r=indexedDB.open('thip-candidate-cache',1);r.onsuccess=()=>resolve(r.result);});const entries=await new Promise(resolve=>{const r=db.transaction('entries').objectStore('entries').getAll();r.onsuccess=()=>resolve(r.result);});db.close();return entries;}"""

async def connected(page, session='SYNTHETIC_COHORT'):
    await page.goto(f'{BASE}/?view=validation&fy=2026&bms-session-id={session}',wait_until='domcontentloaded')
    await expect(page.locator('[data-code="DH0101"]')).to_contain_text('query สำเร็จ',timeout=15000)

async def pause(page):
    await page.get_by_role('button',name='พัก',exact=True).click()
    await expect(page.get_by_role('button',name='ต่อ',exact=True)).to_be_enabled()

async def main():
    checks, errors, logs = [], [], []
    async with async_playwright() as p:
        browser=await p.chromium.launch(headless=True)
        context=await browser.new_context(viewport={'width':1440,'height':1000})
        calls=await fixtures(context); page=await context.new_page()
        page.on('pageerror',lambda e:errors.append(str(e))); page.on('console',lambda m:logs.append(m.text))
        await connected(page)
        await expect(page.locator('.cohort-card')).to_have_count(6)
        assert not any(c['code'].startswith('profile:') for c in calls)
        assert await page.locator('.cohort-evidence').count()==232
        await page.locator('[data-code="DH0112"] .cohort-evidence summary').click()
        await expect(page.locator('[data-code="DH0112"] .cohort-evidence')).to_contain_text('ผลรวมระยะเวลาวันนอน')
        await expect(page.locator('[data-code="DH0112"] .cohort-evidence')).to_contain_text('ตัวหาร COUNT admission')
        await page.get_by_role('button',name='โหลด/ใช้ cache ยอดฐาน',exact=True).click()
        await expect(page.locator('[data-profile="patient"]')).to_contain_text('อ่านยอดฐานสำเร็จ',timeout=10000)
        await pause(page)  # both consumers have used the shared lane
        await expect(page.locator('[data-profile="accounts"]')).to_contain_text('อ่านยอดฐานสำเร็จ',timeout=20000)
        await expect(page.locator('[data-profile="employees"]')).to_contain_text('ทะเบียนยังไม่ยืนยัน')
        await expect(page.locator('[data-profile="patient"]')).to_contain_text('ไม่ใช่ยอดย้อนหลัง')
        await page.locator('[data-profile="person"] summary').click()
        await expect(page.locator('[data-profile="person"]')).to_contain_text('CID ขัดแย้ง')
        for first,second in zip(calls,calls[1:]): assert first['end'] is not None and second['at']-first['end']>=.94, calls
        assert any(not c['code'].startswith('profile:') for c in calls[1:])
        checks+=['manual-only profiles','232 cohort explanations','shared lane: no overlap + 1s gap','HR remains unverified','registry snapshot label','link quality counts']
        entries=await page.evaluate(ENTRIES); profiles=[e for e in entries if e.get('series')=='cohort-profile']
        assert len(profiles)==6 and all(e['facts']==[] and ':cohort-profile:' in e['key'] for e in profiles)
        text=json.dumps(entries); assert 'SYNTHETIC_' not in text and 'step.mock.invalid' not in text
        forbidden={'hn','vn','an','cid','patient_hn','emp_cid','loginname','bearerToken','marketplaceToken'}
        assert all(not forbidden.intersection(e.get('metrics',{})) for e in profiles)
        before=len(calls); await page.get_by_role('button',name='โหลด/ใช้ cache ยอดฐาน',exact=True).click()
        await expect(page.locator('[data-profile="accounts"]')).to_contain_text('จาก cache')
        assert len(calls)==before
        await page.locator('.cohort-panel').scroll_into_view_if_needed(); await page.screenshot(path=str(OUT/'desktop.png'))
        checks+=['IndexedDB namespace isolation','aggregate-only cache/no credentials','cache avoids queries']
        await page.reload(wait_until='networkidle'); await expect(page.locator('.cohort-panel')).not_to_contain_text('จาก cache')
        await page.get_by_label('BMS Session ID').fill('SYNTHETIC_COHORT'); await page.get_by_role('button',name='เชื่อมต่อ',exact=True).click()
        await expect(page.locator('[data-code="DH0101"]')).to_contain_text('query สำเร็จ'); await pause(page)
        await page.get_by_role('button',name='โหลด/ใช้ cache ยอดฐาน',exact=True).click(); await expect(page.locator('[data-profile="accounts"]')).to_contain_text('จาก cache')
        await page.get_by_label('เดือนสอบทานยอดฐาน').select_option('2'); await expect(page.locator('.cohort-panel')).not_to_contain_text('จาก cache')
        await expect(page.locator('.cohort-panel')).to_contain_text('ยังไม่โหลด')
        await page.get_by_role('button',name='โหลด/ใช้ cache ยอดฐาน',exact=True).click(); await expect(page.locator('[data-profile="accounts"]')).to_contain_text('อ่านยอดฐานสำเร็จ',timeout=20000)
        assert any(c['code']=='profile:visits' and c['start']=='2025-11-01' for c in calls)
        await page.get_by_role('button',name='ล้าง cache ทั้งหมด',exact=True).click(); await expect(page.locator('.step-page')).to_contain_text('ล้าง cache แล้ว')
        assert not await page.evaluate(ENTRIES); await expect(page.locator('.cohort-panel')).to_contain_text('ยังไม่โหลด')
        checks+=['refresh requires session before cache','month clears old results + isolated query','clear all removes both namespaces']
        await context.close()
        mobile=await browser.new_context(viewport={'width':390,'height':844}); await fixtures(mobile)
        page=await mobile.new_page(); await connected(page); await pause(page)
        await page.locator('[data-code="DH0101"] .cohort-evidence summary').focus(); await page.keyboard.press('Enter')
        await expect(page.locator('[data-code="DH0101"] .cohort-evidence')).to_have_attribute('open','')
        assert await page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        await page.locator('.cohort-panel').scroll_into_view_if_needed(); await page.screenshot(path=str(OUT/'mobile.png'))
        checks+=['mobile no page overflow','keyboard cohort details']; await mobile.close()
        for scenario in ['profile-auth','profile-rate','profile-failure','profile-stale']:
            ctx=await browser.new_context(); calls=await fixtures(ctx,scenario); page=await ctx.new_page(); page.on('pageerror',lambda e:errors.append(str(e)))
            await connected(page); await pause(page); await page.get_by_role('button',name='โหลด/ใช้ cache ยอดฐาน',exact=True).click()
            if scenario=='profile-stale':
                while not any(c['code'].startswith('profile:') for c in calls): await asyncio.sleep(.02)
                await page.get_by_label('เดือนสอบทานยอดฐาน').select_option('2'); await asyncio.sleep(2.2)
                await expect(page.locator('.cohort-panel')).not_to_contain_text('อ่านยอดฐานสำเร็จ')
                assert not any(e.get('series')=='cohort-profile' for e in await page.evaluate(ENTRIES))
            elif scenario=='profile-failure':
                await expect(page.locator('[data-profile="accounts"]')).to_contain_text('อ่านยอดฐานสำเร็จ',timeout=20000)
                await expect(page.locator('[data-profile="person"]')).to_contain_text('route/config')
                await expect(page.locator('[data-profile="patient"]')).to_contain_text('อ่านยอดฐานสำเร็จ')
            else:
                await expect(page.locator('[data-profile="patient"]')).to_contain_text('อ่าน source ไม่สำเร็จ',timeout=10000)
                await expect(page.get_by_role('button',name='ต่อ',exact=True)).to_be_disabled()
                assert sum(c['code'].startswith('profile:') for c in calls)==1
                if scenario=='profile-rate':
                    await expect(page.get_by_role('button',name='ต่อ',exact=True)).to_be_enabled(timeout=5000)
                else: await expect(page.get_by_role('button',name='โหลด/ใช้ cache ยอดฐาน',exact=True)).to_be_disabled()
            checks.append(scenario); await ctx.close()
        assert not errors, errors; assert not any('SYNTHETIC_STEP_TOKEN' in line or 'SYNTHETIC_SECRET_ERROR' in line for line in logs)
        await browser.close()
    result={'passed':checks,'pageErrors':errors,'realBmsCalls':0}
    (OUT/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8'); print(json.dumps(result,ensure_ascii=True))

if __name__=='__main__': asyncio.run(main())
