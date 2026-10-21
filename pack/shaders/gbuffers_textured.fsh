#version 330 compatibility

// Particles (and other unlit textured geometry Iris routes here). Drawn the
// vanilla way: texture * vertex colour * lightmap.

/* RENDERTARGETS: 0 */

uniform sampler2D gtexture;
uniform sampler2D lightmap;
uniform float alphaTestRef;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 c = texture(gtexture, texcoord) * glcolor;
    if (c.a < alphaTestRef) discard;
    c.rgb *= texture(lightmap, lmcoord).rgb;
    outColor = c;
}
