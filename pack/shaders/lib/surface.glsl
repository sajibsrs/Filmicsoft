// Forward shading for opaque geometry: lighting, shadow map, sun sheen and
// atmosphere for one surface, right where it is drawn. There is no deferred
// pass: on Apple GPUs a full-screen pass between the opaque and translucent
// geometry cost ~1.2 ms on its own (the scene is stored to memory and loaded
// back), far more than the lighting math.
// Include after lib/options.glsl, lib/lighting.glsl and lib/fog.glsl.

uniform vec3 cameraPosition;
uniform float frameTimeCounter;

// viewPos      : view-space position of the surface
// useShadowMap : false for the hand, whose view space is not the world's
vec3 litSurface(vec3 albedoGamma, vec2 lm, vec3 nWS, float ao, float foliage, float emissive,
                vec3 viewPos, bool useShadowMap) {
    vec3 feet = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

    // Rain: open, upward-facing surfaces get wet. Wet ground is darker (water
    // fills the pores) and mirrors a little of the grey sky at grazing angles.
    // Sky light 15 only, so roofs and tree cover keep the ground under them dry.
    float wet = 0.0;
    if (hasSkylight && useShadowMap) {
        wet = rainStrength * RAIN_MOOD * smoothstep(0.90, 0.97, lm.y)
            * smoothstep(0.5, 0.9, nWS.y) * (1.0 - emissive);
        wet = clamp(wet, 0.0, 1.0);
        albedoGamma *= 1.0 - 0.30 * wet;
    }

    vec2 sh = vec2(1.0, 0.0);
#ifdef ENABLE_SHADOWS
    if (useShadowMap) sh = shadowTerm(feet, nWS);
#endif
    vec3 rgb = shadeSurface(albedoGamma, lm, nWS, ao, foliage, emissive, sh);
#if SURFACE_SHEEN > 0
    rgb += sunSheen(nWS, feet, lm.y, sh) * (1.0 - emissive);
#endif
    if (wet > 0.0) {
        // View rotation is orthonormal, so its inverse is the transpose: this
        // takes the world-space reflection back to view space for skyGradient.
        vec3 V = normalize(feet);
        vec3 R = transpose(mat3(gbufferModelViewInverse)) * reflect(V, nWS);
        float fres = pow(1.0 - clamp(dot(nWS, -V), 0.0, 1.0), 4.0);
        rgb = mix(rgb, skyGradient(normalize(R)), fres * 0.45 * wet);
    }
    // Underwater caustics: sunlight focused by the surface waves above paints a
    // drifting web of light on whatever is below. Blocky (1/4-block cells) to
    // match the pixel look; only where sky light still reaches (it drops with
    // depth), by day, and not on the hand.
#ifdef ENABLE_CAUSTICS
    if (isEyeInWater == 1 && hasSkylight && useShadowMap) {
        float h = sin(sunAngle * 6.28318530718);
        // Sky light falls about a level per block of water, so a seabed a few
        // blocks down is already well below 0.9: the gate starts low.
        float lit = smoothstep(0.10, 0.60, lm.y) * smoothstep(0.0, 0.30, h)
                  * mix(1.0, sh.x, sh.y)                    // not inside a shadow
                  * (0.35 + 0.65 * clamp(nWS.y, 0.0, 1.0)) * (1.0 - emissive);
        if (lit > 0.0) {
            vec3 q = floor((feet + cameraPosition) * 4.0) * 0.25 * 1.1;
            float t = frameTimeCounter;
            float a = sin(q.x + t * 0.9 + sin(q.z * 1.3 + t * 0.7 + q.y * 0.5));
            float b = sin(q.z * 1.2 - t * 0.8 + sin(q.x * 1.1 - t * 0.6 + q.y * 0.5));
            float web = pow(1.0 - abs(a), 3.0) + pow(1.0 - abs(b), 3.0);
            rgb += vec3(0.50, 0.85, 1.00) * web * lit * 0.22;
        }
    }
#endif
    return applyAtmosphere(rgb, viewPos, false);
}
