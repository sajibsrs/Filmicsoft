#version 330 compatibility

// Translucent terrain (water, stained glass, ice). Drawn after the deferred
// pass, so it is lit directly with the same model as opaque surfaces.

#include "/lib/options.glsl"
#include "/lib/lighting.glsl"

/* RENDERTARGETS: 0 */

uniform sampler2D gtexture;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 tex = texture(gtexture, texcoord);
    // Terrain programs carry vertex AO in glcolor.a (separateAo=true).
    vec3 lit = shadeSurface(tex.rgb * glcolor.rgb, clamp(lmcoord, 0.0, 1.0),
                            normalize(normal), glcolor.a, 0.0);
    outColor = vec4(lit, tex.a);
}
