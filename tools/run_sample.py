"""Build a sample, stage its paired DLLs, then run it (also used by Zed tasks)."""
from pathlib import Path
import argparse
import os
import re
import subprocess
import sys
from stage_runtime import stage_runtime

ROOT = Path(__file__).resolve().parents[1]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('sample', choices=sorted(p.parent.name for p in (ROOT/'src').glob('*/main.jai')))
    parser.add_argument('args', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    output = ROOT/'build'/args.sample
    output.parent.mkdir(exist_ok=True)
    result = subprocess.run([os.environ.get('JAIC','jaic'),'-no_dce','-import_dir',str(ROOT.parent/'JaiLib'),
        '-exe',str(output),str(ROOT/'src'/args.sample/'main.jai')],cwd=ROOT,capture_output=True)
    text = (result.stdout+result.stderr).decode('utf-8',errors='replace')
    if result.returncode or re.search(r'error\[|\berror:|error LNK|assertion failed',text,re.I):
        print(text)
        return result.returncode or 1
    stage_runtime(output.parent)
    return subprocess.call([str(output.with_suffix('.exe')),*args.args],cwd=ROOT)

if __name__ == '__main__':
    sys.exit(main())
