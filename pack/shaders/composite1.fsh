#version 330 compatibility

// Bloom prefilter: scene (full res) -> colortex4 (1/2 res).
// Also writes the plain half-res scene to colortex10 for the diffusion pass,
// and the god rays to colortex11 (also 1/2 res, so they share this pass).
// Soft-knee brightness threshold applied per tap, so a single hot pixel
// (torch flame, lava) is kept instead of being averaged away first.

#include "/lib/options.glsl"

/* RENDERTARGETS: 4,10,11 */

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjection;
uniform vec3 sunPosition;
uniform float sunAngle;
uniform float rainStrength;
uniform bool hasSkylight;
uniform int isEyeInWater;
uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outScene;   // unthresholded copy for diffusion
layout(location = 2) out vec4 outShafts;  // god rays, already tinted and scaled

vec3 brightPart(vec3 c) {
    float peak = max(max(c.r, c.g), c.b);
    float knee = BLOOM_THRESHOLD * 0.5 + 0.0001;
    float soft = clamp(peak - BLOOM_THRESHOLD + knee, 0.0, 2.0 * knee);
    soft = soft * soft / (4.0 * knee);
    float gain = max(soft, peak - BLOOM_THRESHOLD) / max(peak, 0.0001);
    return c * gain;
}

#ifdef ENABLE_GODRAYS
// Screen-space light shafts: march from this pixel toward the sun's screen
// position and count how many taps see open sky (depth 1). Sky near the sun is
// the light source, anything else blocks it. The same sum gives the glare
// around the sun, because rays that start close to it are almost all sky.
vec3 godRays(vec2 uv) {
    if (!hasSkylight || isEyeInWater != 0) return vec3(0.0);

    float h = sin(sunAngle * 6.28318530718);
    float dayAmt = smoothstep(-0.10, 0.20, h);
    float lowSun = (1.0 - smoothstep(0.02, 0.50, h)) * dayAmt;      // sunrise / sunset
    // Strongest when the sun is low; a noon sun is mostly out of view anyway.
    float amount = dayAmt * (1.0 - rainStrength) * mix(0.45, 1.0, lowSun);
    if (amount <= 0.0) return vec3(0.0);

    vec4 clip = gbufferProjection * vec4(sunPosition, 1.0);
    if (clip.w <= 0.0) return vec3(0.0);                            // sun behind the camera
    vec2 sunUV = clip.xy / clip.w * 0.5 + 0.5;
    // Fade out as the sun leaves the screen, instead of popping off at the edge.
    vec2 beyond = max(abs(sunUV - 0.5) * 2.0 - 1.0, vec2(0.0));
    float onScreen = 1.0 - smoothstep(0.0, 0.6, max(beyond.x, beyond.y));
    if (onScreen <= 0.0) return vec3(0.0);

    float aspect = viewWidth / viewHeight;
    float d = length((uv - sunUV) * vec2(aspect, 1.0));
    float falloff = exp(-d * 3.5);
    // Dim the glare over the sun's own quad so vanilla's sun stays visible: the
    // quad is 30 blocks wide at 100 away, so its half-height on screen is
    // 0.15 * proj[1][1] / 2 (in height units). Inside that the glare drops to
    // GODRAY_GLARE; just outside it the halo is at full strength.
    float discR = 0.075 * gbufferProjection[1][1];
    falloff *= mix(GODRAY_GLARE, 1.0, smoothstep(0.6 * discR, 1.5 * discR, d));

    vec2 delta = (sunUV - uv) * GODRAY_LENGTH / float(GODRAY_SAMPLES);
    // Per-pixel start offset turns step banding into noise that the upsample,
    // FXAA and film grain hide.
    float jitter = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
    vec2 p = uv + delta * jitter;
    float open = 0.0;
    for (int i = 0; i < GODRAY_SAMPLES; i++) {
        p += delta;
        bool inside = p.x >= 0.0 && p.x <= 1.0 && p.y >= 0.0 && p.y <= 1.0;
        open += (inside && texture(depthtex0, p).r >= 1.0) ? 1.0 : 0.0;
    }
    open /= float(GODRAY_SAMPLES);

    vec3 tint = mix(vec3(1.00, 0.93, 0.80), vec3(1.00, 0.55, 0.25), lowSun);

    // Headroom limit: shafts add light, so over sky that is already near white
    // (right around the sun) they would only clip it. Scale them by how much
    // room the scene pixel has left, so the sky next to the sun stays natural
    // while rays over blue sky, clouds and shaded ground keep full strength.
    float sceneLuma = dot(texture(colortex0, uv).rgb, vec3(0.2126, 0.7152, 0.0722));
    float headroom = mix(1.0, clamp((1.0 - sceneLuma) / 0.35, 0.0, 1.0), GODRAY_LIMIT);

    // Open sky sees an even glow, not shafts, so a sky pixel keeps only a
    // little of it; full rays show over terrain and clouds, where they read.
    float selfSky = texture(depthtex0, uv).r >= 1.0 ? 0.35 : 1.0;

    return tint * (open * falloff * onScreen * amount * GODRAY_STRENGTH * headroom * selfSky);
}
#endif

void main() {
    vec2 ts = vec2(1.0 / viewWidth, 1.0 / viewHeight);
    vec3 a = texture(colortex0, texcoord + ts * vec2( 1.0,  1.0)).rgb;
    vec3 b = texture(colortex0, texcoord + ts * vec2(-1.0,  1.0)).rgb;
    vec3 c = texture(colortex0, texcoord + ts * vec2( 1.0, -1.0)).rgb;
    vec3 d = texture(colortex0, texcoord + ts * vec2(-1.0, -1.0)).rgb;
    outColor = vec4((brightPart(a) + brightPart(b) + brightPart(c) + brightPart(d)) * 0.25, 1.0);
#ifdef ENABLE_DIFFUSION
    outScene = vec4((a + b + c + d) * 0.25, 1.0);
#else
    outScene = vec4(0.0);
#endif
#ifdef ENABLE_GODRAYS
    outShafts = vec4(godRays(texcoord), 1.0);
#else
    outShafts = vec4(0.0);
#endif
}
