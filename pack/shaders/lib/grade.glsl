// Colour grade shared by final.fsh (direct) and composite4.fsh (bakes a LUT).
// Needs lib/options.glsl included first. Pure function of one RGB colour.

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float hueDist(float a, float b) {
    float d = abs(a - b);
    return min(d, 1.0 - d);
}

// Soft ceiling on saturation: linear up to a knee, then eases toward `limit`.
float softLimit(float s, float limit) {
    float k = limit * 0.6;
    float r = max(limit - k, 0.0001);
    float over = max(s - k, 0.0);
    return min(s, k) + r * (1.0 - exp(-over / r));
}

// One band of the Lightroom-style HSL mixer. Called with literal slider values,
// so a band whose three sliders are all 0 is removed at compile time.
void mixerBand(float center, float dh, float ds, float dl, float hue, inout vec3 shift, inout float wSum) {
    if (dh != 0.0 || ds != 0.0 || dl != 0.0) {
        float w = max(0.0, 1.0 - hueDist(hue, center) / 0.14);
        w = w * w * (3.0 - 2.0 * w);
        shift += w * vec3(dh, ds, dl);
        wSum += w;
    }
}

// HSL mixer over 8 hue bands. Works in and returns HSV so the caller can keep
// editing without converting back and forth.
vec3 colorMixerHSV(vec3 rgb) {
    vec3 hsv = rgb2hsv(rgb);

    vec3 shift = vec3(0.0);   // x hue, y saturation, z luminance
    float wSum = 0.0;
    mixerBand(0.0000, RED_H,     RED_S,     RED_L,     hsv.x, shift, wSum);
    mixerBand(0.0833, ORANGE_H,  ORANGE_S,  ORANGE_L,  hsv.x, shift, wSum);
    mixerBand(0.1667, YELLOW_H,  YELLOW_S,  YELLOW_L,  hsv.x, shift, wSum);
    mixerBand(0.3333, GREEN_H,   GREEN_S,   GREEN_L,   hsv.x, shift, wSum);
    mixerBand(0.5000, AQUA_H,    AQUA_S,    AQUA_L,    hsv.x, shift, wSum);
    mixerBand(0.6389, BLUE_H,    BLUE_S,    BLUE_L,    hsv.x, shift, wSum);
    mixerBand(0.7500, PURPLE_H,  PURPLE_S,  PURPLE_L,  hsv.x, shift, wSum);
    mixerBand(0.9167, MAGENTA_H, MAGENTA_S, MAGENTA_L, hsv.x, shift, wSum);
    shift /= max(wSum, 1.0);

    // Greys have no meaningful hue; fade the effect out as saturation -> 0.
    float chromaMask = smoothstep(0.02, 0.15, hsv.y);

    hsv.x = fract(hsv.x + shift.x * 0.10 * chromaMask + 1.0);
    hsv.y = clamp(hsv.y * (1.0 + shift.y), 0.0, 1.0);
    hsv.z = clamp(hsv.z * (1.0 + shift.z * 0.4 * chromaMask), 0.0, 1.0);
    return hsv;
}

// Lightroom "Calibration"-style primary shifts. Rows are normalised so greys
// stay grey while the primaries rotate toward their neighbours.
vec3 calibrate(vec3 c) {
    // Copy option values into variables first: Iris pastes option values in as
    // plain text, so `-CAL_GREEN` with a default of -0.10 would become `--0.10`.
    float cr = CAL_RED;
    float cg = CAL_GREEN;
    float cb = CAL_BLUE;
    vec3 rp = vec3(1.0, max(cr, 0.0), max(-cr, 0.0));
    vec3 gp = vec3(max(-cg, 0.0), 1.0, max(cg, 0.0));
    vec3 bp = vec3(max(cb, 0.0), max(-cb, 0.0), 1.0);
    mat3 m = mat3(rp, gp, bp);
    vec3 rowSum = vec3(rp.x + gp.x + bp.x, rp.y + gp.y + bp.y, rp.z + gp.z + bp.z);
    return (m * c) / rowSum;
}

// Everything from black lift to global saturation, for a colour in 0..1.
vec3 gradeCore(vec3 col) {
    // Black lift + soft highlight shoulder (scene is display-referred, so this
    // is a gentle curve rather than a full HDR tone map).
    col = col * (1.0 - BLACK_LIFT) + vec3(BLACK_LIFT);
    col = col / (1.0 + 0.12 * col) * 1.12;

    // Contrast: blend toward a smoothstep S-curve.
    vec3 sc = clamp(col, 0.0, 1.0);
    sc = sc * sc * (3.0 - 2.0 * sc);
    col = mix(col, sc, CONTRAST * 2.0);

    // Color: primaries first, then per-band HSL mixer.
    col = clamp(calibrate(col), 0.0, 1.0);
    vec3 hsv = colorMixerHSV(col);

    // Balance intensity: lift weak colors (vibrance), then cap strong ones so
    // water and grass sit in the same saturation range.
    hsv.y = hsv.y + VIBRANCE * hsv.y * (1.0 - hsv.y);
    hsv.y = softLimit(hsv.y, CHROMA_LIMIT);
    col = hsv2rgb(hsv);

    // Split toning: cyan shadows, orange highlights.
    float luma = dot(col, LUMA);
    float shadowMask = 1.0 - smoothstep(0.0, 0.5, luma);
    float highlightMask = smoothstep(0.5, 1.0, luma);
    col += vec3(-0.030, 0.022, 0.030) * SHADOW_TINT * shadowMask;
    col += vec3(0.040, 0.018, -0.035) * HIGHLIGHT_TINT * highlightMask;

    // Global saturation.
    luma = dot(col, LUMA);
    return mix(vec3(luma), col, SATURATION);
}
