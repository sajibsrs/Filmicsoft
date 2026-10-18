#version 330 compatibility

// Atmosphere: distance haze toward the sky color, a warm glow toward the sun,
// and the water / lava / blindness fog that vanilla would normally draw.
// Runs after translucents, before the bloom chain, and rewrites colortex0.

#include "/lib/options.glsl"

/* RENDERTARGETS: 0 */

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
uniform vec3 fogColor;
uniform vec3 sunPosition;
uniform float sunAngle;
uniform float far;
uniform float rainStrength;
uniform float blindness;
uniform int isEyeInWater;
uniform bool hasSkylight;
uniform ivec2 eyeBrightnessSmooth;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 c = texture(colortex0, texcoord);
    float depth = texture(depthtex0, texcoord).r;

    vec3 ndc = vec3(texcoord, depth) * 2.0 - 1.0;
    vec4 v = gbufferProjectionInverse * vec4(ndc, 1.0);
    vec3 viewPos = v.xyz / v.w;
    float dist = length(viewPos);
    vec3 dir = viewPos / max(dist, 0.0001);
    bool isSky = depth >= 1.0;

    // How much sky the camera can see (caves -> 0). Dimensions without sky
    // (Nether, End) keep their fog color at full strength.
    float skyEye = hasSkylight ? clamp(float(eyeBrightnessSmooth.y) / 240.0, 0.0, 1.0) : 1.0;

    float h = sin(sunAngle * 6.28318530718);
    float dayAmt = smoothstep(-0.10, 0.20, h);
    float warm = (1.0 - smoothstep(0.02, 0.50, h)) * dayAmt;

    vec3 fogCol = fogColor;
    float fogAmt = 0.0;

    if (isEyeInWater == 1) {
        fogAmt = 1.0 - exp(-dist * 0.035);
    } else if (isEyeInWater == 2) {
        fogAmt = 1.0 - exp(-dist * 0.45);
    } else if (!isSky) {
        float weatherBoost = 1.0 + rainStrength * 2.0;
        float haze = 1.0 - exp(-dist * 0.43 / max(far, 32.0) * HAZE_AMOUNT * weatherBoost);
        haze *= skyEye;
        // Fade the last stretch fully to fog so the chunk border never shows.
        float edge = smoothstep(far * 0.75, far * 0.98, dist);
        fogAmt = max(haze, edge);

        if (hasSkylight) {
            float sd = max(dot(dir, normalize(sunPosition)), 0.0);
            vec3 glow = mix(vec3(1.00, 0.90, 0.70), vec3(1.00, 0.50, 0.20), warm);
            fogCol += glow * pow(sd, 5.0) * HAZE_SUN_GLOW * 0.5 * dayAmt * skyEye * (1.0 - rainStrength);
        }
        fogCol *= mix(0.10, 1.0, skyEye);
    }

    if (blindness > 0.0) {
        fogAmt = max(fogAmt, 1.0 - exp(-dist * 0.35 * blindness));
        fogCol = mix(fogCol, vec3(0.0), blindness);
    }

    outColor = vec4(mix(c.rgb, fogCol, clamp(fogAmt, 0.0, 1.0)), c.a);
}
