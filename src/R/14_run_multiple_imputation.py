#!/usr/bin/env python3
"""Four-worker supervisor. Runs only after explicit invocation; stops at a review endpoint."""
import argparse, csv, hashlib, pathlib, re, shutil, subprocess, time
parser=argparse.ArgumentParser()
parser.add_argument('run_id');parser.add_argument('--endpoint',type=int,default=20)
parser.add_argument('--review-note',type=pathlib.Path)
parser.add_argument('--synthetic-test',action='store_true')
args=parser.parse_args()
if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]{0,70}',args.run_id):parser.error('Invalid run ID')
root=pathlib.Path('data/processed')/('mi14_'+args.run_id)
settings=dict(line.split('=',1) for line in (root/'execution.txt').read_text().splitlines())
chains=int(settings['m']);workers=int(settings['workers'])
if workers!=4:raise RuntimeError('Only the validated four-worker strategy is accepted.')
if args.synthetic_test:
    if settings['kind']!='synthetic' or args.endpoint!=2 or chains!=4:raise RuntimeError('Synthetic test settings required.')
else:
    if settings['kind']!='study' or chains!=50 or args.endpoint not in (20,40,60):raise RuntimeError('Study settings required.')
script='src/R/14_prepare_run_multiple_imputation.R'
subprocess.run(['Rscript',script,'--status',args.run_id],check=True)
# Memory estimate from measured explicit-GC worker peak, with 15% margin and 1-GiB reserve.
def mem():
    return {line.split(':')[0]:int(line.split()[1]) for line in pathlib.Path('/proc/meminfo').read_text().splitlines() if line.startswith(('MemAvailable:','SwapFree:'))}
required_kib=876108*workers*1.15+1024**2
if mem()['MemAvailable']<required_kib:raise RuntimeError('Insufficient available RAM for four-worker admission.')
if shutil.disk_usage(root).free<8*1024**3:raise RuntimeError('Need at least 8 GiB free disk for immutable checkpoints.')
endpoint=args.endpoint
if endpoint>20:
    previous=20 if endpoint==40 else 40
    if not (root/f'review_endpoint_{previous:03d}.csv').exists():raise RuntimeError('Previous diagnostic endpoint missing.')
    if args.review_note is None or not args.review_note.is_file() or not args.review_note.read_text().strip():raise RuntimeError('Provide a written diagnostic review with --review-note.')
    approval=root/f'extension_to_{endpoint:03d}.txt'
    content=f'prior_endpoint={previous}\nreview_sha256={hashlib.sha256(args.review_note.read_bytes()).hexdigest()}\n'+args.review_note.read_text()
    if approval.exists():
        if approval.read_text()!=content:raise RuntimeError('Different extension review already recorded.')
    else:approval.write_text(content)
# Exclusive supervisor lock. Hard-killed processes leave locks for deliberate recovery review.
lock=root/'supervisor.lock'
lock.mkdir()
active=[];samples=[];begin=time.monotonic();status='failed'
try:
    for iteration in range(1,endpoint+1):
        pending=[i for i in range(1,chains+1) if not (root/f'chain_{i:03d}'/f'iteration_{iteration:03d}.rds').exists()]
        while pending or active:
            while pending and len(active)<workers:
                chain=pending.pop(0)
                log=open(root/f'chain_{chain:03d}_iteration_{iteration:03d}_{time.time_ns()}.log','w')
                p=subprocess.Popen(['Rscript',script,'--worker',args.run_id,str(chain),str(iteration)],stdout=log,stderr=subprocess.STDOUT)
                active.append((p,log,chain))
            m=mem();rss=0
            for p,_,_ in active:
                try:
                    for line in pathlib.Path(f'/proc/{p.pid}/status').read_text().splitlines():
                        if line.startswith('VmRSS:'):rss+=int(line.split()[1])
                except FileNotFoundError:pass
            samples.append(dict(seconds=time.monotonic()-begin,iteration=iteration,rss_kib=rss,available_kib=m['MemAvailable'],swap_free_kib=m['SwapFree']))
            if shutil.disk_usage(root).free<2*1024**3:raise RuntimeError('Runtime disk guard: less than 2 GiB free.')
            if m['MemAvailable']<1024**2:raise RuntimeError('Runtime memory guard: available RAM below 1 GiB.')
            remaining=[]
            for p,log,chain in active:
                result=p.poll()
                if result is None:remaining.append((p,log,chain))
                else:
                    log.close()
                    if result:raise RuntimeError(f'Chain {chain} failed; inspect its worker log.')
            active=remaining
            time.sleep(.2)
        print(f'All {chains} chains checkpointed at iteration {iteration}.',flush=True)
    marker=root/f'review_endpoint_{endpoint:03d}.csv'
    if not marker.exists():
        subprocess.run(['Rscript',script,'--export',args.run_id,str(endpoint)],check=True)
        with marker.open('x',newline='') as f:
            w=csv.writer(f);w.writerow(['endpoint','status']);w.writerow([endpoint,'awaiting_diagnostic_review'])
    status='awaiting_diagnostic_review'
finally:
    for p,log,_ in active:
        if p.poll() is None:p.terminate()
    for p,log,_ in active:
        p.wait();log.close()
    if samples:
        with (root/f'resource_samples_{time.time_ns()}.csv').open('x',newline='') as f:
            w=csv.DictWriter(f,fieldnames=samples[0].keys());w.writeheader();w.writerows(samples)
    lock.rmdir()
print(f'Stopped at {endpoint}: {status}. No Cox models or pooling executed.',flush=True)
