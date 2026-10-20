#version 330 compatibility

// Sun and moon. Without this program Iris's fallback blends the quad as a
// normal overlay, so in rain the texture's dark padding shows as a grey square.
// Draw it the vanilla way instead: added on top of the sky, faded by the
// vertex alpha (which carries the rain fade). See blend.gbuffers_skytextured.
// Underwater, in lava and when blind the sky is all fog (gbuffers_skybasic),
// so the sun and moon fade out with it.

/* RENDERTARGETS: 0 */

uniform sampler2D gtexture;
uniform int isEyeInWater;
uniform float blindness;

in vec2 texcoord;
in vec4 glcolor;

layout(location = 0) out vec4 outColor;

void main() {
    if (isEyeInWater != 0) discard;
    vec4 c = texture(gtexture, texcoord) * glcolor;
    outColor = vec4(c.rgb * c.a * (1.0 - blindness), 1.0);
}
