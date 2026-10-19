#version 330 compatibility

// Shadow map caster pass: depth only, with a cheap cutout test so leaves,
// grass and fences cast their real shape instead of a full block.

uniform sampler2D gtexture;

in vec2 texcoord;

void main() {
    if (texture(gtexture, texcoord).a < 0.5) discard;
}
