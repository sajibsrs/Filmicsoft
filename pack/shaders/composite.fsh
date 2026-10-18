#version 330 compatibility

// Atmosphere: distance haze toward the sky color, a warm glow toward the sun,
// and the water / lava / blindness fog vanilla would normally draw.
// Its own pass, before bloom and FXAA: fog depends on per-pixel depth, so
// applying it after FXAA leaves edge pixels (half tree, half sky, sky depth)
// unfogged, which shows as a dark outline around every fogged object.

#include "/lib/options.glsl"
// The #ifdef ENABLE_HAZE below is redundant (shaders.properties already
// disables this program), but Iris only lists a toggle in the menu if some
// shader tests it, so it must stay.

/* RENDERTARGETS: 0 */

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform float sunAngle;
uniform float far;
uniform float rainStrength;
uniform float blindness;
uniform int isEyeInWater;
uniform bool hasSkylight;
uniform ivec2 eyeBrightnessSmooth;

#include "/lib/sky.glsl"

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 scene = texture(colortex0, texcoord);
    float depth = texture(depthtex0, texcoord).r;
    vec3 ndc = vec3(texcoord, depth) * 2.0 - 1.0;
    vec4 v = gbufferProjectionInverse * vec4(ndc, 1.0);
    vec3 viewPos = v.xyz / v.w;
    float dist = length(viewPos);
    vec3 dir = viewPos / max(dist, 0.0001);

    bool isSky = depth >= 1.0;
    // gbuffers_clouds tags its pixels with colortex1 = (0, 0, 1, 0).
    vec4 tag = texture(colortex1, texcoord);
    bool isCloud = tag.b > 0.5 && tag.a <= 0.0;

    // How much sky the camera can see (caves -> 0). Dimensions without sky
    // (Nether, End) keep their fog color at full strength.
    float skyEye = hasSkylight ? clamp(float(eyeBrightnessSmooth.y) / 240.0, 0.0, 1.0) : 1.0;

    vec3 fogCol = fogColor;
    float fogAmt = 0.0;

    if (isEyeInWater == 1) {
        fogAmt = 1.0 - exp(-dist * 0.035);
    } else if (isEyeInWater == 2) {
        fogAmt = 1.0 - exp(-dist * 0.45);
    } else if (!isSky && !isCloud) {
        // Sky and clouds already carry their own gradient / distance fade.
        // Terrain fades toward the sky color behind it, so a fully fogged
        // object is exactly the sky (no silhouette).
        fogCol = skyGradient(dir);

        float weatherBoost = 1.0 + rainStrength * 2.0;
        float haze = 1.0 - exp(-dist * 0.43 / max(far, 32.0) * HAZE_AMOUNT * weatherBoost);
        haze *= skyEye;
        // Hide the chunk border like vanilla: horizontal distance, only the
        // last stretch, so mid-distance stays crisp.
        vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos;
        float edge = smoothstep(far * 0.88, far, length(playerPos.xz));
        fogAmt = max(haze, edge);

        if (hasSkylight) {
            float h = sin(sunAngle * 6.28318530718);
            float dayAmt = smoothstep(-0.10, 0.20, h);
            float warm = (1.0 - smoothstep(0.02, 0.50, h)) * dayAmt;
            float sd = max(dot(dir, normalize(sunPosition)), 0.0);
            vec3 glow = mix(vec3(1.00, 0.90, 0.70), vec3(1.00, 0.50, 0.20), warm);
            fogCol += glow * pow(sd, 5.0) * HAZE_SUN_GLOW * 0.5 * dayAmt * skyEye * (1.0 - rainStrength);
        }
        // Underground, fade toward dark instead of bright sky. The chunk-edge
        // fade keeps the sky color so the border still blends with the sky.
        fogCol *= mix(mix(0.10, 1.0, skyEye), 1.0, edge);
    }

    if (blindness > 0.0) {
        fogAmt = max(fogAmt, 1.0 - exp(-dist * 0.35 * blindness));
        fogCol = mix(fogCol, vec3(0.0), blindness);
    }

#ifdef ENABLE_HAZE
    scene.rgb = mix(scene.rgb, fogCol, clamp(fogAmt, 0.0, 1.0));
#endif
    outColor = scene;
}
