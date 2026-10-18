#version 330 compatibility

// Bloom downsample: colortex5 (1/4) -> colortex6 (1/8).

/* RENDERTARGETS: 6 */

uniform sampler2D colortex5;
uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

void main() {
    vec2 ts = vec2(4.0 / viewWidth, 4.0 / viewHeight);
    vec3 sum = texture(colortex5, texcoord + ts * vec2( 1.0,  1.0)).rgb;
    sum     += texture(colortex5, texcoord + ts * vec2(-1.0,  1.0)).rgb;
    sum     += texture(colortex5, texcoord + ts * vec2( 1.0, -1.0)).rgb;
    sum     += texture(colortex5, texcoord + ts * vec2(-1.0, -1.0)).rgb;
    outColor = vec4(sum * 0.25, 1.0);
}
