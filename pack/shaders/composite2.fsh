#version 330 compatibility

// Bloom downsample, 4x per pass: colortex4 (1/2) -> colortex5 (1/8).
// Also builds the diffusion source ("pro-mist"): a wide blur of the plain
// half-res scene copy colortex10 -> colortex9, same size so it shares the pass.
// Nine bilinear taps in a 3x3 tent, spaced two source texels apart, so the
// whole 6x6 neighbourhood is covered without gaps.

#include "/lib/options.glsl"

/* RENDERTARGETS: 5,9 */

uniform sampler2D colortex4;
uniform sampler2D colortex10;
uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outDiffuse;

void main() {
    // Tap spacing is a fraction of screen height (same on-screen blur radius at
    // any resolution); x is corrected for aspect so the kernel stays square.
    float aspect = viewHeight / viewWidth;
    vec2 s = vec2(0.0037 * aspect, 0.0037);
    vec3 sum = texture(colortex4, texcoord).rgb * 4.0;
    sum += texture(colortex4, texcoord + vec2( s.x, 0.0)).rgb * 2.0;
    sum += texture(colortex4, texcoord + vec2(-s.x, 0.0)).rgb * 2.0;
    sum += texture(colortex4, texcoord + vec2(0.0,  s.y)).rgb * 2.0;
    sum += texture(colortex4, texcoord + vec2(0.0, -s.y)).rgb * 2.0;
    sum += texture(colortex4, texcoord + vec2( s.x,  s.y)).rgb;
    sum += texture(colortex4, texcoord + vec2(-s.x,  s.y)).rgb;
    sum += texture(colortex4, texcoord + vec2( s.x, -s.y)).rgb;
    sum += texture(colortex4, texcoord + vec2(-s.x, -s.y)).rgb;
    outColor = vec4(sum / 16.0, 1.0);

#ifdef ENABLE_DIFFUSION
    // Diffusion: same 3x3 tent, spread twice as wide.
    vec2 d = vec2(0.0074 * aspect, 0.0074);
    vec3 df = texture(colortex10, texcoord).rgb * 4.0;
    df += texture(colortex10, texcoord + vec2( d.x, 0.0)).rgb * 2.0;
    df += texture(colortex10, texcoord + vec2(-d.x, 0.0)).rgb * 2.0;
    df += texture(colortex10, texcoord + vec2(0.0,  d.y)).rgb * 2.0;
    df += texture(colortex10, texcoord + vec2(0.0, -d.y)).rgb * 2.0;
    df += texture(colortex10, texcoord + vec2( d.x,  d.y)).rgb;
    df += texture(colortex10, texcoord + vec2(-d.x,  d.y)).rgb;
    df += texture(colortex10, texcoord + vec2( d.x, -d.y)).rgb;
    df += texture(colortex10, texcoord + vec2(-d.x, -d.y)).rgb;
    outDiffuse = vec4(df / 16.0, 1.0);
#else
    outDiffuse = vec4(0.0);
#endif
}
