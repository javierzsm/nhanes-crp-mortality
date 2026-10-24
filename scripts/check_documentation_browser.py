#!/usr/bin/env python3
"""Inspect local MathML in a disposable headless Chrome session (no user profile).

Requires websockets and the HTML build from render_documentation.py.
Screenshots remain local. The CSV contains only equation layout summaries.
"""
import asyncio
import base64
import csv
import json
from pathlib import Path
import re
import shutil
import tempfile
import websockets

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT/'output/documentation_preview'
AUDIT = ROOT/'reports/documentation_quality_v1'


async def main():
    chrome = shutil.which('google-chrome') or shutil.which('chromium')
    if not chrome:
        raise RuntimeError('Chrome/Chromium is required for local visual QA.')
    profile = tempfile.mkdtemp(prefix='nhanes-docs-browser-')
    proc = await asyncio.create_subprocess_exec(
        chrome, '--headless=new', '--no-sandbox', '--disable-gpu',
        '--disable-dev-shm-usage', '--no-first-run', '--no-default-browser-check',
        '--remote-debugging-port=0', '--user-data-dir='+profile, 'about:blank',
        stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.PIPE)
    try:
        endpoint = None
        for _ in range(100):
            line = (await asyncio.wait_for(proc.stderr.readline(), 15)).decode()
            match = re.search(r'DevTools listening on (ws://\S+)', line)
            if match:
                endpoint = match[1]
                break
            if not line:
                raise RuntimeError('Browser exited before local inspection.')
        if not endpoint:
            raise RuntimeError('No browser inspection endpoint.')
        async with websockets.connect(endpoint, max_size=32*1024*1024) as ws:
            serial = 0

            async def send(method, params=None, session=None):
                nonlocal serial
                serial += 1
                message = dict(id=serial, method=method, params=params or {})
                if session:
                    message['sessionId'] = session
                await ws.send(json.dumps(message))
                while True:
                    result = json.loads(await ws.recv())
                    if result.get('id') == serial:
                        if 'error' in result:
                            raise RuntimeError(result['error'])
                        return result.get('result', {})

            target = await send('Target.createTarget', {'url':'about:blank'})
            session = (await send('Target.attachToTarget',
                                 {'targetId':target['targetId'],'flatten':True}))['sessionId']
            await send('Page.enable', session=session)
            files = list(csv.DictReader((AUDIT/'render_validation.csv').open()))
            rows = []
            screenshots = BUILD/'screenshots'
            screenshots.mkdir(exist_ok=True)
            for item in files:
                if int(item['equations']) == 0:
                    continue
                source = item['path']
                path = BUILD/Path(source).with_suffix('.html')
                for width in (1440, 480):
                    await send('Emulation.setDeviceMetricsOverride',
                               {'width':width,'height':1100,'deviceScaleFactor':1,'mobile':False},session)
                    await send('Page.navigate', {'url':path.as_uri()},session)
                    expression = """(async()=>{
                      await document.fonts.ready;
                      if(document.readyState!=='complete')await new Promise(r=>window.addEventListener('load',r,{once:true}));
                      const main=document.querySelector('main')||document.body;
                      const m=[...main.querySelectorAll('math')];
                      const boxes=m.map(x=>{let b=x.getBoundingClientRect();return {w:b.width,h:b.height}});
                      const scroll=[...main.querySelectorAll('.math-display-scroll')];
                      return {equations:m.length,zero_boxes:boxes.filter(x=>x.w<=0||x.h<=0).length,
                        math_errors:main.querySelectorAll('merror').length,
                        overflow_equations:scroll.filter(x=>x.scrollWidth>x.clientWidth+2).length,
                        clipped_equations:scroll.filter(x=>x.scrollWidth>x.clientWidth+2 && getComputedStyle(x).overflowX!=='auto').length,
                        font: getComputedStyle(m[0]||main).fontFamily, language:document.documentElement.lang};
                    })()"""
                    # Wait for the newly navigated document, rather than a stale prior page.
                    for _ in range(100):
                        current = await send('Runtime.evaluate', {'expression':'location.href'},session)
                        if current.get('result',{}).get('value') == path.as_uri():
                            break
                        await asyncio.sleep(.05)
                    result = await send('Runtime.evaluate',
                                        {'expression':expression,'awaitPromise':True,'returnByValue':True},session)
                    values = result.get('result',{}).get('value')
                    if values is None:
                        raise RuntimeError(result)
                    row = dict(path=source, width=width, **values)
                    row['passed'] = (values['equations']==int(item['equations']) and
                                     not values['zero_boxes'] and not values['math_errors'] and
                                     not values['clipped_equations'] and values['language']=='en')
                    rows.append(row)
                    # Screenshots cover the dense companion and the older Cox guide.
                    if 'manuscrito_metodologico' in source or 'cox_model_explained' in source:
                        sections = ['sec-cox','sec-splines','sec-rubin'] if 'manuscrito' in source else ['partial-likelihood','restricted-cubic-splines']
                        for section in sections:
                            await send('Runtime.evaluate', {'expression':
                                f"(async()=>{{document.documentElement.style.setProperty('scroll-behavior','auto','important');const s=document.getElementById({json.dumps(section)});const e=(s&&s.querySelector('math'))||s||document.querySelector('math');window.scrollTo({{top:window.scrollY+e.getBoundingClientRect().top-220,behavior:'instant'}});await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));}})()", 'awaitPromise':True},session)
                            shot = await send('Page.captureScreenshot', {'format':'png'},session)
                            name = f'{path.stem}-{section}-{width}.png'
                            (screenshots/name).write_bytes(base64.b64decode(shot['data']))
                    print(f'{source} width={width}: {values["equations"]} equations; passed={row["passed"]}',flush=True)
            with (AUDIT/'browser_validation.csv').open('w',newline='') as stream:
                writer=csv.DictWriter(stream,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
            if not all(x['passed'] for x in rows):
                raise SystemExit('Browser checks failed.')
            await send('Browser.close')
    finally:
        if proc.returncode is None:
            proc.terminate()
        await proc.wait()
        shutil.rmtree(profile,ignore_errors=True)


if __name__=='__main__':
    asyncio.run(main())
