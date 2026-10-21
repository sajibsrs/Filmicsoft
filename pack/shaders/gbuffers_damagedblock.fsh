#version 330 compatibility

// Block-breaking cracks. Blended onto the lit block (see shaders.properties),
// so the shader only outputs the crack texture.

/* RENDERTARGETS: 0 */

uniform sampler2D gtexture;
uniform float alphaTestRef;

in vec2 texcoord;
in vec4 glcolor;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 c = texture(gtexture, texcoord) * glcolor;
    if (c.a < alphaTestRef) discard;
    outColor = c;
}
