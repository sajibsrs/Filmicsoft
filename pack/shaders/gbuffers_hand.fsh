#version 330 compatibility

// Held item and hand (same logic as gbuffers_entities.fsh).
// Writes raw albedo + lighting inputs; lighting happens in deferred.fsh.

#include "/lib/options.glsl"
#include "/lib/gbuf.glsl"

/* RENDERTARGETS: 0,1 */

uniform sampler2D gtexture;
uniform float alphaTestRef;
uniform vec4 entityColor;   // hurt flash / creeper fuse overlay

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outLight;

void main() {
    vec4 tex = texture(gtexture, texcoord) * glcolor;
    if (tex.a < alphaTestRef) discard;
    tex.rgb = mix(tex.rgb, entityColor.rgb, entityColor.a);

    // Alpha doubles as AO in the G-buffer. The hand is solid, so keep it at 1:
    // any alpha below 1 here lets the terrain behind it show through.
    outColor = vec4(tex.rgb, 1.0);
    outLight = vec4(packLight(lmcoord, false), packNormal(normal));
}
