"""Shared SPA regression; deny real HTTPS, use aggregate fixtures only."""
import asyncio
import csv
import io
import json
import os
from pathlib import Path
from playwright.async_api import async_playwright, expect
from step_browser_smoke import fixtures
ROOT=Path(__file__).resolve().parents[1]
BASE=os.environ.get('THIP_SMOKE_BASE_URL','http://127.0.0.1:5173')
SOURCE=os.environ.get('THIP_SOURCE_BASE_URL','http://127.0.0.1:5175')
OUT=ROOT/'tmp/shared-kpi';OUT.mkdir(parents=True,exist_ok=True)
async def main():
  checks=[];errors=[]
  async with async_playwright() as p:
    browser=await p.chromium.launch(headless=True)
    for device,viewport in [('desktop',{'width':1440,'height':1000}),('mobile',{'width':390,'height':844})]:
      ctx=await browser.new_context(viewport=viewport)
      await ctx.route('https://**',lambda route:route.abort())
      calls=await fixtures(ctx);page=await ctx.new_page();page.on('pageerror',lambda e:errors.append(str(e)))
      await page.goto(BASE+'/?fy=2026&bms-session-id=SYNTHETIC_SHARED',wait_until='domcontentloaded')
      cell=page.locator('#monitoring-DH0101-1')
      await expect(cell).to_contain_text('10')
      assert len(calls)<177
      await page.get_by_role('button',name='พัก',exact=True).click()
      await expect(page.get_by_role('button',name='ต่อ',exact=True)).to_be_enabled()
      count=len(calls)
      assert await page.locator('.monitoring-cell').count()==2784
      assert await page.locator('.monitoring-matrix tbody tr').count()==232
      assert await page.locator('.state-not-applicable').count()==1232
      await page.get_by_role('button',name='ติดตามรายเดือน',exact=True).click()
      await expect(cell).to_contain_text('10')
      await page.get_by_role('button',name='รายงาน THIP',exact=True).click()
      await cell.focus();await page.keyboard.press('ArrowRight');await expect(page.locator('#monitoring-DH0101-2')).to_be_focused()
      await page.keyboard.press('Enter');await expect(page.locator('dialog[open]')).to_contain_text('ยังไม่รับรอง')
      await page.keyboard.press('Escape');await expect(page.locator('#monitoring-DH0101-2')).to_be_focused()
      await cell.click();await expect(page.locator('dialog[open]')).to_contain_text('ตัวตั้ง');await page.get_by_role('button',name='ดูทุกงวดของ DH0101').click()
      await expect(page.locator('.kpi-detail-periods')).to_contain_text('10')
      await expect(page.locator('.kpi-trend')).to_be_visible()
      await page.get_by_role('button',name='กลับภาพรวม',exact=True).click()
      await expect(page.locator('.kpi-overview-row').filter(has_text='DH0101').first).to_contain_text('10')
      async def nav(text):
        if device=='mobile':await page.get_by_role('button',name='เปิดเมนู',exact=True).click()
        await page.locator('.sidebar-nav-item').filter(has_text=text).click()
      await nav('คลังตัวชี้วัด');await expect(page.locator('.catalog-table tbody tr').filter(has_text='DH0101').first).to_contain_text('มีค่าในโหมดที่เลือก')
      await nav('ตรวจข้อมูลทีละ KPI');await expect(page.locator('.step-table [data-code="DH0101"]')).to_contain_text('query สำเร็จ')
      await nav('ตารางตัวชี้วัด');await expect(cell).to_contain_text('10')
      assert len(calls)==count,'Navigation repeated aggregate queries'
      await page.get_by_role('button',name='รับรองแล้ว',exact=True).click();await expect(cell).to_contain_text('รอรับรอง')
      assert await cell.locator('strong').inner_text()=='—'
      await page.get_by_role('button',name='สอบทาน',exact=True).click();await expect(cell).to_contain_text('10')
      await page.get_by_label('ค้นหารหัสหรือชื่อ KPI').fill('DH0101')
      await expect(page.locator('.monitoring-matrix tbody tr:not([hidden])')).to_have_count(3)
      with_download=page.expect_download()
      async with with_download as download:
        await page.get_by_role('button',name='CSV สอบทาน',exact=True).click()
      artifact=await download.value;path=await artifact.path();rows=list(csv.DictReader(io.StringIO(Path(path).read_text(encoding='utf-8-sig'))))
      assert len(rows)==36 and all('UNAPPROVED REVIEW' in row['data_label'] for row in rows)
      assert artifact.suggested_filename=='thip-report-2569-unapproved-review.csv'
      await page.get_by_label('ค้นหารหัสหรือชื่อ KPI').fill('')
      await page.evaluate('scrollTo(0,0)');await page.screenshot(path=str(OUT/f'{device}.png'),full_page=True)
      assert await page.evaluate('document.documentElement.scrollWidth<=innerWidth')
      if device=='mobile':
        scroll=page.locator('.monitoring-scroll');identity=page.locator('.monitoring-matrix tbody tr .monitoring-identity').first
        before=(await identity.bounding_box())['x'];await scroll.evaluate('(e)=>e.scrollLeft=600');after=(await identity.bounding_box())['x'];assert abs(before-after)<1
      # Request in flight continues through navigation and the central controls stay active.
      await page.get_by_role('button',name='ต่อ',exact=True).click();await nav('ภาพรวมคุณภาพ')
      await page.wait_for_timeout(1400);assert len(calls)>count
      await page.get_by_role('button',name='พัก',exact=True).click();await expect(page.get_by_role('button',name='ต่อ',exact=True)).to_be_enabled()
      assert sum(call['code']=='DH0101' for call in calls)==1
      assert all(b['at']-a['end']>=.94 for a,b in zip(calls,calls[1:]) if a['end'])
      assert 'SYNTHETIC_SHARED' not in page.url
      assert await page.evaluate('localStorage.length+sessionStorage.length')==0
      checks.append(device+': shared results/routes, cadence slots, approval, keyboard, CSV, queue persistence, responsive')
      await ctx.close()
    # Configured per-code source views have independent cache/series and never use native SQL.
    ctx=await browser.new_context();await ctx.route('https://**',lambda route:route.abort());await fixtures(ctx)
    fixture=json.loads((ROOT/'test-fixtures/thip-kpi-complete-2026.json').read_text(encoding='utf-8'))
    meta=json.loads((ROOT/'src/data/thipRuntimeMetadata.json').read_text(encoding='utf-8'));rules={r['code']:r for r in meta['monitoringRules']};source_calls=[]
    async def source_sql(route):
      if route.request.method=='OPTIONS':await route.fallback();return
      payload=route.request.post_data_json;sql=payload['sql']
      if 'SELECT VERSION()' in sql:await route.fallback();return
      headers={'Access-Control-Allow-Origin':'*'};code=payload['params']['indicator_code']['value'];year=payload['params']['fiscal_year']['value'];source_calls.append((code,year,'monitoring' if 'thip_monthly_monitoring' in sql else 'reporting'))
      if 'FROM reporting.thip_monthly_monitoring' in sql:
        rule=rules[code];start=f'{year-1}-10-01'
        result=[dict(code=code,fiscalYear=year,fiscalMonth=1,periodStart=start,periodEnd=f'{year-1}-11-01',dataThrough=f'{year-1}-10-31',numerator=5,denominator=100,value=5,unit=rule['unit'],target=None,cumulative=dict(numerator=None,denominator=None,value=None,through=None,complete=False),accumulation=rule['accumulation'],formula=rule['formula'],method=rule['method'],dataStatus='measured',assessment='no-target',reason=None,ruleVersion=rule['version'],refreshedAt='2026-10-01T00:00:00Z',synthetic=False)] if year==2026 else []
      else:
        assert 'FROM "reporting"."thip_kpi_monthly"' in sql
        result=[row for row in fixture if row['indicator_code']==code and row['fiscal_year']==year]
      await route.fulfill(json={'result':result},headers=headers)
    await ctx.route('https://step.mock.invalid/**',source_sql)
    page=await ctx.new_page();page.on('pageerror',lambda e:errors.append(str(e)))
    await page.goto(SOURCE+'/?fy=2026&bms-session-id=SYNTHETIC_SOURCE',wait_until='domcontentloaded')
    await page.wait_for_function("document.querySelector('.step-counts')?.dataset.querySuccesses >= 3")
    await page.get_by_role('button',name='พัก',exact=True).click();await expect(page.get_by_role('button',name='ต่อ',exact=True)).to_be_enabled()
    await page.get_by_role('button',name='ติดตามรายเดือน',exact=True).click();await expect(page.locator('#monitoring-DH0101-1')).to_contain_text('5')
    before=len(source_calls);await page.reload(wait_until='domcontentloaded');await expect(page.locator('#monitoring-DH0101-1')).not_to_contain_text('5')
    await page.get_by_label('BMS Session ID').fill('SYNTHETIC_SOURCE');await page.get_by_role('button',name='เชื่อมต่อ',exact=True).click()
    await expect(page.locator('#monitoring-DH0101-1')).to_contain_text('5');await page.get_by_role('button',name='พัก',exact=True).click();await expect(page.get_by_role('button',name='ต่อ',exact=True)).to_be_enabled()
    assert sum(code=='DH0101' and series=='monitoring' for code,year,series in source_calls)==1
    await page.get_by_label('เลือกปีงบประมาณ').select_option('2025');await expect(page.locator('#monitoring-DH0101-1')).not_to_contain_text('5')
    assert await page.locator('.monitoring-cell').count()==2784
    checks.append('configured reporting/monitoring per-code sources, cache namespace, session prerequisite, year reset')
    await ctx.close();await browser.close()
  assert not errors,errors
  result={'passed':checks,'realBmsCalls':0,'pageErrors':errors};(OUT/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(result,ensure_ascii=False))
if __name__=='__main__':asyncio.run(main())
