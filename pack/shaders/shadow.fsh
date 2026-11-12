#version 330 compatibility

// Shadow map caster pass for cutout terrain and entities: depth only, with a
// cheap cutout test so leaves, grass and fences cast their real shape instead
// of a full block. Solid terrain goes through shadow_solid (no fetch, no discard).

uniform sampler2D gtexture;

in vec2 texcoord;
flat in int solidCutout;

void main() {
    if (solidCutout == 0 && texture(gtexture, texcoord).a < 0.5) discard;
}
