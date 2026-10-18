#version 330 compatibility

// Bloom downsample: colortex7 (1/16) -> colortex8 (1/32).

/* RENDERTARGETS: 8 */

uniform sampler2D colortex7;
uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

void main() {
    vec2 ts = vec2(16.0 / viewWidth, 16.0 / viewHeight);
    vec3 sum = texture(colortex7, texcoord + ts * vec2( 1.0,  1.0)).rgb;
    sum     += texture(colortex7, texcoord + ts * vec2(-1.0,  1.0)).rgb;
    sum     += texture(colortex7, texcoord + ts * vec2( 1.0, -1.0)).rgb;
    sum     += texture(colortex7, texcoord + ts * vec2(-1.0, -1.0)).rgb;
    outColor = vec4(sum * 0.25, 1.0);
}
