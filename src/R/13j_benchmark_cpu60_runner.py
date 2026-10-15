# Synthetic benchmark: one-worker preflight followed by ten single-thread workers.
import subprocess,time,pathlib,csv,json,os
root=pathlib.Path('data/processed/qc_13j_cpu60_benchmark_v1')
script='src/R/13j_benchmark_cpu60_synthetic.R'
subprocess.run(['Rscript',script,'setup'],check=True)
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
    for path,data in [(root/'phases.csv',rows),(root/(label+'_memory.csv'),samples)]:
        with open(path,'w',newline='') as f:
            w=csv.DictWriter(f,fieldnames=data[0].keys());w.writeheader();w.writerows(data)
    print(row,flush=True)
    return row
first=phase('gc_single',[(1,'gc_single_1')])
if first['status']!='completed':raise RuntimeError('Single worker failed')
required=first['aggregate_peak_rss_kib']*10*1.15+1024*1024
available=mem()['MemAvailable']
(root/'preflight.json').write_text(json.dumps(dict(logical_cpus=os.cpu_count(),workers=10,required_kib=required,available_kib=available),indent=2))
if available<required:
    print('Ten-worker phase blocked by measured memory preflight.',flush=True)
else:
    result=phase('gc_ten',[(i,f'gc_ten_{i}') for i in range(1,11)])
    if result['status']!='completed':raise RuntimeError(result['status'])
