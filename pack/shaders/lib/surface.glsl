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
    vec2 sh = vec2(1.0, 0.0);
#ifdef ENABLE_SHADOWS
    if (useShadowMap) sh = shadowTerm(feet, nWS);
#endif
    vec3 rgb = shadeSurface(albedoGamma, lm, nWS, ao, foliage, emissive, sh);
#if SURFACE_SHEEN > 0
    rgb += sunSheen(nWS, feet, lm.y, sh) * (1.0 - emissive);
#endif
    return applyAtmosphere(rgb, viewPos, false);
}
