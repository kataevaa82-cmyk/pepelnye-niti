"""Check official Godot downloads against the release SHA512-SUMS.txt."""
import hashlib
from pathlib import Path
import sys

sums = {}
for line in Path('SHA512-SUMS.txt').read_text().splitlines():
    fields = line.split(maxsplit=1)
    if len(fields) == 2:
        sums[fields[1].lstrip('*').removeprefix('./')] = fields[0].lower()
for argument in sys.argv[1:]:
    path = Path(argument)
    expected = sums.get(path.name)
    if expected is None:
        raise SystemExit(f'No SHA512 entry for {path.name}')
    with path.open('rb') as content:
        actual = hashlib.file_digest(content, 'sha512').hexdigest()
    if actual != expected:
        raise SystemExit(f'Checksum mismatch: {path.name}')
    print(f'Verified {path.name}')
