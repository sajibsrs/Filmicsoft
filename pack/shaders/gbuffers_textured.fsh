#version 330 compatibility

// Particles (and other unlit textured geometry Iris routes here). Drawn the
// vanilla way: texture * vertex colour * lightmap. The one change: rain
// splashes on the ground are saturated blue in vanilla, so strongly blue texels
// take the shared rain colour (lib/rain.glsl) and match the falling streaks.
// Water drips and bubbles are the same blue and get the same treatment.

/* RENDERTARGETS: 0 */

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float alphaTestRef;
uniform vec3 fogColor;
uniform float rainStrength;

#include "/lib/rain.glsl"

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 c = texture(gtexture, texcoord) * glcolor;
    if (c.a < alphaTestRef) discard;
    // Blue well above both red and green: vanilla's water-drop blue.
    // Cyan (soul fire, sculk, glow squid) has green close to blue, so it fails
    // this test. Only while it rains: splashes exist only then, and outside
    // rain every other blue particle keeps its vanilla colour.
    float blue = smoothstep(0.15, 0.35, c.b - max(c.r, c.g)) * step(0.001, rainStrength);
    if (blue > 0.0) c.rgb = mix(c.rgb, rainColor(c.rgb), blue);
    else c.rgb *= texture(lightmap, lmcoord).rgb;
    outColor = c;
}
