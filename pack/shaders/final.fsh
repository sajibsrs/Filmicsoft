#version 330 compatibility

// Filmicsoft - final pass.
// glow -> tone -> calibration -> color mixer -> chroma limit -> lens -> grain.
// Strict GLSL 3.30: explicit float literals, no implicit int->float.

#include "/lib/options.glsl"
#include "/lib/grade.glsl"

// Bloom buffers are stored in half float so dim glow doesn't band. These
// must live inside a comment: Iris reads them from the source text, and
// RGBA16F is not a real GLSL identifier. The bloom buffers are fully
// rewritten every frame, so Iris need not clear them first.
/*
const int colortex4Format = RGBA16F;
const int colortex5Format = RGBA16F;
const int colortex9Format = RGBA16F;
const int colortex11Format = RGBA16F;
const bool colortex4Clear = false;
const bool colortex5Clear = false;
const bool colortex9Clear = false;
const bool colortex10Clear = false;
const bool colortex11Clear = false;
*/

uniform sampler2D noisetex;      // Iris built-in 256x256 white noise
uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform mat4 gbufferProjectionInverse;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex9;
uniform sampler2D colortex11;    // god rays (half res, tinted and scaled in composite1)
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform ivec2 eyeBrightnessSmooth;   // y = sky light at the camera (0 indoors / caves)

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

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
    // One layer instead of two: the 0.25-weight fine layer was barely
    // visible. Scaled by 0.8 to keep the old layered strength.
    float n = valueNoise(p);
    return (n - 0.5) * 2.85;
}

#ifdef ENABLE_FXAA
// FXAA (Lottes, console variant): find the edge direction from the four
// corner lumas and blur along it. Flat areas return after four extra taps.
// `centre` is the raw centre pixel, so callers can add per-channel offsets
// (lens fringe) without losing the smoothing.
vec3 fxaa(vec2 uv, vec2 px, out vec3 centre) {
    centre = texture(colortex0, uv).rgb;
    float lM = dot(centre, LUMA);
    float lNW = dot(texture(colortex0, uv + vec2(-1.0, -1.0) * px).rgb, LUMA);
    float lNE = dot(texture(colortex0, uv + vec2( 1.0, -1.0) * px).rgb, LUMA);
    float lSW = dot(texture(colortex0, uv + vec2(-1.0,  1.0) * px).rgb, LUMA);
    float lSE = dot(texture(colortex0, uv + vec2( 1.0,  1.0) * px).rgb, LUMA);
    float lMin = min(lM, min(min(lNW, lNE), min(lSW, lSE)));
    float lMax = max(lM, max(max(lNW, lNE), max(lSW, lSE)));
    if (lMax - lMin < max(0.04, lMax * 0.125)) return centre;   // not an edge

    vec2 dir = vec2(-((lNW + lNE) - (lSW + lSE)), (lNW + lSW) - (lNE + lSE));
    float reduce = max((lNW + lNE + lSW + lSE) * 0.25 * 0.125, 1.0 / 128.0);
    dir = clamp(dir / (min(abs(dir.x), abs(dir.y)) + reduce), vec2(-8.0), vec2(8.0)) * px;

    vec3 a = 0.5 * (texture(colortex0, uv + dir * (1.0 / 3.0 - 0.5)).rgb +
                    texture(colortex0, uv + dir * (2.0 / 3.0 - 0.5)).rgb);
    vec3 b = a * 0.5 + 0.25 * (texture(colortex0, uv + dir * -0.5).rgb +
                               texture(colortex0, uv + dir *  0.5).rgb);
    float lB = dot(b, LUMA);
    return (lB < lMin || lB > lMax) ? a : b;
}
#endif

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

// ---------------------------------------------------------------------------

