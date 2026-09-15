"""Static packaging checks only. This is NOT a GDScript compiler or playtest."""
from pathlib import Path
import ast
import re
import sys
import wave
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
errors = []


def check(condition, message):
    if not condition:
        errors.append(message)


def main():
    files = [p for p in ROOT.rglob('*') if p.is_file() and
             not any(x in {'.godot', '.git', '.tools', 'build', 'dist', '__pycache__'}
                     for x in p.relative_to(ROOT).parts)]
    for path in files:
        if path.suffix in {'.gd', '.tscn', '.godot', '.cfg'}:
            text = path.read_text(encoding='utf-8')
            for resource in re.findall(r'res://([^"\s]+)', text):
                check((ROOT / resource).exists(), f'{path.name}: missing {resource}')
            check('\r' not in text, f'{path.name}: inconsistent newlines')
        if path.suffix == '.py':
            ast.parse(path.read_text(encoding='utf-8'), filename=str(path))
    project = (ROOT / 'project.godot').read_text()
    preset = (ROOT / 'export_presets.cfg').read_text()
    check('gl_compatibility' in project, 'Compatibility renderer is required')
    check('variant/thread_support=false' in preset, 'Web must be single-threaded')
    check('progressive_web_app/enabled=false' in preset, 'Do not ship a service worker')
    check('web/shell.html' in preset, 'SDK HTML shell is missing')
    check(not (ROOT / 'web' / 'sdk.js').exists(), 'Do not redistribute a copied Yandex SDK')
    shell = (ROOT / 'web' / 'shell.html').read_text()
    for token in ['$GODOT_URL', '$GODOT_CONFIG', '$GODOT_HEAD_INCLUDE']:
        check(token in shell, f'Missing HTML placeholder {token}')
    for name in ['hit', 'pulse', 'core', 'workshop']:
        path = ROOT / 'assets' / 'audio' / f'{name}.wav'
        check(path.exists(), f'Missing audio: {name}; run tools/make_audio.py')
        if path.exists():
            with wave.open(str(path)) as sound:
                check(sound.getnchannels() == 1 and sound.getsampwidth() == 2, f'Unexpected PCM format: {name}')
    ET.parse(ROOT / 'assets' / 'icon.svg')
    check(sum(p.stat().st_size for p in files) < 5_000_000, 'Source package unexpectedly large')
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        raise SystemExit(1)
    print(f'PASS: source/resource paths, export flags, Python syntax, SVG, 4 PCM assets ({len(files)} files).')
    print('NOT RUN by this check: GDScript compilation, Godot execution, rendering, WebGL, real Yandex SDK.')


if __name__ == '__main__':
    main()
