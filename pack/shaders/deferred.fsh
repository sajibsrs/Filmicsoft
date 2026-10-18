#version 330 compatibility

// Deferred lighting for opaque geometry written by our gbuffers programs.
// Reads the packed G-buffer (see lib/gbuf.glsl). Pixels no geometry program of
// ours wrote to (sky, clouds, particles, fallback programs) are passed through
// unchanged.

#include "/lib/options.glsl"
#include "/lib/gbuf.glsl"
#include "/lib/lighting.glsl"

/* RENDERTARGETS: 0 */

uniform sampler2D colortex0;
uniform sampler2D colortex1;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 c = texture(colortex0, texcoord);
    vec4 d = texture(colortex1, texcoord);
    if (d.b <= 0.0 || d.a <= 0.0) {
        outColor = c;
        return;
    }
    float foliage;
    vec2 lm = unpackLight(d.rg, foliage);
    outColor = vec4(shadeSurface(c.rgb, lm, unpackNormal(d.ba), c.a, foliage), 1.0);
}