void main() {
    vec2 uv = texcoord;
    vec2 fromCenter = uv - vec2(0.5);
    vec2 px = vec2(1.0 / viewWidth, 1.0 / viewHeight);

    // Lens fringe: red/blue sampled slightly apart, growing toward the edges.
    // At the default 0.05 the corners split by ~1 px at 1080p (was ~2.5 px,
    // which smeared edges and read as lens warping); ~5 px at the max 0.40.
    float fringe = CHROMA_FRINGE * 0.004 * dot(fromCenter, fromCenter) * 4.0;
    vec3 col;
    vec3 rawR = texture(colortex0, uv + fromCenter * fringe * 3.0).rgb;
    vec3 rawB = texture(colortex0, uv - fromCenter * fringe * 3.0).rgb;
#ifdef ENABLE_FXAA
    vec3 centre;
    col = fxaa(uv, px, centre);
    col.r += rawR.r - centre.r;
    col.b += rawB.b - centre.b;
#else
    col = vec3(rawR.r, texture(colortex0, uv).g, rawB.b);
#endif

    // Diffusion: blend a heavily blurred copy for a soft, filmic look.
#ifdef ENABLE_DIFFUSION
    vec3 diffuse = texture(colortex9, uv).rgb;   // very soft already: one tap
    col = mix(col, diffuse, DIFFUSION);
#endif

    // Bloom: weighted sum of two levels (1/2 and 1/8 res, the wide one tapped with a wide spread).
#ifdef ENABLE_BLOOM
    vec3 bloom = tap4(colortex4, uv, px * 2.0) * 0.30;
    bloom     += tap4(colortex5, uv, px * 24.0) * 0.70;
    bloom *= BLOOM_STRENGTH;
    // Nearby terrain gets less bloom the closer it already is to white, so
    // sunlit sand and stone at your feet are not pushed into the clamp. Three
    // zones by distance: close (under 1 chunk) is capped hardest, near (to 2
    // chunks) holds a lighter cap, and past 3 the cap settles at a light trim
    // because far away the haze reads right. Close to near is a short blend
    // (12-20 blocks) so near keeps its own plateau; near to far fades over 32-48.
    // Sky (depth 1) keeps the plain glow.
    float depth = texture(depthtex0, uv).r;
    float headroom = 1.0;
    if (depth < 1.0) {
        // Only bright surfaces are capped; grass, dirt and shade keep full bloom
        // (capping them too made the ground read dark and muted).
        float luma = dot(col * EXPOSURE, LUMA);
        float bright = smoothstep(0.30, 0.80, luma);
        headroom = mix(1.0, 0.90, bright);   // far terrain: a light trim so distant dunes are not near-white
        vec4 vp = gbufferProjectionInverse * vec4(vec3(uv, depth) * 2.0 - 1.0, 1.0);
        float dist = length(vp.xyz / vp.w);
        float near = 1.0 - smoothstep(32.0, 48.0, dist);
        float closeW = 1.0 - smoothstep(12.0, 20.0, dist);
        float cap = mix(mix(0.60, 0.35, closeW), 1.0, clamp(1.0 - luma, 0.0, 1.0));
        headroom = mix(headroom, mix(1.0, cap, bright), near);
    }
    col += bloom * headroom;
#endif

    // God rays: already tinted and scaled, so a single bilinear upsample.
    // Screen blend, so bright sky by the sun approaches white instead of clipping.
#ifdef ENABLE_GODRAYS
    col += texture(colortex11, uv).rgb * max(1.0 - col, 0.0);
#endif

    float luma;
    col = clamp(col * EXPOSURE, 0.0, 1.0);

    // Rain mood: overcast light is flat and cool. Only while the camera is
    // under open sky, so a house or cave in a storm keeps its warm look.
    float rainMood = rainStrength * RAIN_MOOD * clamp(float(eyeBrightnessSmooth.y) / 240.0, 0.0, 1.0);
    if (rainMood > 0.0) {
        luma = dot(col, LUMA);
        // Mostly a grey-out; only a hint of cool. Vanilla's rain fog and sky are
        // already blue-grey, so a strong tint on top reads as a blue filter.
        col = mix(col, vec3(luma), clamp(0.35 * rainMood, 0.0, 0.6));
        col *= mix(vec3(1.0), vec3(0.985, 0.995, 1.01), clamp(rainMood, 0.0, 1.5));
        col *= 1.0 - 0.04 * rainMood;
    }
    col = gradeCore(clamp(col, 0.0, 1.0));

    // Vignette.
    float vig = smoothstep(0.85, 0.25, length(fromCenter) * 1.15);
    col *= mix(1.0, vig, VIGNETTE);

    // Film grain: soft, larger, strongest in midtones.
#ifdef ENABLE_GRAIN
    luma = clamp(dot(col, LUMA), 0.0, 1.0);
    float grainMask = 4.0 * luma * (1.0 - luma) * 0.8 + 0.2;
    col += filmGrain(gl_FragCoord.xy) * GRAIN_AMOUNT * grainMask;
#endif

    outColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
