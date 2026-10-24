#!/usr/bin/env python3
"""Render repository prose in English, audit equations, and build a local HTML index.

Run from any directory. This does not execute analysis code or alter old manifests.
HTML stays local under output/documentation_preview/. Audit CSVs are aggregate only.
"""
import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from urllib.parse import unquote, urlsplit
from bs4 import BeautifulSoup

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / 'reports/documentation_quality_v1'
BUILD = ROOT / 'output/documentation_preview'


def documents():
    return sorted([ROOT / 'README.md', *ROOT.glob('docs/**/*.md'),
                   *ROOT.glob('reports/**/*.md'), *ROOT.glob('protocol/**/*.md'),
                   *ROOT.glob('protocol/**/*.qmd')])


def save_csv(path, rows):
    with path.open('w', newline='') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', type=Path, help='Optional pre-edit path/MD5 JSON')
    parser.add_argument('--check-existing', action='store_true', help='Audit an existing complete render')
    args = parser.parse_args()
    env = dict(os.environ, XDG_CACHE_HOME='/tmp/nhanes-docs-quarto-cache',
               DENO_DIR='/tmp/nhanes-docs-deno-cache')
    rows, sources, language, changed = [], [], [], []
    baseline = json.loads(args.baseline.read_text()) if args.baseline else {}
    docs = documents()
    prior_file = AUDIT/'source_manifest.csv'
    prior = {r['path']:r['md5'] for r in csv.DictReader(prior_file.open())} if prior_file.exists() else {}
    for path in docs:
        rel = path.relative_to(ROOT)
        text = path.read_text()
        # These signals target untranslated prose, not names, filenames, or references.
        prose = re.sub(r'`[^`]*`|\]\([^)]*\)', '', text)
        signals = re.findall(r'\b(?:imputación|metodológico|sensibilidad|verificaciones|'
                             r'fallecimientos|enmienda|desenlace|covariables|Qué|Por qué)\b', prose)
        language.append(dict(path=str(rel), spanish_prose_signals=len(signals)))
        target_dir = BUILD / rel.parent
        target_dir.mkdir(parents=True, exist_ok=True)
        ignore = path.parent/'.gitignore'
        ignore_existed = ignore.exists()
        cmd = ['quarto', 'render', str(path), '--to', 'html', '--output-dir',
               str(target_dir), '--metadata-file', str(AUDIT / 'render.yml')]
        html = target_dir / (path.stem + '.html')
        logfile = target_dir / (path.stem + '.render.log')
        if (args.check_existing and html.exists() and logfile.exists() and
            prior.get(str(rel)) == hashlib.md5(path.read_bytes()).hexdigest()):
            run = subprocess.CompletedProcess(cmd, 0)
            log = logfile.read_text()
        else:
            run = subprocess.run(cmd, cwd=ROOT, env=env, text=True, capture_output=True)
            log = run.stdout + run.stderr
            logfile.write_text(log)
            if not ignore_existed and ignore.exists() and ignore.read_text()=='/.quarto/\n**/*.quarto_ipynb\n':
                ignore.unlink()
        errors = bool(re.search(r'Could not convert|Could not fetch|\bWARNING\b|\bERROR\b', log, re.I))
        if run.returncode or not html.exists():
            raise RuntimeError(f'Render failed for {rel}: {log}')
        soup = BeautifulSoup(html.read_text(), 'html.parser')
        body = soup.select_one('main') or soup.body
        # Pandoc MathML emits both semantic MathML and a hidden original-TeX annotation.
        # TeX annotations are expected; fallback TeX in the visible math wrapper is not.
        ast_run = subprocess.run(['quarto', 'pandoc', str(path), '--from=markdown+tex_math_dollars', '--to=json'], cwd=ROOT, text=True, capture_output=True, check=True)
        def count_math(node):
            if isinstance(node, dict):
                return int(node.get('t') == 'Math') + sum(count_math(x) for x in node.values())
            if isinstance(node, list):
                return sum(count_math(x) for x in node)
            return 0
        expected = count_math(json.loads(ast_run.stdout)['blocks'])
        maths = body.find_all('math')
        fallback = sum(not x.find('math') for x in body.select('span.math'))
        fallback += abs(expected-len(maths))
        # Native MathML has no span.math wrapper in current Pandoc. Wrap only
        # display equations to allow local scrolling without clipping on mobile.
        for equation in body.select('math[display=block]'):
            if 'math-display-scroll' not in equation.parent.get('class', []):
                equation.wrap(soup.new_tag('span', attrs={'class':'math-display-scroll'}))
        style = soup.find('style', id='nhanes-math-layout')
        if not style:
            style = soup.new_tag('style', id='nhanes-math-layout')
            soup.head.append(style)
        style.string = '.math-display-scroll{display:block;max-width:100%;overflow-x:auto;overflow-y:hidden;padding:.6em 0 .8em}.math-display-scroll math{max-width:none}'
        merrors = len(body.find_all('merror'))
        raw_fences = len(body.select('code.language-math, pre.math'))
        for a in soup.find_all('a', href=True):
            url = urlsplit(a['href'])
            if url.scheme or url.netloc or not url.path:
                continue
            p = Path(unquote(url.path))
            if p.suffix in ('.md', '.qmd'):
                destination = (path.parent / p).resolve()
                if destination in docs:
                    a['href'] = str(p.with_suffix('.html')) + ('#'+url.fragment if url.fragment else '')
            elif p.suffix != '.html':
                destination = (path.parent / p).resolve()
                if destination.is_file():
                    a['href'] = destination.as_uri() + ('#'+url.fragment if url.fragment else '')
        html.write_text(str(soup))
        digest = hashlib.md5(path.read_bytes()).hexdigest()
        sources.append(dict(path=str(rel), md5=digest))
        if str(rel) in baseline and baseline[str(rel)] != digest:
            changed.append(dict(path=str(rel), original_md5=baseline[str(rel)], revised_md5=digest,
                                change='English translation or equation formatting; no model rerun'))
        rows.append(dict(path=str(rel), equations=expected, mathml=len(maths),
                         unconverted_equations=fallback, math_errors=merrors,
                         raw_math_code_blocks=raw_fences, render_warnings=int(errors),
                         html_language=soup.html.get('lang',''),
                         passed=(not signals and not fallback and not merrors and
                                 not raw_fences and not errors and soup.html.get('lang')=='en')))
        print(f'{rel}: {len(maths)} equations, passed={rows[-1]["passed"]}', flush=True)
    AUDIT.mkdir(exist_ok=True)
    save_csv(AUDIT/'render_validation.csv', rows)
    save_csv(AUDIT/'source_manifest.csv', sources)
    save_csv(AUDIT/'language_scan.csv', language)
    if changed:
        save_csv(AUDIT/'documentation_changes.csv', changed)
    index = ['<!doctype html><html lang="en"><meta charset="utf-8">',
             '<title>NHANES documentation</title><h1>NHANES documentation</h1>',
             '<p>English HTML reading copies; equations use native MathML.</p><ul>']
    for row in rows:
        target = str(Path(row['path']).with_suffix('.html'))
        index.append(f'<li><a href="{target}">{row["path"]}</a></li>')
    index.append('</ul></html>')
    (BUILD/'index.html').write_text('\n'.join(index))
    if not all(row['passed'] for row in rows):
        raise SystemExit('Documentation checks failed; inspect render_validation.csv and logs.')
    print(f'PASS: {len(rows)} documents, {sum(r["equations"] for r in rows)} equations.')


if __name__ == '__main__':
    main()
