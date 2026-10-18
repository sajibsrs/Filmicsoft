// Sky color for a view direction. The single source of truth for the sky:
// gbuffers_skybasic draws it, and fog on terrain and clouds fades toward it,
// so a fully fogged object is exactly the sky behind it (no silhouette).
// Needs uniforms skyColor, fogColor, upPosition.

vec3 skyGradient(vec3 viewDir) {
    float up = max(dot(viewDir, normalize(upPosition)), 0.0);
    // Horizon: fogColor carrying some of the sky's blue, so it reads as a
    // bluish white rather than a flat white band (sunset fog stays warm).
    vec3 horizon = mix(fogColor, skyColor, 0.35);
    // Gradual climb from the horizon to the full sky color: about halfway by
    // 10 degrees up, nearly all sky by 35.
    float t = exp(-up * 4.0);
    return mix(skyColor, horizon, t);
}
