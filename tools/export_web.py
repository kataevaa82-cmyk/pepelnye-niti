"""Import, test, export and validate a single-threaded Godot Web build."""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
MAX_BYTES = 100_000_000  # Conservative project budget; verify platform limits again before release.


def godot_run(executable, *args, testing=False):
    env = os.environ.copy()
    if testing:
        env['ASH_TESTING'] = '1'
    result = subprocess.run([executable, '--headless', '--path', str(ROOT), *args],
                            cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=300, check=False)
    print(result.stdout)
    if result.returncode or re.search(r'SCRIPT ERROR:|Parse Error:|^ERROR:', result.stdout, re.M):
        raise SystemExit(f'Godot failed validation (exit {result.returncode}).')


def package(web_dir, output):
    required = ['index.html', 'index.js', 'index.wasm', 'index.pck', 'bridge.js', 'boot.js']
    for name in required:
        if not (web_dir / name).is_file():
            raise SystemExit(f'Missing exported file: {name}')
    html = (web_dir / 'index.html').read_text(encoding='utf-8')
    if '$GODOT_' in html:
        raise SystemExit('Unexpanded Godot HTML placeholders.')
    if (web_dir / 'index.wasm').read_bytes()[:4] != b'\0asm':
        raise SystemExit('Invalid WASM header.')
    files = sorted(path for path in web_dir.rglob('*') if path.is_file())
    total = sum(path.stat().st_size for path in files)
    if total > MAX_BYTES:
        raise SystemExit(f'Build is over the project size budget: {total} bytes.')
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in files:
            relative = path.relative_to(web_dir).as_posix()
            if not re.fullmatch(r'[A-Za-z0-9_./-]+', relative):
                raise SystemExit(f'Nonportable export filename: {relative}')
            archive.write(path, relative)
    with zipfile.ZipFile(output) as archive:
        if archive.testzip() is not None:
            raise SystemExit('ZIP validation failed.')
    print(f'Web build: {total / 1_000_000:.2f} MB unpacked; {output}')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
    args = parser.parse_args()
    executable = shutil.which(args.godot)
    if executable is None:
        raise SystemExit('Godot was not found. Install Godot 4.4.1 and its matching export templates, or use GitHub Actions.')
    web_dir = ROOT / 'build' / 'web'
    web_dir.mkdir(parents=True, exist_ok=True)
    if any(web_dir.iterdir()):
        raise SystemExit('build/web must be empty to avoid packaging stale files; archive or move the previous build first.')
    godot_run(executable, '--editor', '--import')
    godot_run(executable, '--script', 'res://tests/smoke.gd', testing=True)
    godot_run(executable, '--export-release', 'Web', str(web_dir / 'index.html'))
    for name in ['bridge.js', 'boot.js']:
        shutil.copy2(ROOT / 'web' / name, web_dir / name)
    package(web_dir, ROOT / 'dist' / 'pepelnye-niti-yandex.zip')


if __name__ == '__main__':
    main()
