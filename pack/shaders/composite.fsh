#version 330 compatibility

// Bloom prefilter: scene (full res) -> colortex4 (1/2 res).
// Soft-knee brightness threshold applied per tap, so a single hot pixel
// (torch flame, lava) is kept instead of being averaged away first.

#include "/lib/options.glsl"

/* RENDERTARGETS: 4 */

uniform sampler2D colortex0;
uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

vec3 brightPart(vec3 c) {
    float peak = max(max(c.r, c.g), c.b);
    float knee = BLOOM_THRESHOLD * 0.5 + 0.0001;
    float soft = clamp(peak - BLOOM_THRESHOLD + knee, 0.0, 2.0 * knee);
    soft = soft * soft / (4.0 * knee);
    float gain = max(soft, peak - BLOOM_THRESHOLD) / max(peak, 0.0001);
    return c * gain;
}

void main() {
    vec2 ts = vec2(1.0 / viewWidth, 1.0 / viewHeight);
    vec3 sum = brightPart(texture(colortex0, texcoord + ts * vec2( 1.0,  1.0)).rgb);
    sum     += brightPart(texture(colortex0, texcoord + ts * vec2(-1.0,  1.0)).rgb);
    sum     += brightPart(texture(colortex0, texcoord + ts * vec2( 1.0, -1.0)).rgb);
    sum     += brightPart(texture(colortex0, texcoord + ts * vec2(-1.0, -1.0)).rgb);
    outColor = vec4(sum * 0.25, 1.0);
}
