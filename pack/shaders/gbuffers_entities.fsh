#version 330 compatibility

// Entities. Lit right here (forward shading, see lib/surface.glsl).

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

    // Alpha stays the texture alpha so translucent entity parts still blend.
    vec3 lit = litSurface(tex.rgb, clamp(lmcoord, 0.0, 1.0), normalize(normal), 1.0, 0.0, 0.0,
                          viewPos, true);
    outColor = vec4(lit, tex.a);
}
