#version 330 compatibility

// Held item and hand (same logic as gbuffers_entities.fsh).
// Writes raw albedo + lighting inputs; lighting happens in deferred.fsh.

#include "/lib/options.glsl"

/* RENDERTARGETS: 0,1,2 */

uniform sampler2D gtexture;
uniform float alphaTestRef;
uniform vec4 entityColor;   // hurt flash / creeper fuse overlay

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outLight;
layout(location = 2) out vec4 outNormal;

void main() {
    vec4 tex = texture(gtexture, texcoord) * glcolor;
    if (tex.a < alphaTestRef) discard;
    tex.rgb = mix(tex.rgb, entityColor.rgb, entityColor.a);

    outColor = tex;
    outLight = vec4(clamp(lmcoord, 0.0, 1.0), 1.0, 1.0);
    outNormal = vec4(normalize(normal) * 0.5 + 0.5, 1.0);
}
