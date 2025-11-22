#!/usr/bin/env python3
"""
fix_imports.py

Scans `lib/` for Dart files and rewrites local-relative imports to package imports
`package:wvsu_space/<path>` so that moves inside `lib/` don't break imports.

WARNING: This is a best-effort script. Review changes before committing.
"""
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / 'lib'
PKG = 'wvsu_space'

IMPORT_RE = re.compile(r"^(\s*import\s+)(['\"])([^'\"]+)(['\"]\s*;)" )

# Build map of existing lib files
lib_files = {}
for p in LIB.rglob('*.dart'):
    rel = p.relative_to(LIB).as_posix()
    lib_files[rel] = p

print(f"Found {len(lib_files)} Dart files under lib/")

changed_files = []

for src in LIB.rglob('*.dart'):
    text = src.read_text(encoding='utf-8')
    lines = text.splitlines()
    changed = False
    new_lines = []
    src_dir = src.parent
    for line in lines:
        m = IMPORT_RE.match(line)
        if not m:
            new_lines.append(line)
            continue
        prefix, q1, path_str, q2semi = m.groups()
        path = path_str.strip()
        # Skip absolute imports
        if path.startswith('dart:') or path.startswith('package:'):
            new_lines.append(line)
            continue
        # Skip urls
        if '://' in path:
            new_lines.append(line)
            continue
        resolved = None
        # If path starts with 'lib/' or '/': treat as lib-relative
        if path.startswith('lib/'):
            candidate = LIB / path[len('lib/'):]
            if candidate.exists():
                resolved = candidate
        else:
            # Resolve relative to file
            candidate = (src_dir / path).resolve()
            if candidate.exists() and str(candidate).startswith(str(LIB)):
                resolved = candidate
            else:
                # Try as lib-relative (e.g., 'widgets/foo.dart')
                candidate = LIB / path
                if candidate.exists():
                    resolved = candidate
        if resolved is None:
            # fallback: try to find a file with same basename
            basename = os.path.basename(path)
            matches = [p for rel,p in lib_files.items() if rel.endswith('/' + basename) or rel == basename]
            if len(matches) == 1:
                resolved = matches[0]
            elif len(matches) > 1:
                # prefer same folder name
                for cand in matches:
                    if cand.parent == src_dir:
                        resolved = cand
                        break
                if resolved is None:
                    resolved = matches[0]
        if resolved is None:
            new_lines.append(line)
            continue
        rel_from_lib = resolved.relative_to(LIB).as_posix()
        new_import = f"{prefix}{q1}package:{PKG}/{rel_from_lib}{q2semi}"
        if new_import != line:
            new_lines.append(new_import)
            changed = True
        else:
            new_lines.append(line)
    if changed:
        backup = src.with_suffix(src.suffix + '.bak')
        src.replace(backup)
        src.write_text('\n'.join(new_lines) + '\n', encoding='utf-8')
        changed_files.append(str(src.relative_to(ROOT)))

print(f"Updated imports in {len(changed_files)} files:")
for f in changed_files:
    print(' -', f)
print('Done. Review changes and run `flutter analyze`/`flutter test`.')
