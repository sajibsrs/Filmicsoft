#version 330 compatibility

// Bloom downsample: colortex6 (1/8) -> colortex7 (1/16).

/* RENDERTARGETS: 7 */

uniform sampler2D colortex6;
uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

void main() {
    vec2 ts = vec2(8.0 / viewWidth, 8.0 / viewHeight);
    vec3 sum = texture(colortex6, texcoord + ts * vec2( 1.0,  1.0)).rgb;
    sum     += texture(colortex6, texcoord + ts * vec2(-1.0,  1.0)).rgb;
    sum     += texture(colortex6, texcoord + ts * vec2( 1.0, -1.0)).rgb;
    sum     += texture(colortex6, texcoord + ts * vec2(-1.0, -1.0)).rgb;
    outColor = vec4(sum * 0.25, 1.0);
}
