#!/usr/bin/env python3
"""Strict host-suite runner. Missing tools/skips are INCOMPLETE, never full PASS."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]


def command_output(command):
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    return result.stdout.strip() if result.returncode == 0 else 'unavailable'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path, help='Optional repository-local JSON evidence file')
    args = parser.parse_args()
    target = None
    if args.report:
        target = (ROOT/args.report).resolve()
        if not target.is_relative_to(ROOT) or target.suffix != '.json':
            parser.error('--report must be a repository-local .json file')
    tools = {name: shutil.which(name) for name in ('g++','cpp')}
    environment = dict(os.environ, PYTHONDONTWRITEBYTECODE='1')
    result = subprocess.run([sys.executable,'-B','-m','unittest','discover','-s','Tests','-p','test_*.py','-v'],
                            cwd=ROOT, env=environment, text=True, capture_output=True)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    run = re.search(r'Ran (\d+) tests?', result.stderr)
    skips = re.search(r'\bskipped=(\d+)', result.stderr)
    skipped = int(skips.group(1)) if skips else 0
    missing = [name for name,path in tools.items() if path is None]
    incomplete = bool(skipped or missing or run is None or int(run.group(1)) == 0)
    status = 'FAIL' if result.returncode else ('INCOMPLETE' if incomplete else 'PASS')
    hashes = {}
    for directory in ('Include','Experts','Scripts','Tests','Presets'):
        for path in sorted((ROOT/directory).rglob('*')):
            if path.is_file() and path.suffix in ('.mqh','.mq5','.py','.set','.csv'):
                hashes[path.relative_to(ROOT).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    report = {
        'scope':'host checks only; not MQL compilation, terminal integration or trading approval',
        'status':status, 'utc_clock':datetime.now(timezone.utc).isoformat(),
        'branch':command_output(['git','branch','--show-current']),
        'head':command_output(['git','rev-parse','HEAD']),
        'dirty_worktree':bool(command_output(['git','status','--porcelain'])),
        'python':platform.python_version(), 'platform':platform.system(),
        'tools':{name:command_output([path,'--version']).splitlines()[0] if path else 'missing' for name,path in tools.items()},
        'tests_run':int(run.group(1)) if run else None, 'skipped':skipped,
        'missing_tools':missing, 'suite_returncode':result.returncode,
        'mql_compilation':'NOT RUN', 'terminal_tests':'NOT RUN', 'broker_execution':'BLOCKED / NOT RUN',
        'sha256':hashes,
    }
    if target:
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
        print('Evidence:',target.relative_to(ROOT))
    print('Host validation:',status,'(not a trading release)')
    return 1 if result.returncode else (2 if incomplete else 0)


if __name__ == '__main__':
    raise SystemExit(main())
