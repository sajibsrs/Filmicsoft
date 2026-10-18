"""Prepare Filmicsoft fragment shaders for the local compile check.

Mimics what Iris does before compiling:
  * expands `#include "/path"`
  * substitutes option values as plain TEXT (so `-OPTION` with a negative
    value becomes `--0.10`, exactly as it would inside Iris)
  * turns `#version 330 compatibility` into core, which macOS requires
"""
import re
import sys
import pathlib

root = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
out.mkdir(exist_ok=True)

OPTION = re.compile(r'^#define\s+([A-Za-z_]\w*)\s+(\S+)\s*//\s*\[', re.M)


def expand(text):
    return re.sub(r'#include\s+"/([^"]+)"', lambda m: (root / m.group(1)).read_text(), text)


def substitute_options(text):
    values = {m.group(1): m.group(2) for m in OPTION.finditer(text)}
    text = OPTION.sub(lambda m: '// option ' + m.group(1) + ' =', text)
    for name, value in values.items():
        text = re.sub(r'\b' + re.escape(name) + r'\b', value, text)
    return text


for f in sorted(root.glob('*.fsh')):
    t = substitute_options(expand(f.read_text()))
    t = t.replace('#version 330 compatibility', '#version 410 core')
    (out / f.name).write_text(t)
