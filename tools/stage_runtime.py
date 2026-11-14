"""Copy JaiLib's Windows runtime DLLs beside sample executables."""
from pathlib import Path
import argparse
import shutil
import filecmp

ROOT = Path(__file__).resolve().parents[1]

def stage_runtime(destination):
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    for path in ['foster/internal/native/windows/SDL3.dll',
                 'foster/internal/third_party/stb/stb_impl.dll', 'thirdparty/imgui/ImGui.dll']:
        source = ROOT.parent / 'JaiLib' / path
        if not source.is_file():
            raise RuntimeError(f'Missing runtime: {source}')
        target = destination / source.name
        # An unchanged DLL may be loaded by another running sample.
        if target.is_file() and filecmp.cmp(source, target, shallow=False):
            continue
        shutil.copy2(source, target)
    for source in (ROOT / 'assets/voice').glob('*'):
        if source.name not in ('opus.dll', 'LICENSE.opus.txt'):
            continue
        target = destination / source.name
        if not target.is_file() or not filecmp.cmp(source, target, shallow=False):
            shutil.copy2(source, target)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination', nargs='?', type=Path, default=ROOT / 'build')
    args = parser.parse_args()
    stage_runtime(args.destination)
    print(f'Runtime staged in {args.destination.resolve()}')
