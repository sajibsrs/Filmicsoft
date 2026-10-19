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
#ifdef ENABLE_SHADOWS
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
#endif

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 c = texture(colortex0, texcoord);
    vec4 d = texture(colortex1, texcoord);
    if (d.b <= 0.0 || d.a <= 0.0) {
        outColor = c;
        return;
    }
    float foliage, emissive;
    vec2 lm = unpackLight(d.rg, foliage, emissive);
    vec3 n = unpackNormal(d.ba);
    vec2 sh = vec2(1.0, 0.0);
#ifdef ENABLE_SHADOWS
    vec3 ndc = vec3(texcoord, texture(depthtex0, texcoord).r) * 2.0 - 1.0;
    vec4 vp = gbufferProjectionInverse * vec4(ndc, 1.0);
    vec3 feet = (gbufferModelViewInverse * vec4(vp.xyz / vp.w, 1.0)).xyz;
    sh = shadowTerm(feet, n);
#endif
    outColor = vec4(shadeSurface(c.rgb, lm, n, c.a, foliage, emissive, sh), 1.0);
}
