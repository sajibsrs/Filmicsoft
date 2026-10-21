#version 330 compatibility

// Rain and snow in vanilla colour, but much more see-through: drawn unshaded
// at full opacity, vanilla's saturated streaks tint the whole screen.

/* RENDERTARGETS: 0 */

uniform sampler2D gtexture;

in vec2 texcoord;
in vec4 glcolor;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 c = texture(gtexture, texcoord) * glcolor;
    if (c.a < 0.01) discard;
    outColor = vec4(c.rgb, c.a * 0.55);
}
