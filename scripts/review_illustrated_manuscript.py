#!/usr/bin/env python3
"""Review embedded figures in the local v0.3 manuscripts using a temporary browser."""
import asyncio,base64,csv,json,re,shutil,tempfile
from pathlib import Path
import websockets
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/documentation_preview/stage6_v3_review'
async def main():
 OUT.mkdir(parents=True,exist_ok=True)
 profile=tempfile.mkdtemp(prefix='nhanes-figure-browser-')
 p=await asyncio.create_subprocess_exec(shutil.which('google-chrome'),'--headless=new','--no-sandbox','--disable-gpu','--disable-dev-shm-usage','--no-first-run','--no-default-browser-check','--remote-debugging-port=0','--user-data-dir='+profile,'about:blank',stdout=asyncio.subprocess.DEVNULL,stderr=asyncio.subprocess.PIPE)
 try:
  while True:
   line=(await p.stderr.readline()).decode();m=re.search(r'DevTools listening on (ws://\S+)',line)
   if m:break
   if not line:raise RuntimeError('Browser failed')
  async with websockets.connect(m[1],max_size=32*1024*1024) as ws:
   ident=0
   async def send(method,params=None,session=None):
    nonlocal ident
    ident+=1;obj=dict(id=ident,method=method,params=params or {})
    if session:obj['sessionId']=session
    await ws.send(json.dumps(obj))
    while True:
     reply=json.loads(await ws.recv())
     if reply.get('id')==ident:
      if 'error' in reply:raise RuntimeError(reply['error'])
      return reply.get('result',{})
   t=await send('Target.createTarget',{'url':'about:blank'})
   session=(await send('Target.attachToTarget',{'targetId':t['targetId'],'flatten':True}))['sessionId']
   await send('Page.enable',session=session)
   rows=[]
   for name,expected in [('manuscript_methods_results',3),('supplementary_figures',2)]:
    file=ROOT/f'reports/stage6_v3/{name}.html'
    for width in (1440,480):
     await send('Emulation.setDeviceMetricsOverride',dict(width=width,height=1400,deviceScaleFactor=1,mobile=False),session)
     await send('Page.navigate',{'url':file.as_uri()},session)
     for _ in range(100):
      state=await send('Runtime.evaluate',{'expression':"JSON.stringify({url:location.href,state:document.readyState})"},session)
      state=json.loads(state['result'].get('value','{}'))
      if state.get('url')==file.as_uri() and state.get('state')=='complete':break
      await asyncio.sleep(.05)
     expression="""(async()=>{await document.fonts.ready;await Promise.all([...document.images].map(x=>x.decode().catch(()=>{})));const m=document.querySelector('main');const im=[...m.querySelectorAll('img')];return {images:im.length,broken:im.filter(x=>!x.naturalWidth).length,overflow:im.filter(x=>x.getBoundingClientRect().right>innerWidth+2).length,embedded:im.filter(x=>x.src.startsWith('data:')).length,unresolved:m.querySelectorAll('.quarto-unresolved-ref').length,captions:m.querySelectorAll('figcaption').length,lang:document.documentElement.lang};})()"""
     r=(await send('Runtime.evaluate',dict(expression=expression,awaitPromise=True,returnByValue=True),session))['result']['value']
     row=dict(document=name,width=width,**r)
     row['passed']=r['images']==expected and r['embedded']==expected and r['broken']==0 and r['overflow']==0 and r['unresolved']==0 and r['lang']=='en'
     rows.append(row)
     if width==1440:
      targets=['fig-cohort','fig-crp','fig-periods'] if expected==3 else ['supplementary-figure-s1','supplementary-figure-s2']
      for target in targets:
       expr=f"(async()=>{{document.documentElement.style.setProperty('scroll-behavior','auto','important');const x=document.getElementById({json.dumps(target)});if(!x)throw Error('Missing figure section');window.scrollTo({{top:scrollY+x.getBoundingClientRect().top-15,behavior:'instant'}});await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));}})()"
       await send('Runtime.evaluate',dict(expression=expr,awaitPromise=True),session)
       shot=await send('Page.captureScreenshot',{'format':'png'},session)
       (OUT/f'{target}.png').write_bytes(base64.b64decode(shot['data']))
     print(row,flush=True)
   with (ROOT/'reports/stage6_v3/browser_validation.csv').open('w',newline='') as f:
    writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
   assert all(x['passed'] for x in rows)
   await send('Browser.close')
 finally:
  if p.returncode is None:p.terminate()
  await p.wait();shutil.rmtree(profile,ignore_errors=True)
asyncio.run(main())
