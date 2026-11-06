// The shadow map is rendered from a light turned SHADOW_YAW degrees around the
// vertical axis away from the real sun. The sun itself stays on its vanilla path;
// only the shadows are cast from a slightly different azimuth. At low sun the real
// light runs almost along the world's axis-aligned walls, which leaves a thin
// bright line along wall bases that no bias removes. shadow.vsh and shadowTerm
// both turn the world by this matrix before using the shadow matrices.
mat3 shadowYaw() {
    float a = radians(SHADOW_YAW);
    float c = cos(a), s = sin(a);
    return mat3(c, 0.0, -s,
                0.0, 1.0, 0.0,
                s, 0.0, c);
}

// Turn a player-space position (relative to the camera) by shadowYaw(), pivoting
// on the shadow map's own origin rather than on the camera. Iris snaps that
// origin to a world grid (shadowIntervalSize) so map texels stay fixed to the
// world while the player walks. A pivot on the camera would slide the turned
// world across the map by (1 - yaw) times every step, so every shadow edge would
// crawl over the texel grid as the player moves. Iris's shadow view has no
// pull-back, so shadowModelViewInverse[3] is exactly that origin in player space.
// Needs uniform mat4 shadowModelViewInverse.
vec3 shadowYawPos(vec3 playerPos) {
    vec3 pivot = shadowModelViewInverse[3].xyz;
    return shadowYaw() * (playerPos - pivot) + pivot;
}
