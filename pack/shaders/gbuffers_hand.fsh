#version 330 compatibility

// Held item and hand (same logic as gbuffers_entities.fsh). The hand has its
// own projection, so it skips the shadow map and keeps the sky-light shadow.

#include "/lib/options.glsl"
#include "/lib/lighting.glsl"
#include "/lib/fog.glsl"
#include "/lib/surface.glsl"

/* RENDERTARGETS: 0 */

uniform sampler2D gtexture;
uniform float alphaTestRef;
uniform vec4 entityColor;   // hurt flash / creeper fuse overlay

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;
in vec3 viewPos;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 tex = texture(gtexture, texcoord) * glcolor;
    if (tex.a < alphaTestRef) discard;
    tex.rgb = mix(tex.rgb, entityColor.rgb, entityColor.a);

    // The hand is solid: any alpha below 1 lets the terrain behind it show through.
    vec3 lit = litSurface(tex.rgb, clamp(lmcoord, 0.0, 1.0), normalize(normal), 1.0, 0.0, 0.0,
                          viewPos, false);
    outColor = vec4(lit, 1.0);
}
