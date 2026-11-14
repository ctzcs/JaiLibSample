"""Build and exercise every sample, including behavior and GPU regressions.

Network probes require permission for local UDP/ENet sockets. No Internet access.
"""
from pathlib import Path
import argparse
import subprocess
import time
import re
import json
import os
import shutil
from stage_runtime import stage_runtime

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build/check-samples"
LIB = ROOT.parent / "JaiLib"
SAMPLES = sorted(p.parent.name for p in (ROOT / 'src').glob('*/main.jai'))
RESULTS = []

def record(name, status, detail=''):
    RESULTS.append(dict(name=name,status=status,detail=detail))
    (BUILD / 'results.json').write_text(json.dumps(RESULTS,indent=2),encoding='utf-8')

def invoke(command, name, timeout=90):
    result = subprocess.run(command, cwd=ROOT, capture_output=True, timeout=timeout)
    output = (result.stdout + result.stderr).decode("utf-8", errors="replace")
    (BUILD / f"{name}.log").write_text(output, encoding="utf-8")
    if result.returncode or re.search(r"error\[|\berror:|error LNK|assertion failed|runtime error|access violation|SMOKE FAIL", output, re.I):
        raise RuntimeError(f"{name} failed; see {BUILD / (name+'.log')}\n{output[-2500:]}")
    return output

def run(sample, *args):
    label = re.sub(r"[^a-zA-Z0-9_.-]", "_", sample + "-" + "-".join(args))
    screenshots=ROOT/'library/screenshots'
    before={p:p.stat().st_mtime_ns for p in screenshots.rglob('*.png')}
    output = invoke([str(BUILD / f"{sample}.exe"), *args], label)
    if "PASS" not in output:
        raise RuntimeError(f"{label}: no success marker")
    print(f"PASS {sample} {' '.join(args)}", flush=True)
    saved=[]
    for path in screenshots.rglob('*.png'):
        if before.get(path)==path.stat().st_mtime_ns: continue
        destination=BUILD/'screenshots'/label/path.relative_to(screenshots)
        destination.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(path,destination)
        saved.append(str(destination.relative_to(BUILD)))
    record(label,'passed',saved)

def network_pair(sample, backend, port):
    log = BUILD / f"{sample}-{backend}-server.log"
    with log.open("wb") as stream:
        server = subprocess.Popen([str(BUILD / f"{sample}.exe"), "server", f"port={port}", backend, "frames=10000"], cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        try:
            deadline = time.monotonic() + 15
            while "on port" not in log.read_text(encoding="utf-8", errors="replace"):
                if server.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError(f"{sample} server failed to start: {log.read_text(errors='replace')}")
                time.sleep(.05)
            run(sample, "client", "127.0.0.1", str(port), backend, "smoke")
            if "connected" not in log.read_text(errors="replace"):
                raise RuntimeError("Server did not accept the independent client")
            print(f"PASS {sample} {backend} independent processes", flush=True)
        finally:
            if server.poll() is None:
                server.terminate()
            server.wait(timeout=10)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--network", action="store_true", help="also run UDP/ENet hosts and independent client/server processes")
    parser.add_argument("--skip-build", action="store_true")
    parser.add_argument("--only", default='', help='comma-separated sample names or fragments')
    parser.add_argument("--baseline", action="store_true", help='only the default case for each selected sample')
    args = parser.parse_args()
    BUILD.mkdir(parents=True,exist_ok=True)
    stage_runtime(BUILD)
    selected=[s for s in SAMPLES+['render_regression','notes_regression','perf_overlay_regression','image_bytes_regression','hdr_targets_regression']
              if not args.only or any(part in s for part in args.only.split(','))]
    if not args.skip_build:
        for sample in selected:
            source = f"tools/{sample}.jai" if sample.endswith("regression") else f"src/{sample}/main.jai"
            invoke([os.environ.get('JAIC','jaic'), '-no_dce', '-import_dir', str(LIB),
                    '-exe', str(BUILD / sample), source], sample + "-build")
            print(f"BUILT {sample}", flush=True)
            record(sample+'-build','passed')
    baseline={name:[] for name in ['app_composition','backend','calc','feature','spatial',
                                  'render_regression','notes_regression','perf_overlay_regression','image_bytes_regression','hdr_targets_regression']}
    baseline.update({name:['shot'] for name in ['basic','batcher','gizmo2d','material2d']})
    baseline.update(hotreload=['selftest'],net_arena=['shot','menu'],net_fps=['tracer-test'])
    if 'meshview' in selected and not args.baseline:
        invoke([os.environ.get('JAIC','jaic'),'-no_dce','-import_dir',str(LIB),
                '-exe',str(BUILD/'mesh_fixture'),'tools/mesh_fixture.jai'],'mesh-fixture-build')
        run('mesh_fixture')
    variants={
        'gizmo2d':[['shot','scaled']],
        'material2d':[['shot','swarm'],['shot','scaled'],['shot','auto']],
        'material3d':[['shot','views','samples=4'],['shot','swarm','count=20000'],
                      ['shot','models','count=512'],['shot','models','each','count=128'],['shot','ungrouped','nooutline']],
        'meshview':[['shot','wire','xray'],['shot','solid'],['smoke','build/meshview-offset.dasset']],
        'stylized3d':[['shot','flat','noao','noshadow']],
        'shader_lab':[['shot'],['smoke','scaled','narrow'],['smoke','cube']],
        'scene_notes':[['smoke','narrow','scaled']],
        'tween_preview':[['smoke','-case=card/spring','-target=scene/card-42']],
        'book_ui':[['shot','turn'],['shot','back']],
    }
    for name in ['cjk_ui','ui_motion','game_ui','book_ui','ui_gallery']:
        variants.setdefault(name,[]).append(['smoke','narrow','scaled'])
    for name in ['net_arena','net_fps']:
        variants[name]=[['shot','menu','narrow','scaled']]
    variants["net_arena"].extend([["shot","menu","join"],["view-test"],["view-test","narrow","scaled"]])
    for sample in selected:
        run(sample,*baseline.get(sample,['smoke']))
        if not args.baseline:
            for case in variants.get(sample,[]): run(sample,*case)
    if args.network:
        for i, sample in enumerate(["net_arena", "net_fps"]):
            if sample not in selected: continue
            run(sample, "menu-test", "narrow", "scaled", f"port={18200+i}")
            for j, backend in enumerate(["udp", "enet"]):
                port = 18000 + i * 10 + j
                run(sample, "smoke", backend, f"port={port}", "lag=80")
                if sample == "net_fps":
                    run(sample,"smoke",backend,f"port={port+200}","bots=0","voicetest","voice-panel")
                network_pair(sample, backend, port + 100)
                record(f'{sample}-{backend}-independent','passed')
    else:
        for sample in ['net_arena','net_fps']:
            if sample in selected: record(sample+'-sockets','skipped','Enable --network for UDP/ENet local sockets')
    print("All requested sample checks passed.")

if __name__ == "__main__":
    try: main()
    except Exception as error:
        if BUILD.exists(): record('suite','failed',str(error))
        raise
