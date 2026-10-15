# Synthetic benchmark: one-worker preflight followed by ten single-thread workers.
import subprocess,time,pathlib,csv,json,os
root=pathlib.Path('data/processed/qc_13j_cpu60_benchmark_v1')
script='src/R/13j_benchmark_cpu60_synthetic.R'
if not root.is_dir(): raise RuntimeError('Run the 13j preflight first.')
if (root/'four_phases.csv').exists(): raise RuntimeError('Four-worker benchmark exists.')
def mem():
    return {s.split(':')[0]:int(s.split()[1]) for s in pathlib.Path('/proc/meminfo').read_text().splitlines() if s.startswith(('MemAvailable:','SwapFree:'))}
rows=[]
def phase(label,jobs):
    handles=[];ps=[];begin=time.monotonic();peak=0;minimum=mem()['MemAvailable'];swapstart=mem()['SwapFree'];samples=[];reason='completed'
    try:
        for chain,name in jobs:
            h=open(root/(name+'.log'),'w');handles.append(h)
            ps.append(subprocess.Popen(['Rscript',script,'compact',str(chain),name],stdout=h,stderr=subprocess.STDOUT))
        while any(p.poll() is None for p in ps):
            rss=0
            for p in ps:
                try:
                    for line in pathlib.Path(f'/proc/{p.pid}/status').read_text().splitlines():
                        if line.startswith('VmRSS:'):rss+=int(line.split()[1])
                except FileNotFoundError:pass
            m=mem();peak=max(peak,rss);minimum=min(minimum,m['MemAvailable'])
            samples.append(dict(seconds=time.monotonic()-begin,rss_kib=rss,available_kib=m['MemAvailable'],swap_free_kib=m['SwapFree']))
            if m['MemAvailable']<1024*1024:
                reason='memory_guard';break
            time.sleep(.2)
    finally:
        if reason!='completed':
            for p in ps:
                if p.poll() is None:p.terminate()
        for p in ps:p.wait()
        for h in handles:h.close()
    if reason=='completed' and any(p.returncode for p in ps):reason='worker_failed'
    row=dict(phase=label,wall_seconds=time.monotonic()-begin,aggregate_peak_rss_kib=peak,workers=len(ps),minimum_available_kib=minimum,swap_free_delta_kib=mem()['SwapFree']-swapstart,status=reason)
    rows.append(row)
    for path,data in [(root/'four_phases.csv',rows),(root/(label+'_memory.csv'),samples)]:
        with open(path,'w',newline='') as f:
            w=csv.DictWriter(f,fieldnames=data[0].keys());w.writeheader();w.writerows(data)
    print(row,flush=True)
    return row

previous=list(csv.DictReader(open(root/'phases.csv')))[0]
required=float(previous['aggregate_peak_rss_kib'])*4*1.15+1024*1024
available=mem()['MemAvailable']
(root/'four_preflight.json').write_text(json.dumps(dict(workers=4,required_kib=required,available_kib=available),indent=2))
if available<required: raise RuntimeError('Four-worker memory preflight failed.')
result=phase('gc_four',[(i,f'gc_four_{i}') for i in range(1,5)])
if result['status']!='completed':raise RuntimeError(result['status'])
for i in range(2,5):
    result=phase(f'gc_single_{i}',[(i,f'gc_single_{i}')])
    if result['status']!='completed':raise RuntimeError(result['status'])
