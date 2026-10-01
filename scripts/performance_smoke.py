"""Production gzip/lab benchmark. Every BMS request is mocked, all rows synthetic.

EventTiming samples are an interaction lab proxy, not field INP. Metrics contain
only route/device/timings/counts, never launch URLs, credentials or facts.
"""
import asyncio
import json
import math
import os
from pathlib import Path
import subprocess
import time
import urllib.request
from playwright.async_api import async_playwright
from step_browser_smoke import fixtures

ROOT = Path(__file__).resolve().parents[1]
BASE = 'http://127.0.0.1:5186'
META = json.loads((ROOT/'src/data/thipRuntimeMetadata.json').read_text(encoding='utf-8'))
STEPS = json.loads((ROOT/'reporting/thip_step_queries.manifest.json').read_text(encoding='utf-8'))['steps']
INIT = """window.__perf={lcp:0,cls:0,events:[],long:[]};
new PerformanceObserver(l=>{for(const e of l.getEntries())__perf.lcp=e.startTime}).observe({type:'largest-contentful-paint',buffered:true});
new PerformanceObserver(l=>{for(const e of l.getEntries())if(!e.hadRecentInput)__perf.cls+=e.value}).observe({type:'layout-shift',buffered:true});
new PerformanceObserver(l=>{for(const e of l.getEntries())if(e.interactionId)__perf.events.push({id:e.interactionId,duration:e.duration})}).observe({type:'event',buffered:true,durationThreshold:16});
new PerformanceObserver(l=>{for(const e of l.getEntries())__perf.long.push(e.duration)}).observe({type:'longtask',buffered:true});"""

def p75(values):
    return sorted(values)[max(0, math.ceil(len(values)*.75)-1)]

async def seed_cache(page):
    # The session itself stays in fixture memory. Only digests and aggregate
    # projections enter the same IndexedDB schema used by the app.
    await page.evaluate("""async ({meta,steps}) => {
      const digest=async x=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(JSON.stringify(x))))).map(x=>x.toString(16).padStart(2,'0')).join('');
      const scope=await digest(['https://step.mock.invalid','10929','THIP.KPI.BMS','SYNTHETIC_STEP_TOKEN_SYNTHETIC_PERF_CACHE','']);
      const signatures=new Map(meta.signatures.map(x=>[x.code,x])); const rules=new Map(meta.rules.map(x=>[x.code,x])); const monitoring=new Map(meta.monitoringRules.map(x=>[x.code,x]));
      const observedMs=Date.now(), observedAt=new Date(observedMs).toISOString(), expiresAt=observedMs+86400000;
      const entries=await Promise.all(steps.map(async step=>{
        const s=signatures.get(step.code), rule=rules.get(step.code), unit=monitoring.get(step.code).unit;
        const fingerprint=await digest([s.sqlHash,s.ruleHash,'2025-10-01','2026-10-01',unit]);
        const facts=step.expectedMonths.map(month=>({indicator_code:step.code,fiscal_year:2026,fiscal_month:month,period_start:`${month<=3?2025:2026}-${String(month<=3?month+9:month-3).padStart(2,'0')}-01`,numerator:1,denominator:10,value:0.1}));
        return {key:`${scope}:2026:thip-report:${step.code}:${fingerprint}`,scope,version:2,fiscalYear:2026,code:step.code,fingerprint,ruleVersion:rule.ruleVersion??'candidate-unversioned',observedAt,expiresAt,facts};
      }));
      const db=await new Promise((resolve,reject)=>{const r=indexedDB.open('thip-candidate-cache',2);r.onupgradeneeded=()=>{const store=r.result.createObjectStore('entries',{keyPath:'key'});store.createIndex('context',['scope','fiscalYear']);store.createIndex('expiry','expiresAt');};r.onsuccess=()=>resolve(r.result);r.onerror=reject;});
      await new Promise((resolve,reject)=>{const tx=db.transaction('entries','readwrite');tx.oncomplete=resolve;tx.onerror=reject;for(const entry of entries)tx.objectStore('entries').put(entry);});db.close();
    }""", {'meta': META, 'steps': STEPS})

