#version 330 compatibility

// Terrain (also block entities and damage overlay via Iris fallbacks).
// Writes raw albedo + lighting inputs (see lib/gbuf.glsl); lighting happens in
// deferred.fsh.
// shaders.properties sets separateAo=true, so for terrain: rgb = biome tint,
// a = vertex ambient occlusion.

#include "/lib/options.glsl"
#include "/lib/gbuf.glsl"

/* RENDERTARGETS: 0,1 */

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outLight;

void main() {
    vec4 tex = texture(gtexture, texcoord);
    if (tex.a < alphaTestRef) discard;

    vec3 n = normalize(normal);
    vec2 lm = clamp(lmcoord, 0.0, 1.0);
    float ao = glcolor.a;

    outColor = vec4(tex.rgb * glcolor.rgb, ao);
    outLight = vec4(lm, packNormal(n));

#if DEBUG_VIEW == 1
    outColor = vec4(glcolor.rgb, 1.0);
    outLight.ba = vec2(0.0);
#elif DEBUG_VIEW == 2
    outColor = vec4(vec3(ao), 1.0);
    outLight.ba = vec2(0.0);
#elif DEBUG_VIEW == 3
    outColor = vec4(n * 0.5 + 0.5, 1.0);
    outLight.ba = vec2(0.0);
#elif DEBUG_VIEW == 4
    outColor = vec4(lm, 0.0, 1.0);
    outLight.ba = vec2(0.0);
#endif
}
