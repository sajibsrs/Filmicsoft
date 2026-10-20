#version 330 compatibility

// Terrain (also block entities and damage overlay via Iris fallbacks).
// Lit right here (forward shading, see lib/surface.glsl).
// shaders.properties sets separateAo=true, so for terrain: rgb = biome tint,
// a = vertex ambient occlusion.

#include "/lib/options.glsl"
#include "/lib/lighting.glsl"
#include "/lib/fog.glsl"
#include "/lib/surface.glsl"

/* RENDERTARGETS: 0 */

uniform sampler2D gtexture;
uniform float alphaTestRef;
uniform int renderStage;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;
in vec3 viewPos;
flat in int foliage;
flat in int emissive;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 tex = texture(gtexture, texcoord);
    if (tex.a < alphaTestRef) discard;

    // Block-breaking cracks multiply onto the already lit block: keep them unlit.
    if (renderStage == MC_RENDER_STAGE_DESTROY) {
        outColor = tex * glcolor;
        return;
    }

    vec3 n = normalize(normal);
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
#endif
}
