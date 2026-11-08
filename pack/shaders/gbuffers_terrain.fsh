#version 330 compatibility

// Terrain (also block entities via Iris fallbacks).
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

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;
in vec3 viewPos;
flat in int foliage;
flat in int emissive;
flat in int grassCard;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 tex = texture(gtexture, texcoord);
    if (tex.a < alphaTestRef) discard;

    vec3 n = normalize(normal);
    // Grass is a pair of crossed cards drawn as two faces back to back. From
    // the side away from the sun you see the face whose normal points away
    // from it, which the shadow lookup counts as "turned from the light" and
    // blacks out. A blade is thin, so that face gets the sunlight that passes
    // through it: lit as if facing the sun, at a share of the strength, so
    // grass against the sun reads darker than grass with the sun behind you.
    if (grassCard == 1 && dot(n, mat3(gbufferModelViewInverse) * shadowLightPosition) < 0.0) {
        n = -n;
        sunTransmit = 0.45;
    }
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
