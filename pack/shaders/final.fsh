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
const int colortex9Format = RGBA16F;
*/

uniform sampler2D noisetex;      // Iris built-in 256x256 white noise
uniform sampler2D colortex0;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex9;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
uniform vec3 fogColor;
uniform vec3 sunPosition;
uniform float sunAngle;
uniform float far;
uniform float rainStrength;
uniform float blindness;
uniform int isEyeInWater;
uniform bool hasSkylight;
uniform ivec2 eyeBrightnessSmooth;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Hoskins-style float-only hash, used only for the per-step grain offset.
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// One lattice value from the built-in white-noise texture. Wrapping is done
// by hand so this does not depend on the texture's filter or wrap state.
float noiseAt(ivec2 c) {
    return texelFetch(noisetex, c & 255, 0).r;
}

// Smooth value noise: bilinear blend of four lattice values. Interpolated, so
// grain comes out soft rather than per-pixel sharp.
float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    ivec2 c = ivec2(i);
    float a = noiseAt(c);
    float b = noiseAt(c + ivec2(1, 0));
    float cc = noiseAt(c + ivec2(0, 1));
    float d = noiseAt(c + ivec2(1, 1));
    return mix(mix(a, b, f.x), mix(cc, d, f.x), f.y);
}

float filmGrain(vec2 fragCoord) {
    // Size is relative to a 1080p screen so Retina looks like non-Retina.
    float cell = GRAIN_SIZE * viewHeight / 1080.0;
    // Pattern changes GRAIN_SPEED times per real-time second, so the look is
    // identical at 60 fps or 500 fps.
    float step24 = mod(floor(frameTimeCounter * float(GRAIN_SPEED)), 997.0);
    vec2 offset = vec2(hash12(vec2(step24, 1.7)), hash12(vec2(2.3, step24))) * 256.0;
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

// Bloom levels are already blurred, so the coarser they are the fewer taps
// they need to hide the blockiness of upsampling. `texel` is the level's texel
// size in UV space.
vec3 tap4(sampler2D tex, vec2 uv, vec2 texel) {
    vec3 s = texture(tex, uv + texel * vec2( 0.5,  0.5)).rgb;
    s     += texture(tex, uv + texel * vec2(-0.5,  0.5)).rgb;
    s     += texture(tex, uv + texel * vec2( 0.5, -0.5)).rgb;
    s     += texture(tex, uv + texel * vec2(-0.5, -0.5)).rgb;
    return s * 0.25;
}

vec3 tap2(sampler2D tex, vec2 uv, vec2 texel) {
    return (texture(tex, uv + texel * vec2( 0.5,  0.5)).rgb +
            texture(tex, uv + texel * vec2(-0.5, -0.5)).rgb) * 0.5;
}

// Atmosphere: distance haze toward the sky color, a warm glow toward the sun,
// and the water / lava / blindness fog vanilla would normally draw. Done here
// instead of in its own pass: that saves a full-screen read + write of the
// scene, which is the real cost on a bandwidth-bound GPU.
vec3 applyAtmosphere(vec3 c, vec2 uv) {
    float depth = texture(depthtex0, uv).r;
    vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
    vec4 v = gbufferProjectionInverse * vec4(ndc, 1.0);
    vec3 viewPos = v.xyz / v.w;
    float dist = length(viewPos);
    bool isSky = depth >= 1.0;

    // How much sky the camera can see (caves -> 0). Dimensions without sky
    // (Nether, End) keep their fog color at full strength.
    float skyEye = hasSkylight ? clamp(float(eyeBrightnessSmooth.y) / 240.0, 0.0, 1.0) : 1.0;

    float h = sin(sunAngle * 6.28318530718);
    float dayAmt = smoothstep(-0.10, 0.20, h);
    float warm = (1.0 - smoothstep(0.02, 0.50, h)) * dayAmt;

    vec3 fogCol = fogColor;
    float fogAmt = 0.0;

    if (isEyeInWater == 1) {
        fogAmt = 1.0 - exp(-dist * 0.035);
    } else if (isEyeInWater == 2) {
        fogAmt = 1.0 - exp(-dist * 0.45);
    } else if (!isSky) {
        float weatherBoost = 1.0 + rainStrength * 2.0;
        float haze = 1.0 - exp(-dist * 0.43 / max(far, 32.0) * HAZE_AMOUNT * weatherBoost);
        haze *= skyEye;
        // Fade the last stretch fully to fog so the chunk border never shows.
        float edge = smoothstep(far * 0.75, far * 0.98, dist);
        fogAmt = max(haze, edge);

        if (hasSkylight) {
            float sd = max(dot(viewPos / max(dist, 0.0001), normalize(sunPosition)), 0.0);
            vec3 glow = mix(vec3(1.00, 0.90, 0.70), vec3(1.00, 0.50, 0.20), warm);
            fogCol += glow * pow(sd, 5.0) * HAZE_SUN_GLOW * 0.5 * dayAmt * skyEye * (1.0 - rainStrength);
        }
        fogCol *= mix(0.10, 1.0, skyEye);
    }

    if (blindness > 0.0) {
        fogAmt = max(fogAmt, 1.0 - exp(-dist * 0.35 * blindness));
        fogCol = mix(fogCol, vec3(0.0), blindness);
    }

    return mix(c, fogCol, clamp(fogAmt, 0.0, 1.0));
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
    vec3 diffuse = texture(colortex9, uv).rgb;   // very soft already: one tap
    col = mix(col, diffuse, DIFFUSION);

    // Atmosphere (haze / sun glow / fluid fog) before bloom is added back.
    col = applyAtmosphere(col, uv);

    // Bloom: weighted sum of three levels (1/2, 1/8, 1/32 res).
    vec3 bloom = tap4(colortex4, uv, px * 2.0) * 0.30;
    bloom     += tap2(colortex5, uv, px * 8.0) * 0.40;
    bloom     += texture(colortex6, uv).rgb * 0.30;
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
