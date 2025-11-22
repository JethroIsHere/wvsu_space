#!/usr/bin/env python3
"""
fix_nested_imports.py

Replace occurrences of duplicated nested feature folders in package imports:
- features/admin/admin -> features/admin
- features/gratitude_wall/gratitude_wall -> features/gratitude_wall
- features/vibe_rooms/vibe_rooms -> features/vibe_rooms

Creates a .bak backup for each modified file.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / 'lib'
patterns = [
    (r"features/admin/admin", "features/admin"),
    (r"features/gratitude_wall/gratitude_wall", "features/gratitude_wall"),
    (r"features/vibe_rooms/vibe_rooms", "features/vibe_rooms"),
]

modified = []
for p in LIB.rglob('*.dart'):
    text = p.read_text(encoding='utf-8')
    new = text
    for pat, repl in patterns:
        new = re.sub(pat, repl, new)
    if new != text:
        bak = p.with_suffix(p.suffix + '.bak')
        p.write_text(new, encoding='utf-8')
        bak.write_text(text, encoding='utf-8')
        modified.append(str(p.relative_to(ROOT)))

print(f"Modified {len(modified)} files:")
for m in modified:
    print(' -', m)
print('Done. Review changes and run dart analyze/flutter test.')
