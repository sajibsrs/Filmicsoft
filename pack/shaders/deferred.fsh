#version 330 compatibility

// Deferred lighting for opaque geometry written by our gbuffers programs.
//   colortex0 : albedo (display space)
//   colortex1 : rg = lightmap (block, sky), b = vertex AO, a = "lit by us" flag
//   colortex2 : world-oriented normal, encoded 0..1
// Pixels without the flag (sky, clouds, particles, fallback programs) are
// passed through unchanged.

#include "/lib/options.glsl"
#include "/lib/lighting.glsl"

/* RENDERTARGETS: 0 */

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 c = texture(colortex0, texcoord);
    vec4 d = texture(colortex1, texcoord);
    if (d.a < 0.5) {
        outColor = c;
        return;
    }
    vec3 n = normalize(texture(colortex2, texcoord).rgb * 2.0 - 1.0);
    outColor = vec4(shadeSurface(c.rgb, d.rg, n, d.b), c.a);
}
