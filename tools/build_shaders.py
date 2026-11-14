"""Build sample shaders with JaiLib's parser and SDL_shadercross/DXC.

All intermediate files stay in this repository's build directory.
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT.parent / "JaiLib"


def run(args):
    result = subprocess.run(list(map(str, args)), cwd=ROOT, capture_output=True,
                            text=True, encoding="utf-8", errors="replace", timeout=120)
    if result.returncode or "error[" in result.stdout or "error:" in result.stderr:
        raise RuntimeError(result.stdout + result.stderr)


def build(source):
    source = source.resolve()
    work = ROOT / "build/shaders"
    work.mkdir(parents=True, exist_ok=True)
    extractor_source = work / "extract.jai"
    shutil.copy2(LIB / "tools/shaders/main.jai", extractor_source)
    extractor = work / "extract.exe"
    run(["jacket", "build", "-exe", extractor.with_suffix(""), extractor_source])
    cross = shutil.which("shadercross")
    dxc = shutil.which("dxc")
    if not cross or not dxc:
        raise RuntimeError("shadercross and dxc must be on PATH")
    with tempfile.TemporaryDirectory(dir=work) as scratch:
        temp = Path(scratch)
        shutil.copytree(LIB / "kit/rendering/shader/lang/include/olib", temp / "olib")
        products = []
        jobs = list(source.glob("*.hlsl"))
        for path in source.glob("*.oshader"):
            extracted = temp / path.stem
            extracted.mkdir()
            run([extractor, path, extracted])
            for hlsl in extracted.glob("*.hlsl"):
                destination = temp / hlsl.name
                shutil.copy2(hlsl, destination)
                jobs.append(destination)
            products.extend(extracted.glob("*.shader.json"))
        for path in jobs:
            for stage in (["vertex"] if path.stem.endswith(".instanced") else ["vertex", "fragment"]):
                base = temp / (path.stem + "." + stage)
                spv, dxil, msl = [Path(str(base) + "." + suffix) for suffix in ("spv", "dxil", "msl")]
                run([cross, path, "-s", "HLSL", "-d", "SPIRV", "-t", stage,
                     "-e", stage + "_main", "-I", source, "-o", spv])
                run([dxc, path, "-T", "vs_6_0" if stage == "vertex" else "ps_6_0",
                     "-E", stage + "_main", "-HV", "2021", "-O3", "-Ges",
                     "-I", source, "-I", temp, "-Fo", dxil])
                run([cross, spv, "-s", "SPIRV", "-d", "MSL", "-t", stage,
                     "-e", stage + "_main", "-o", msl])
                products.extend([spv, dxil, msl])
        output = source / "Compiled"
        output.mkdir(exist_ok=True)
        for path in products:
            shutil.copy2(path, output / path.name)
        digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
        sources = {path.name: digest(path) for path in sorted(source.iterdir())
                   if path.suffix in (".hlsl", ".hlsli", ".oshader")}
        sources.update({"@include/olib/" + path.name: digest(path)
                        for path in sorted((temp / "olib").glob("*")) if path.is_file()})
        sources["@tool/build_shaders.py"] = digest(Path(__file__))
        sources["@tool/main.jai"] = digest(extractor_source)
        manifest = {"policy": "jailib-sample-shaders-1:vertex_main,fragment_main;spv;dxil=direct;msl",
                    "dxil": "direct", "sources": sources,
                    "tools": {Path(path).name: digest(Path(path)) for path in (cross, dxc)},
                    "outputs": {path.name: digest(path) for path in sorted(products)}}
        (output / "jailib-sources.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        print(f"Built {len(products)} shader products: {source}", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    build(parser.parse_args().directory)
