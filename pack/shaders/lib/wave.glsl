// Subtle wind sway for leaves, vines and grass plants (ENABLE_WAVING).
// Shared by the terrain pass and the shadow pass, so shadows move with the
// plants. Works in world space (player space + cameraPosition), so the motion
// is fixed to the world and does not slide as the camera moves.

uniform float frameTimeCounter;
uniform float rainStrength;
uniform vec3 cameraPosition;

in vec2 mc_midTexCoord;   // texture centre of the quad: tells top vertices from bottom ones

// Offset in blocks for a vertex at world position wp. id is the block id from
// block.properties; uv is the vertex texture coordinate.
vec3 waveOffset(vec3 wp, int id, vec2 uv) {
    float amp;
    if (id == 10003) {
        // Grass plants: roots stay put, only the top edge of the quad moves.
        if (uv.y >= mc_midTexCoord.y) return vec3(0.0);
        amp = 0.045;
    } else if (id == 10001) {
        amp = 0.030;      // leaves and vines: a faint shiver of the whole block
    } else {
        return vec3(0.0);
    }

    float t = frameTimeCounter;
    // Phase varies across the world so neighbours are not in lockstep; two
    // detuned sines per axis avoid an obvious metronome.
    float ph = dot(wp.xz, vec2(0.61, 0.43)) + wp.y * 0.27;
    // Slow gusts roll across the landscape.
    float gust = 0.55 + 0.45 * sin(t * 0.37 + wp.x * 0.045 + wp.z * 0.031);
    vec3 o;
    o.x = sin(t * 1.55 + ph) * 0.65 + sin(t * 2.85 + ph * 1.7) * 0.35;
    o.z = sin(t * 1.25 + ph * 1.3 + 1.7) * 0.65 + sin(t * 3.30 + ph * 0.7) * 0.35;
    o.y = id == 10001 ? sin(t * 2.10 + ph * 1.1) * 0.3 : 0.0;
    return o * amp * gust * (1.0 + rainStrength) * WAVING_STRENGTH;
}
