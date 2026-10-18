#version 330 compatibility

// Filmicsoft - final pass.
// glow -> tone -> calibration -> color mixer -> chroma limit -> lens -> grain.
// Strict GLSL 3.30: explicit float literals, no implicit int->float.

#include "/lib/options.glsl"

// Bloom buffers are stored in half float so dim glow doesn't band. These
// must live inside a comment: Iris reads them from the source text, and
// RGBA16F is not a real GLSL identifier.
/*
const int colortex4Format = RGBA16F;
const int colortex5Format = RGBA16F;
const int colortex6Format = RGBA16F;
const int colortex7Format = RGBA16F;
const int colortex8Format = RGBA16F;
const int colortex9Format = RGBA16F;
*/

uniform sampler2D colortex0;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex9;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Hoskins-style float-only hash: no sin(), so no precision surprises per GPU.
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Smooth value noise: bilinear blend of hashed lattice points. Because it is
// interpolated, grain comes out soft rather than per-pixel sharp.
float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float filmGrain(vec2 fragCoord) {
    // Size is relative to a 1080p screen so Retina looks like non-Retina.
    float cell = GRAIN_SIZE * viewHeight / 1080.0;
    // Pattern changes GRAIN_SPEED times per real-time second, so the look is
    // identical at 60 fps or 500 fps.
    float step24 = mod(floor(frameTimeCounter * float(GRAIN_SPEED)), 997.0);
    vec2 offset = vec2(hash12(vec2(step24, 1.7)), hash12(vec2(2.3, step24))) * 512.0;
    vec2 p = fragCoord / cell + offset;
    float n = valueNoise(p) * 0.75 + valueNoise(p * 1.6 + vec2(17.0, 5.0)) * 0.25;
    return (n - 0.5) * 3.6;
}

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

// Lightroom-style HSL mixer over 8 hue bands.
vec3 colorMixer(vec3 rgb) {
    vec3 hsv = rgb2hsv(rgb);

    const float centers[8] = float[8](0.0, 0.0833, 0.1667, 0.3333, 0.5, 0.6389, 0.75, 0.9167);
    float dH[8] = float[8](RED_H, ORANGE_H, YELLOW_H, GREEN_H, AQUA_H, BLUE_H, PURPLE_H, MAGENTA_H);
    float dS[8] = float[8](RED_S, ORANGE_S, YELLOW_S, GREEN_S, AQUA_S, BLUE_S, PURPLE_S, MAGENTA_S);
    float dL[8] = float[8](RED_L, ORANGE_L, YELLOW_L, GREEN_L, AQUA_L, BLUE_L, PURPLE_L, MAGENTA_L);

    float hueShift = 0.0;
    float satShift = 0.0;
    float lumShift = 0.0;
    float wSum = 0.0;
    for (int i = 0; i < 8; i++) {
        float w = max(0.0, 1.0 - hueDist(hsv.x, centers[i]) / 0.14);
        w = w * w * (3.0 - 2.0 * w);
        hueShift += w * dH[i];
        satShift += w * dS[i];
        lumShift += w * dL[i];
        wSum += w;
    }
    float norm = 1.0 / max(wSum, 1.0);

    // Greys have no meaningful hue; fade the effect out as saturation -> 0.
    float chromaMask = smoothstep(0.02, 0.15, hsv.y);

    hsv.x = fract(hsv.x + hueShift * norm * 0.10 * chromaMask + 1.0);
    hsv.y = clamp(hsv.y * (1.0 + satShift * norm), 0.0, 1.0);
    hsv.z = clamp(hsv.z * (1.0 + lumShift * norm * 0.4 * chromaMask), 0.0, 1.5);
    return hsv2rgb(hsv);
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

// Four diagonal taps on a coarse bloom level: smooths the blocky look of
// upsampling a tiny texture. `texel` is that level's texel size in UV space.
vec3 softTap(sampler2D tex, vec2 uv, vec2 texel) {
    vec3 s = texture(tex, uv + texel * vec2( 0.5,  0.5)).rgb;
    s     += texture(tex, uv + texel * vec2(-0.5,  0.5)).rgb;
    s     += texture(tex, uv + texel * vec2( 0.5, -0.5)).rgb;
    s     += texture(tex, uv + texel * vec2(-0.5, -0.5)).rgb;
    return s * 0.25;
}

// ---------------------------------------------------------------------------

void main() {
    vec2 uv = texcoord;
    vec2 fromCenter = uv - vec2(0.5);
    vec2 px = vec2(1.0 / viewWidth, 1.0 / viewHeight);

    // Lens fringe: red/blue sampled slightly apart, growing toward the edges.
    float fringe = CHROMA_FRINGE * 0.004 * dot(fromCenter, fromCenter) * 4.0;
    vec3 col;
    col.r = texture(colortex0, uv + fromCenter * fringe * 8.0).r;
    col.g = texture(colortex0, uv).g;
    col.b = texture(colortex0, uv - fromCenter * fringe * 8.0).b;

    // Diffusion: blend a heavily blurred copy for a soft, filmic look.
    vec3 diffuse = softTap(colortex9, uv, px * 4.0);
    col = mix(col, diffuse, DIFFUSION);

    // Bloom: weighted sum of the downsample chain (1/2 ... 1/32 res).
    vec3 bloom = softTap(colortex4, uv, px * 2.0) * 0.22;
    bloom     += softTap(colortex5, uv, px * 4.0) * 0.24;
    bloom     += softTap(colortex6, uv, px * 8.0) * 0.22;
    bloom     += softTap(colortex7, uv, px * 16.0) * 0.18;
    bloom     += softTap(colortex8, uv, px * 32.0) * 0.14;
    col += bloom * BLOOM_STRENGTH;

    col *= EXPOSURE;

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
    col = colorMixer(col);

    // Balance intensity: lift weak colors (vibrance), then cap strong ones so
    // water and grass sit in the same saturation range.
    vec3 hsv = rgb2hsv(clamp(col, 0.0, 1.0));
    hsv.y = hsv.y + VIBRANCE * hsv.y * (1.0 - hsv.y);
    hsv.y = softLimit(hsv.y, CHROMA_LIMIT);
    col = hsv2rgb(hsv);

    // Split toning: cool/teal shadows, warm highlights.
    float luma = dot(col, LUMA);
    float shadowMask = 1.0 - smoothstep(0.0, 0.5, luma);
    float highlightMask = smoothstep(0.5, 1.0, luma);
    col += vec3(-0.020, 0.012, 0.030) * SHADOW_TINT * shadowMask;
    col += vec3(0.030, 0.014, -0.025) * HIGHLIGHT_TINT * highlightMask;

    // Global saturation.
    luma = dot(col, LUMA);
    col = mix(vec3(luma), col, SATURATION);

    // Vignette.
    float vig = smoothstep(0.85, 0.25, length(fromCenter) * 1.15);
    col *= mix(1.0, vig, VIGNETTE);

    // Film grain: soft, larger, strongest in midtones.
    luma = clamp(dot(col, LUMA), 0.0, 1.0);
    float grainMask = 4.0 * luma * (1.0 - luma) * 0.8 + 0.2;
    col += filmGrain(gl_FragCoord.xy) * GRAIN_AMOUNT * grainMask;

    outColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
