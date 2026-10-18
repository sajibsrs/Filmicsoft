#version 330 compatibility

// Bloom downsample: colortex4 (1/2) -> colortex5 (1/4).

/* RENDERTARGETS: 5 */

uniform sampler2D colortex4;
uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

void main() {
    // Source is half resolution, so one source texel = 2 full-res pixels.
    vec2 ts = vec2(2.0 / viewWidth, 2.0 / viewHeight);
    vec3 sum = texture(colortex4, texcoord + ts * vec2( 1.0,  1.0)).rgb;
    sum     += texture(colortex4, texcoord + ts * vec2(-1.0,  1.0)).rgb;
    sum     += texture(colortex4, texcoord + ts * vec2( 1.0, -1.0)).rgb;
    sum     += texture(colortex4, texcoord + ts * vec2(-1.0, -1.0)).rgb;
    outColor = vec4(sum * 0.25, 1.0);
}
