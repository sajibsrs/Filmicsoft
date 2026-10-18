#version 330 compatibility

// Entities (also used, identically, for the held item in gbuffers_hand).
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

    // Alpha doubles as AO in the G-buffer; for entities it stays the texture
    // alpha so translucent entity parts still blend.
    outColor = tex;
    outLight = vec4(packLight(lmcoord, false), packNormal(normal));
}
