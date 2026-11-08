// The shadow map is rendered from a light that is not quite the real sun. The sun
// itself stays on its vanilla path; only the shadows are cast differently:
//
// - Yaw: turned SHADOW_YAW degrees around the vertical axis. At low sun the real
//   light runs almost along the world's axis-aligned walls, which leaves a thin
//   bright line along wall bases that no bias removes.
// - Elevation floor: never lower than SHADOW_MIN_ELEVATION degrees. A shadow is
//   1/tan(elevation) times its caster's height: 5x at 11 degrees, 11x at 5. At
//   sunset every ledge smeared a long streak down the walls below it. Held at the
//   floor, shadows stay at most ~2.5x their caster while the sun keeps setting.
//
// shadow.vsh and shadowTerm both turn the world by this matrix before using the
// shadow matrices. Turning the world by M under the real light L is the same as
// lighting the unturned world from transpose(M) * L, so M = yaw * P, where P
// tilts the raised light back down onto the yawed one.
// Needs uniform mat4 shadowModelViewInverse.
mat3 shadowYaw() {
    float a = radians(SHADOW_YAW);
    float c = cos(a), s = sin(a);
    mat3 yaw = mat3(c, 0.0, -s,
                    0.0, 1.0, 0.0,
                    s, 0.0, c);

    // Real light direction (toward the sun or moon), player space. The shadow view
    // looks down -z, so the light sits on its +z axis. Only daytime-high lights
    // matter (the map is faded out below ~3 degrees), so force it upward.
    vec3 L = normalize(shadowModelViewInverse[2].xyz);
    if (L.y < 0.0) L = -L;
    vec3 Ly = transpose(yaw) * L;              // the light as the yawed map sees it

    const float sinMin = sin(radians(SHADOW_MIN_ELEVATION));
    if (Ly.y >= sinMin) return yaw;            // high enough: yaw only

    // Raised light: same azimuth, elevation at the floor.
    vec2 hz = Ly.xz / max(length(Ly.xz), 1e-4);
    float cosMin = sqrt(1.0 - sinMin * sinMin);
    vec3 Lr = vec3(hz.x * cosMin, sinMin, hz.y * cosMin);

    // P: rotation taking Lr onto Ly (Rodrigues, shortest arc; the two are never
    // opposite, so 1 + dot > 0).
    vec3 v = cross(Lr, Ly);
    float d = dot(Lr, Ly);
    mat3 K = mat3(0.0, v.z, -v.y,
                  -v.z, 0.0, v.x,
                  v.y, -v.x, 0.0);
    mat3 P = mat3(1.0) + K + K * K / (1.0 + d);
    return yaw * P;
}

// Turn a player-space position (relative to the camera) by shadowYaw(), pivoting
// on the shadow map's own origin rather than on the camera. Iris snaps that
// origin to a world grid (shadowIntervalSize) so map texels stay fixed to the
// world while the player walks. A pivot on the camera would slide the turned
// world across the map by (1 - yaw) times every step, so every shadow edge would
// crawl over the texel grid as the player moves. Iris's shadow view has no
// pull-back, so shadowModelViewInverse[3] is exactly that origin in player space.
vec3 shadowYawPos(vec3 playerPos) {
    vec3 pivot = shadowModelViewInverse[3].xyz;
    return shadowYaw() * (playerPos - pivot) + pivot;
}
