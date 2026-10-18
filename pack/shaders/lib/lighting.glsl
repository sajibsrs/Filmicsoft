// Filmicsoft lighting model. Shared by the deferred pass (opaque surfaces)
// and gbuffers_water (translucent, lit directly).
//
// Include AFTER lib/options.glsl. No shadow maps: "is this sunlit?" comes from
// the sky-light level of the vanilla lightmap, which already drops under
// roofs, trees and in caves, so it doubles as a cheap shadow.

uniform float sunAngle;
uniform vec3 shadowLightPosition;
uniform mat4 gbufferModelViewInverse;
uniform float rainStrength;
uniform bool hasSkylight;
uniform vec3 fogColor;

const vec3 LIGHT_LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 toLinear(vec3 c) { return pow(max(c, vec3(0.0)), vec3(2.2)); }
vec3 toGamma(vec3 c) { return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2)); }

// albedoGamma : texture color (display space)
// lm          : x = block light, y = sky light, both 0..1
// nWS         : surface normal in player/world orientation, normalised
// ao          : vertex ambient occlusion, 1 = open
vec3 shadeSurface(vec3 albedoGamma, vec2 lm, vec3 nWS, float ao) {
    vec3 albedo = toLinear(albedoGamma);
    float sky = clamp(lm.y, 0.0, 1.0);
    float blk = clamp(lm.x, 0.0, 1.0);
    float aoT = pow(clamp(ao, 0.0, 1.0), AO_STRENGTH);

    // Time of day: h = sun height (+ day, - night).
    float h = sin(sunAngle * 6.28318530718);
    float dayAmt = smoothstep(-0.10, 0.20, h);
    float warm = (1.0 - smoothstep(0.02, 0.50, h)) * dayAmt;   // sunrise / sunset
    float rain = rainStrength;

    // ---- Direct light (sun by day, moon by night) --------------------------
    vec3 direct = vec3(0.0);
    if (hasSkylight) {
        vec3 L = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
        float diff = clamp((dot(nWS, L) + 0.2) / 1.2, 0.0, 1.0);    // soft wrap
        float open = smoothstep(0.86, 0.98, sky);                    // fake shadow
        vec3 sunCol = mix(vec3(1.00, 0.93, 0.80), vec3(1.00, 0.48, 0.20), warm) * SUN_INTENSITY;
        vec3 moonCol = vec3(0.42, 0.55, 1.00) * 0.10 * MOON_BRIGHTNESS;
        vec3 directCol = mix(moonCol, sunCol, dayAmt) * (1.0 - 0.9 * rain);
        direct = directCol * diff * open * mix(1.0, aoT, 0.5);
    }

    // ---- Ambient: cool sky above, warm bounce below -----------------------
    vec3 ambient = vec3(0.0);
    if (hasSkylight) {
        vec3 ambDay = vec3(0.30, 0.37, 0.50);
        vec3 ambSet = vec3(0.38, 0.31, 0.33);
        vec3 ambNight = vec3(0.045, 0.060, 0.115) * MOON_BRIGHTNESS;
        vec3 amb = mix(ambNight, mix(ambDay, ambSet, warm), dayAmt);
        amb = mix(amb, vec3(dot(amb, LIGHT_LUMA)) * 0.9, rain * 0.6) * (1.0 - 0.25 * rain);
        vec3 ground = amb * vec3(0.55, 0.50, 0.45);
        float hemi = nWS.y * 0.5 + 0.5;
        ambient = mix(ground, amb, hemi) * pow(sky, 1.8) * aoT * AMBIENT_INTENSITY;
    }

    // ---- Block light: warm, white-hot near the source ----------------------
    vec3 blockCol = mix(vec3(1.00, 0.58, 0.26), vec3(1.00, 0.82, 0.58), blk * blk * blk * blk);
    vec3 block = blockCol * pow(blk, 2.4) * 1.25 * BLOCKLIGHT_INTENSITY * mix(1.0, aoT, 0.7);

    // ---- Floor so nothing is pitch black -----------------------------------
    // Overworld caves stay dark; Nether / End (no sky) get a fog-tinted glow.
    vec3 floorLight = vec3(0.010, 0.011, 0.014);
    if (!hasSkylight) {
        vec3 tint = fogColor / max(max(max(fogColor.r, fogColor.g), fogColor.b), 0.0001);
        floorLight = mix(vec3(1.0), tint, 0.6) * 0.11;
    }

    return toGamma(albedo * (direct + ambient + block + floorLight));
}
