#version 330 compatibility

// Deferred lighting for opaque geometry written by our gbuffers programs.
// Reads the packed G-buffer (see lib/gbuf.glsl). Pixels no geometry program of
// ours wrote to (sky, particles, fallback programs) keep their color. Every
// pixel then gets the atmosphere (lib/fog.glsl) from its depth.

#include "/lib/options.glsl"
#include "/lib/gbuf.glsl"
#include "/lib/lighting.glsl"
#include "/lib/fog.glsl"

/* RENDERTARGETS: 0 */

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 c = texture(colortex0, texcoord);
    vec4 d = texture(colortex1, texcoord);
    float depth = texture(depthtex0, texcoord).r;
    vec3 ndc = vec3(texcoord, depth) * 2.0 - 1.0;
    vec4 vp = gbufferProjectionInverse * vec4(ndc, 1.0);
    vec3 viewPos = vp.xyz / vp.w;
    bool isSky = depth >= 1.0;

    vec3 rgb = c.rgb;
    if (d.b > 0.0 && d.a > 0.0) {
        float foliage, emissive;
        vec2 lm = unpackLight(d.rg, foliage, emissive);
        vec3 n = unpackNormal(d.ba);
        vec2 sh = vec2(1.0, 0.0);
#ifdef ENABLE_SHADOWS
        vec3 feet = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
        sh = shadowTerm(feet, n);
#endif
        rgb = shadeSurface(c.rgb, lm, n, c.a, foliage, emissive, sh);
    }
    // Haze for everything drawn so far (also pass-through pixels and sky).
    // Translucents drawn later fog themselves (gbuffers_water).
    outColor = vec4(applyAtmosphere(rgb, viewPos, isSky), 1.0);
}
