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
