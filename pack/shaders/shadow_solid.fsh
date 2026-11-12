#version 330 compatibility

// Shadow map caster pass for solid terrain: depth only. No texture fetch and
// no discard, so the GPU takes its depth-only fast path for most of the map.

void main() {
}
