// Terrain fragment stage, shared by gbuffers_terrain and gbuffers_terrain_solid.
// Include after the #version line.
//
// Iris draws solid terrain (stone, dirt, logs...) through gbuffers_terrain_solid
// and cutout terrain (leaves, grass, flowers, doors...) through
// gbuffers_terrain_cutout, which falls back to gbuffers_terrain. Block entities
// also land on gbuffers_terrain. The solid program defines TERRAIN_SOLID and
// skips the alpha test: a shader with no discard is opaque to the GPU, so
// overdrawn solid fragments can be rejected before shading (early depth test,
// and on tile-based GPUs hidden-surface removal) instead of paying for the
// full lighting, shadow taps and sky gradient. Vanilla does no alpha test on
// the solid layer either, so nothing changes visually.
// Lit right here (forward shading, see lib/surface.glsl).
// shaders.properties sets separateAo=true, so for terrain: rgb = biome tint,
// a = vertex ambient occlusion.

#include "/lib/options.glsl"
#include "/lib/lighting.glsl"
#include "/lib/fog.glsl"
#include "/lib/surface.glsl"

/* RENDERTARGETS: 0 */

uniform sampler2D gtexture;
#ifndef TERRAIN_SOLID
uniform float alphaTestRef;
#endif

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;
in vec3 viewPos;
flat in int foliage;
flat in int emissive;
flat in int plantCard;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 tex = texture(gtexture, texcoord);
#ifndef TERRAIN_SOLID
    if (tex.a < alphaTestRef) discard;
#endif

    vec3 n = normalize(normal);
    isPlantCard = plantCard == 1;   // thin-card lighting, see litSurface
    vec2 lm = clamp(lmcoord, 0.0, 1.0);
    float ao = glcolor.a;

    outColor = vec4(litSurface(tex.rgb * glcolor.rgb, lm, n, ao, float(foliage), float(emissive),
                               viewPos, true), 1.0);

#if DEBUG_VIEW == 1
    outColor = vec4(glcolor.rgb, 1.0);
#elif DEBUG_VIEW == 2
    outColor = vec4(vec3(ao), 1.0);
#elif DEBUG_VIEW == 3
    outColor = vec4(n * 0.5 + 0.5, 1.0);
#elif DEBUG_VIEW == 4
    outColor = vec4(lm, 0.0, 1.0);
#elif DEBUG_VIEW == 6
    // Program split: red = gbuffers_terrain_solid (no alpha test), green =
    // gbuffers_terrain (cutout and block entities). All green means Iris is
    // not routing the solid layer to the solid program.
#ifdef TERRAIN_SOLID
    outColor.rgb = mix(outColor.rgb, vec3(1.0, 0.0, 0.0), 0.5);
#else
    outColor.rgb = mix(outColor.rgb, vec3(0.0, 1.0, 0.0), 0.5);
#endif
#endif
}
