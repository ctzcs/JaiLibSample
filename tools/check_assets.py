"""Build and run samples that consume JaiLib built-in fonts (Windows/GPU)."""
from pathlib import Path
import subprocess, re, importlib.util, json
root=Path(__file__).resolve().parents[1]
lib=root.parent/'JaiLib'
out=root/'build'
# Fail before launching if demo text falls outside the shipped subset.
glyphs={g['unicode'] for g in json.loads((lib/'assets/fonts/msdf/ui.json').read_text(encoding='utf-8'))['glyphs']}
for line in (root/'src/cjk_ui/main.jai').read_text(encoding='utf-8').splitlines():
    if 'label(' in line or 'UI.ui_button(' in line:
        for literal in re.findall(r'"([^"]*)"',line):
            missing={ord(c) for c in literal if ord(c) not in glyphs}
            assert not missing, f'Missing CJK demo glyphs: {sorted(missing)}'

spec=importlib.util.spec_from_file_location('libcheck',lib/'tools/check/main.py')
check=importlib.util.module_from_spec(spec);spec.loader.exec_module(check)
check.stage_runtime(out)
def run(command,label,cwd=root):
    r=subprocess.run(list(map(str,command)),cwd=cwd,capture_output=True,timeout=90)
    text=(r.stdout+r.stderr).decode('utf-8',errors='replace')
    (out/('asset-'+label+'.log')).write_text(text,encoding='utf-8')
    if r.returncode or re.search(r'\berror\[|\berror:|error LNK|assertion failed|runtime error',text,re.I):
        raise RuntimeError(label+'\n'+text[-3500:])
    print('PASS',label,flush=True)
    return text
for name in ['cjk_ui','backend','gizmo2d','ui_motion','game_ui','book_ui','scene_notes','shader_lab','tween_preview']:
    run([check.compiler(),'-no_dce','-import_dir',lib,'-output_path',out,'-exe',name,root/f'src/{name}/main.jai'],name+'-build')
cases=[
    ('backend',[],out),
    ('cjk_ui',['smoke'],out),
    ('cjk_ui',['smoke','scaled','narrow'],root),
    ('gizmo2d',['shot'],root),
    ('ui_motion',['smoke'],root),
    ('game_ui',['smoke'],root),
    ('book_ui',['smoke'],root),
    ('scene_notes',['smoke'],root),
    ('shader_lab',['smoke'],root),
    ('tween_preview',['smoke'],root),
]
for name,args,cwd in cases:
    run([out/(name+'.exe'),*args],name+'-'+('-'.join(args) or 'run'),cwd)