async def measure():
    measurements=[]; errors=[]
    async with async_playwright() as p:
        browser=await p.chromium.launch(headless=True)
        for device,viewport,cpu in [('desktop',{'width':1440,'height':1000},1),('mobile',{'width':390,'height':844},4)]:
            for repeat in range(5):
                ctx=await browser.new_context(viewport=viewport)
                # A broad deny route makes an accidental unmocked hospital call impossible.
                await ctx.route('https://**',lambda route:route.abort())
                await ctx.add_init_script(INIT); page=await ctx.new_page()
                page.on('pageerror',lambda error: errors.append(type(error).__name__))
                cdp=await ctx.new_cdp_session(page);await cdp.send('Emulation.setCPUThrottlingRate',{'rate':cpu});await cdp.send('Network.enable')
                await cdp.send('Network.emulateNetworkConditions',{'offline':False,'latency':100,'downloadThroughput':200000,'uploadThroughput':93750})
                await page.goto(BASE+'/?view=monitoring&fy=2026',wait_until='domcontentloaded')
                await page.wait_for_function("document.querySelector('.monitoring-matrix')?.getAttribute('aria-busy')==='false'")
                await page.wait_for_timeout(400)
                result=await page.evaluate("""({lcp:__perf.lcp,cls:__perf.cls,readyMs:performance.now(),jsBytes:performance.getEntriesByType('resource').filter(x=>x.name.split('?')[0].endsWith('.js')).reduce((n,x)=>n+x.encodedBodySize,0),rows:document.querySelectorAll('.monitoring-matrix tbody tr').length,cells:document.querySelectorAll('.monitoring-cell').length,nodes:document.querySelectorAll('*').length,blockingMs:__perf.long.reduce((n,x)=>n+Math.max(0,x-50),0)})""")
                assert result['rows']==232 and result['cells']==2784
                await page.evaluate("window.__firstRow=document.querySelector('.monitoring-matrix tbody tr')")
                search=page.get_by_label('ค้นหารหัสหรือชื่อ KPI')
                await search.press_sequentially('DH0101',delay=80)
                await page.wait_for_function("document.querySelectorAll('.monitoring-matrix tbody tr:not([hidden])').length===3")
                await search.press('ControlOrMeta+A');await search.press('Backspace')
                await page.wait_for_function("document.querySelectorAll('.monitoring-matrix tbody tr:not([hidden])').length===232")
                assert await page.evaluate("__firstRow===document.querySelector('.monitoring-matrix tbody tr')")
                await page.locator('.monitoring-cell').first.focus()
                for _ in range(6):await page.keyboard.press('ArrowRight');await page.wait_for_timeout(60)
                await page.keyboard.press('Enter');await page.wait_for_selector('dialog[open]')
                await page.keyboard.press('Escape');assert await page.locator('dialog[open]').count()==0
                await page.wait_for_timeout(200)
                durations=await page.evaluate("Object.values(__perf.events.reduce((m,e)=>{m[e.id]=Math.max(m[e.id]??0,e.duration);return m},{}))")
                result.update(device=device,repeat=repeat+1,interactionMs=p75(durations) if durations else 16)
                measurements.append(result);print(json.dumps(result),flush=True)
                await ctx.close()
            # All 177 native cache entries are restored after the verified probe,
            # with route modules already loaded; no native query is permitted.
            for repeat in range(5):
                ctx=await browser.new_context(viewport=viewport);await ctx.route('https://**',lambda route:route.abort());calls=await fixtures(ctx)
                page=await ctx.new_page();cdp=await ctx.new_cdp_session(page);await cdp.send('Emulation.setCPUThrottlingRate',{'rate':cpu})
                await page.goto(BASE+'/?view=validation&fy=2026',wait_until='networkidle');await seed_cache(page)
                await page.get_by_label('BMS Session ID').fill('SYNTHETIC_PERF_CACHE')
                start=time.perf_counter();await page.get_by_role('button',name='เชื่อมต่อ',exact=True).click()
                await page.wait_for_function("document.querySelector('.step-counts')?.dataset.cacheHits==='177'")
                assert not calls
                measurements.append({'device':device,'view':'cache','repeat':repeat+1,'restoreMs':round((time.perf_counter()-start)*1000),'cacheHits':177})
                await ctx.close()
        await browser.close()
    summaries={}
    for device in ['desktop','mobile']:
        cold=[x for x in measurements if x['device']==device and 'lcp' in x];warm=[x for x in measurements if x['device']==device and x.get('view')=='cache']
        summaries[device]={k:p75([x[k] for x in cold]) for k in ['lcp','cls','jsBytes','interactionMs','readyMs','blockingMs']}
        summaries[device]['restoreMs']=p75([x['restoreMs'] for x in warm])
    result={'profile':{'downloadMbps':1.6,'latencyMs':100,'mobileCpuSlowdown':4,'runs':5},'labOnly':True,'hospitalQueries':0,'measurements':measurements,'p75':summaries}
    out=ROOT/'tmp/performance';out.mkdir(parents=True,exist_ok=True);(out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(summaries),flush=True)
    failures=[]
    for device,limits in [('desktop',{'lcp':2000,'cls':.1,'jsBytes':200000,'interactionMs':200,'restoreMs':1000}),('mobile',{'lcp':2500,'cls':.1,'jsBytes':200000,'interactionMs':200,'restoreMs':2000})]:
        for metric,limit in limits.items():
            if summaries[device][metric]>limit:failures.append(f'{device}/{metric}: {summaries[device][metric]} > {limit}')
    assert not errors,errors
    assert not failures,failures

def main():
    proc=subprocess.Popen(['node','scripts/performance-server.mjs'],cwd=ROOT,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,creationflags=0x08000000 if os.name=='nt' else 0)
    try:
        for _ in range(100):
            if proc.poll() is not None:raise RuntimeError('Performance server failed to start; port 5186 must be free')
            try:urllib.request.urlopen(BASE,timeout=.2).close();break
            except OSError:time.sleep(.1)
        else:raise RuntimeError('Performance fixture server unavailable')
        asyncio.run(measure())
    finally:proc.terminate();proc.wait(timeout=10)

if __name__=='__main__':main()
