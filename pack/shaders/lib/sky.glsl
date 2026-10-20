// Sky color for a view direction. The single source of truth for the sky:
// gbuffers_skybasic draws it, and fog on terrain and clouds fades toward it,
// so a fully fogged object is exactly the sky behind it (no silhouette).
// Needs uniforms skyColor, fogColor, upPosition, sunPosition, sunAngle,
// rainStrength, hasSkylight.

vec3 skyGradient(vec3 viewDir) {
    float up = max(dot(viewDir, normalize(upPosition)), 0.0);
    // Horizon: fogColor carrying some of the sky's blue, so it reads as a
    // bluish white rather than a flat white band (sunset fog stays warm).
    vec3 horizon = mix(fogColor, skyColor, 0.60);
    // Gradual climb from the horizon to the full sky color, spread wide enough
    // that the pale horizon never reads as a separate band.
    float t = exp(-up * 2.5);
    vec3 sky = mix(skyColor, horizon, t);

    // Scattering look (SKY_SCATTER, 0 = plain gradient above). Overworld only;
    // rain flattens it back to the plain gradient.
    if (hasSkylight) {
        float h = sin(sunAngle * 6.28318530718);
        float dayAmt = smoothstep(-0.10, 0.20, h);
        float lowSun = (1.0 - smoothstep(0.02, 0.50, h)) * dayAmt;   // sunrise / sunset
        float k = SKY_SCATTER * (1.0 - rainStrength);

        // Rayleigh: the zenith is a deeper, more saturated blue than the
        // horizon, which the vanilla sky color alone does not give.
        float zenith = smoothstep(0.30, 1.00, up);
        sky = mix(sky, sky * vec3(0.82, 0.92, 1.08), zenith * 0.60 * k * dayAmt);

        // Mie: a broad bright, warm lobe around the sun, strongest low in the
        // sky. Scaled by the sky's own brightness so it never outshines it.
        float sd = dot(viewDir, normalize(sunPosition)) * 0.5 + 0.5;  // 1 = toward the sun
        float mie = pow(sd, 8.0) * (0.35 + 0.65 * t);
        // Ease off right around the sun: the sun quad is added on top of the
        // sky, so a bright sky there would swallow the disc.
        mie *= mix(0.30, 1.0, 1.0 - smoothstep(0.985, 0.998, sd));
        vec3 warm = mix(vec3(1.00, 0.92, 0.80), vec3(1.00, 0.55, 0.28), lowSun);
        float lum = dot(sky, vec3(0.2126, 0.7152, 0.0722));
        sky += warm * lum * mie * 0.35 * k * dayAmt;

        // At sunrise / sunset the side away from the sun turns cooler.
        sky = mix(sky, sky * vec3(0.88, 0.94, 1.05), (1.0 - sd) * lowSun * 0.60 * k);
    }
    return sky;
}
