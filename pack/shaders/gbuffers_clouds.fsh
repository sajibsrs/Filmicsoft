#version 330 compatibility

// Clouds. Unlit (deferred passes them through) and tagged in colortex1 so
// final.fsh gives them the sky's horizon haze instead of terrain distance fog,
// which would paint far cloud boxes solid fog color.
// Distance fades the cloud into transparency, like vanilla, so the grid of
// boxes dissolves toward the horizon instead of ending in hard edges.

/* RENDERTARGETS: 0,1 */

uniform sampler2D gtexture;
uniform vec3 skyColor;
uniform vec3 fogColor;
uniform vec3 upPosition;
uniform float far;

#include "/lib/sky.glsl"

in vec2 texcoord;
in vec4 glcolor;
in vec3 viewPos;

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outTag;

void main() {
    vec4 c = texture(gtexture, texcoord) * glcolor;

    // Clouds reach well past the terrain render distance, so fade over 2x far.
    float dist = length(viewPos);
    float t = clamp(dist / (max(far, 64.0) * 2.0), 0.0, 1.0);

    // Melt into the sky color behind the cloud, then into transparency, so
    // far cloud boxes dissolve instead of showing as pale flat blocks.
    c.rgb = mix(c.rgb, skyGradient(viewPos / max(dist, 0.0001)), smoothstep(0.05, 0.70, t));
    c.a *= 1.0 - smoothstep(0.30, 0.90, t);
    if (c.a < 0.01) discard;

    outColor = c;
    outTag = vec4(0.0, 0.0, 1.0, 0.0);
}
