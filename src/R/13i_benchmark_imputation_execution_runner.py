import subprocess,time,pathlib,csv
root=pathlib.Path('data/processed/qc_13i_execution_benchmark_v1')
script='src/R/13i_benchmark_imputation_execution_synthetic.R'
subprocess.run(['Rscript',script,'setup'],check=True)
rows=[]
def phase(label,jobs):
    handles=[]; ps=[]; begin=time.monotonic(); peak=0
    for mode,chain,name in jobs:
        h=open(root/(name+'.log'),'w'); handles.append(h)
        ps.append(subprocess.Popen(['Rscript',script,mode,str(chain),name],stdout=h,stderr=subprocess.STDOUT))
    while any(p.poll() is None for p in ps):
        rss=0
        for p in ps:
            try:
                for line in pathlib.Path(f'/proc/{p.pid}/status').read_text().splitlines():
                    if line.startswith('VmRSS:'): rss+=int(line.split()[1])
            except FileNotFoundError: pass
        peak=max(peak,rss); time.sleep(.2)
    for h in handles:h.close()
    if any(p.returncode for p in ps):raise RuntimeError(f'{label} worker failure; inspect logs')
    rows.append(dict(phase=label,wall_seconds=time.monotonic()-begin,aggregate_peak_rss_kib=peak,workers=len(ps)))
    with open(root/'phases.csv','w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=rows[0].keys());w.writeheader();w.writerows(rows)
    print(rows[-1],flush=True)
phase('sequential_original_1',[('original',1,'original_1')])
phase('sequential_original_2',[('original',2,'original_2')])
phase('sequential_compact_1',[('compact',1,'compact_1')])
phase('sequential_compact_2',[('compact',2,'compact_2')])
phase('parallel_compact',[('compact',1,'parallel_1'),('compact',2,'parallel_2')])
# Reload identical verified input checkpoint and replay stream 1 in a fresh process.
phase('checkpoint_replay',[('compact',1,'replay_1')])
