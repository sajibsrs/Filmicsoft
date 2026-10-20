#version 330 compatibility

// Rain and snow. Without this program Iris draws vanilla's rain texture
// unshaded: saturated blue streaks at near-full opacity, which tint the whole
// screen blue. Here they take the shared rain colour (lib/rain.glsl, also used
// by the ground splashes) and are much more see-through. Snow stays white.

/* RENDERTARGETS: 0 */

uniform sampler2D gtexture;
uniform vec3 fogColor;

#include "/lib/rain.glsl"

in vec2 texcoord;
in vec4 glcolor;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 c = texture(gtexture, texcoord) * glcolor;
    if (c.a < 0.01) discard;
    // Streaks catch the light: a bit brighter than the haze behind them, or
    // in a storm (where the haze is the same grey) they vanish into it.
    outColor = vec4(rainColor(c.rgb) * 1.35, c.a * 0.55);
}
