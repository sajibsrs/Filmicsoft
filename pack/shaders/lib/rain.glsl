// Shared colour for rain: the streaks (gbuffers_weather) and the splash
// particles on the ground (gbuffers_textured) both go through this, so they
// always match. Needs uniform fogColor.
// Brightness comes from the texel's strongest channel rather than its luma:
// vanilla's rain textures are saturated blue, whose luma is very low.

vec3 rainColor(vec3 texel) {
    float v = max(max(texel.r, texel.g), texel.b);
    // The overcast light around the drop (follows time of day, dark at night),
    // mostly grey, then a slight cool lean so it still reads as water.
    float fogLum = dot(fogColor, vec3(0.2126, 0.7152, 0.0722));
    vec3 light = mix(vec3(fogLum), fogColor, 0.25) * vec3(0.84, 0.94, 1.20);
    // Floor: in a thunderstorm fogColor goes nearly black, so drops coloured
    // from it alone sink into the dark sky. A small fixed cool-grey keeps them
    // a step brighter than the background whatever the light does.
    return v * (light * 1.4 + vec3(0.050, 0.058, 0.075));
}
