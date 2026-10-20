// Forward shading for opaque geometry: lighting, shadow map, sun sheen and
// atmosphere for one surface, right where it is drawn. There is no deferred
// pass: on Apple GPUs a full-screen pass between the opaque and translucent
// geometry cost ~1.2 ms on its own (the scene is stored to memory and loaded
// back), far more than the lighting math.
// Include after lib/options.glsl, lib/lighting.glsl and lib/fog.glsl.

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
    return applyAtmosphere(rgb, viewPos, false);
}
