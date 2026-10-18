#version 330 compatibility

// Bloom downsample, 4x per pass: colortex5 (1/8) -> colortex6 (1/32).

/* RENDERTARGETS: 6 */

uniform sampler2D colortex5;
uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

void main() {
    // Spacing as a fraction of screen height: resolution-independent radius.
    vec2 s = vec2(0.0148 * viewHeight / viewWidth, 0.0148);
    vec3 sum = texture(colortex5, texcoord).rgb * 4.0;
    sum += texture(colortex5, texcoord + vec2( s.x, 0.0)).rgb * 2.0;
    sum += texture(colortex5, texcoord + vec2(-s.x, 0.0)).rgb * 2.0;
    sum += texture(colortex5, texcoord + vec2(0.0,  s.y)).rgb * 2.0;
    sum += texture(colortex5, texcoord + vec2(0.0, -s.y)).rgb * 2.0;
    sum += texture(colortex5, texcoord + vec2( s.x,  s.y)).rgb;
    sum += texture(colortex5, texcoord + vec2(-s.x,  s.y)).rgb;
    sum += texture(colortex5, texcoord + vec2( s.x, -s.y)).rgb;
    sum += texture(colortex5, texcoord + vec2(-s.x, -s.y)).rgb;
    outColor = vec4(sum / 16.0, 1.0);
}
