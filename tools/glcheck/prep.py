"""Prepare Filmicsoft fragment shaders for the local compile check.

Mimics what Iris does before compiling:
  * expands `#include "/path"`
  * substitutes option values as plain TEXT (so `-OPTION` with a negative
    value becomes `--0.10`, exactly as it would inside Iris)
  * turns `#version 330 compatibility` into core, which macOS requires
  * adds the built-in macros Iris defines (MC_RENDER_STAGE_*)
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


# Values don't matter for a compile check, only that the names exist.
IRIS_MACROS = '\n'.join('#define MC_RENDER_STAGE_%s %d' % (n, i) for i, n in enumerate(
    ['NONE', 'SKY', 'SUNSET', 'CUSTOM_SKY', 'SUN', 'MOON', 'STARS', 'VOID'])) + '\n'

for f in sorted(root.glob('*.fsh')):
    t = substitute_options(expand(f.read_text()))
    t = t.replace('#version 330 compatibility', '#version 410 core\n' + IRIS_MACROS)
    (out / f.name).write_text(t)


def vsh_to_core(t):
    """Fullscreen-pass vertex shaders -> core GLSL driven by gl_VertexID."""
    t = t.replace('#version 330 compatibility', '#version 410 core')
    t = t.replace('ftransform()', 'vec4(fsq * 2.0 - 1.0, 0.0, 1.0)')
    t = t.replace('gl_MultiTexCoord0.xy', 'fsq')
    return re.sub(r'void main\(\)\s*\{',
                  'void main() {\n    vec2 fsq = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));',
                  t, count=1)


for f in sorted(root.glob('*.vsh')):
    if f.name.startswith(('gbuffers_', 'shadow')):
        continue          # real geometry; checked in-game
    t = substitute_options(expand(f.read_text()))
    (out / f.name).write_text(vsh_to_core(t))
