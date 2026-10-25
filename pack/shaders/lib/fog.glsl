// Atmosphere: distance haze toward the sky color, a warm glow toward the sun,
// and the water / lava / blindness fog vanilla would normally draw.
// Applied where each surface is shaded (lib/surface.glsl for opaque geometry,
// gbuffers_water for translucents, gbuffers_skybasic for the in-medium fogs on
// the sky), so no separate full-screen pass reads and rewrites the scene.
// Include after lib/options.glsl and lib/lighting.glsl (which declare sunAngle,
// rainStrength, hasSkylight, fogColor, gbufferModelViewInverse).
// The #ifdef ENABLE_HAZE in applyAtmosphere keeps the menu toggle listed.

uniform vec3 skyColor;
uniform vec3 upPosition;
uniform float far;
uniform float blindness;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

#include "/lib/sky.glsl"

// Returns the scene color mixed with the fog for a surface at viewPos.
// isSky: nothing was drawn there (depth 1), so only the in-medium fogs apply.
vec3 applyAtmosphere(vec3 scene, vec3 viewPos, bool isSky) {
#ifdef ENABLE_HAZE
    float dist = length(viewPos);
    vec3 dir = viewPos / max(dist, 0.0001);

    // How much sky the camera can see (caves -> 0). Dimensions without sky
    // (Nether, End) keep their fog color at full strength.
    float skyEye = hasSkylight ? clamp(float(eyeBrightnessSmooth.y) / 240.0, 0.0, 1.0) : 1.0;

    vec3 fogCol = fogColor;
    float fogAmt = 0.0;

    if (isEyeInWater == 1) {
#ifdef ENABLE_UNDERWATER
        // Water eats red first, then green, and blue last: distant things go
        // blue-green before they fade into the water colour.
        scene *= exp(-dist * vec3(0.065, 0.022, 0.008));
        fogAmt = 1.0 - exp(-dist * 0.026);
        // Vanilla's water colour is an almost pure ultramarine, which no channel
        // scaling can turn into water. Use a fixed teal hue instead, at the
        // brightness vanilla's fog has (so it still follows the time of day
        // and the biome's depth feel), blended 50% so a hint of the biome's
        // own water colour stays.
        float wb = max(max(fogColor.r, fogColor.g), fogColor.b);
        // Vanilla's underwater fog goes dark quickly in dim light, so a sunlit
        // shallows ends up far darker than the water seen from above. A daylight
        // floor (scaled by sky access, so caves and night still go dark).
        wb = max(wb, hasSkylight ? 0.40 * smoothstep(-0.10, 0.20, sin(sunAngle * 6.28318530718)) * skyEye : 0.0);
        fogCol = mix(fogColor, vec3(0.20, 0.80, 0.95) * wb * 1.1, 0.50);
#else
        fogAmt = 1.0 - exp(-dist * 0.035);
#endif
    } else if (isEyeInWater == 2) {
        fogAmt = 1.0 - exp(-dist * 0.45);
    } else if (!isSky) {
        // Terrain fades toward the sky color behind it, so a fully fogged
        // object is exactly the sky (no silhouette).
        fogCol = skyGradient(dir);

        float weatherBoost = 1.0 + rainStrength * 2.0 * (0.5 + 0.5 * RAIN_MOOD);
        // Rain curtain: its own density, independent of HAZE_AMOUNT, so the
        // far end of the render distance is ~90% gone and mid-distance soft.
        // Thunder darkens the fog colour to near the terrain's own shade, so
        // the same density reads as clearer air; it gets extra density here
        // (and a lifted sky colour in lib/sky.glsl) to keep the curtain at the
        // same range.
        float rainDensity = rainStrength * RAIN_MOOD * 2.3 * (1.0 + 0.6 * thunderStrength);
        float haze = 1.0 - exp(-dist / max(far, 32.0) * (0.43 * HAZE_AMOUNT * weatherBoost + rainDensity));
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
    return mix(scene, fogCol, clamp(fogAmt, 0.0, 1.0));
#else
    return scene;
#endif
}
