// Filmicsoft lighting model. Shared by the deferred pass (opaque surfaces)
// and gbuffers_water (translucent, lit directly).
//
// Include AFTER lib/options.glsl. No shadow maps: "is this sunlit?" comes from
// the sky-light level of the vanilla lightmap, which already drops under
// roofs, trees and in caves, so it doubles as a cheap shadow.
// Optionally (ENABLE_SHADOWS) a small shadow map replaces that fake inside
// SHADOW_DISTANCE and fades back to it at the edge, at sunset and at night.

uniform float sunAngle;
uniform vec3 shadowLightPosition;
uniform mat4 gbufferModelViewInverse;
uniform float rainStrength;
uniform bool hasSkylight;
uniform vec3 fogColor;

#ifdef ENABLE_SHADOWS
// Read by Iris to size the shadow pass.
const int shadowMapResolution = SHADOW_RESOLUTION;
const float shadowDistance = SHADOW_DISTANCE;
const float shadowDistanceRenderMul = 1.0;   // don't draw terrain beyond shadowDistance into the map
const bool shadowHardwareFiltering = true;   // shadowtex1 becomes a sampler2DShadow (free 2x2 PCF)

uniform sampler2DShadow shadowtex1;          // opaque casters only: glass and water don't shadow
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

#if SHADOW_FILTER == 1
#define SHADOW_TAPS 4
#elif SHADOW_FILTER == 2
#define SHADOW_TAPS 8
#else
#define SHADOW_TAPS 16
#endif

// Shadow lookup for a surface at 'feet' (player space, i.e. relative to the camera).
// Returns x = sunlight visibility (1 = lit), y = how much to trust it (0 = use the
// fake sky-light shadow instead). y is 0 past the map, at sunset and at night.
vec2 shadowTerm(vec3 feet, vec3 nWS) {
    if (!hasSkylight) return vec2(1.0, 0.0);
    float h = sin(sunAngle * 6.28318530718);
    float dist = length(feet);
    float w = (1.0 - smoothstep(0.45 * SHADOW_DISTANCE, 0.95 * SHADOW_DISTANCE, dist))
            * smoothstep(0.05, 0.25, h);
    if (w <= 0.0) return vec2(1.0, 0.0);

    vec3 L = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    float ndl = dot(nWS, L);
    float texel = 2.0 * SHADOW_DISTANCE / float(SHADOW_RESOLUTION);   // blocks per shadow texel
    float slope = min(sqrt(max(1.0 - ndl * ndl, 0.0)) / max(ndl, 0.15), 4.0);

    // Normal offset (kills acne on faces that graze the light) + slope-scaled depth bias.
    // One block of depth = 0.5 * |shadowProjection[2][2]| in map depth units.
    vec3 p = feet + nWS * texel * (0.8 + 1.6 * (1.0 - clamp(ndl, 0.0, 1.0)));
    vec3 sc = (shadowProjection * (shadowModelView * vec4(p, 1.0))).xyz * 0.5 + 0.5;
    sc.z -= texel * (0.4 + 0.6 * slope * SHADOW_SOFTNESS) * 0.5 * abs(shadowProjection[2][2]);

#if SHADOW_FILTER == 0
    float vis = texture(shadowtex1, sc);
#else
    // Rotated Vogel disk; per-pixel rotation trades banding for noise that
    // film grain and FXAA hide.
    float rot = 6.28318530718 * fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
    float radius = SHADOW_SOFTNESS / float(SHADOW_RESOLUTION);
    float vis = 0.0;
    for (int i = 0; i < SHADOW_TAPS; i++) {
        float a = float(i) * 2.39996323 + rot;
        float r = sqrt((float(i) + 0.5) / float(SHADOW_TAPS)) * radius;
        vis += texture(shadowtex1, vec3(sc.xy + r * vec2(cos(a), sin(a)), sc.z));
    }
    vis /= float(SHADOW_TAPS);
#endif
    return vec2(vis, w);
}
#endif

const vec3 LIGHT_LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 toLinear(vec3 c) { return pow(max(c, vec3(0.0)), vec3(2.2)); }
vec3 toGamma(vec3 c) { return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2)); }

// Highlight shoulder on linear light. Identity below HIGHLIGHT_KNEE, then an
// exponential ease toward 1.0, so a bright sun can light pale surfaces (sand,
// snow, birch) without clipping them to flat white. Scaled by the brightest
// channel so hue is kept; per-channel clipping is what turned sand grey-green.
vec3 rolloff(vec3 c) {
    float k = HIGHLIGHT_KNEE;
    float m = max(max(c.r, c.g), c.b);
    if (m <= k) return c;
    float r = 1.0 - k;
    float mapped = k + r * (1.0 - exp(-(m - k) / r));
    return c * (mapped / m);
}

// albedoGamma : texture color (display space)
// lm          : x = block light, y = sky light, both 0..1
// nWS         : surface normal in player/world orientation, normalised
// ao          : vertex ambient occlusion, 1 = open
// foliage     : 1 for leaves / grass / vines (thin, light scatters through)
// emissive    : 1 for light sources (lava, glowstone...): adds their own colour
// sh          : shadow map result from shadowTerm (x visibility, y weight);
//               pass vec2(1.0, 0.0) for "no shadow map" (ignored when shadows are off)
vec3 shadeSurface(vec3 albedoGamma, vec2 lm, vec3 nWS, float ao, float foliage, float emissive, vec2 sh) {
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
        // Foliage: a leaf block is a cloud of small cards, not a solid face.
        // Light it almost evenly from every side, at less than full sun, so
        // sunlit canopy stops clipping and the shaded side still glows.
        diff = mix(diff, 0.35 + 0.30 * diff, foliage);
        // Fake shadow from the sky-light level: open sky is 15, one leaf
        // layer or an overhang above drops it to 14 (0.935), which is shade.
        float open = smoothstep(0.92, 0.99, sky);
#ifdef ENABLE_SHADOWS
        // Real shadow where the map is trusted; the sky-light check also keeps
        // any map leak out of caves.
        open = mix(open, sh.x * smoothstep(0.15, 0.50, sky), sh.y);
#endif
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

    // ---- Self-emission: a light source shows its own colour, shade or not --
    // The emissive flag covers the whole block, so weight it per texel: bright
    // glass, flame and lava glow fully, dark metal and wood (lantern frame,
    // torch stick) stay dark and keep the contrast that makes the glow read.
    float glowMask = smoothstep(0.18, 0.45, max(max(albedo.r, albedo.g), albedo.b));
    vec3 glow = albedo * emissive * EMISSIVE_GLOW * glowMask;

    // Very pale surfaces (white wool, snow, quartz) reflect so much that sun
    // plus sky pushes every texel past the rolloff and they go flat white.
    // Pulling their sun and sky light down by up to 30% keeps their texture
    // inside the range the rolloff can still resolve. Darker albedos are
    // untouched. (Block light keeps its full strength.)
    float pale = smoothstep(0.45, 0.75, dot(albedo, LIGHT_LUMA));
    vec3 lightTotal = (direct + ambient) * (1.0 - 0.30 * pale) + block + floorLight;

    return toGamma(rolloff(albedo * lightTotal + glow));
}
