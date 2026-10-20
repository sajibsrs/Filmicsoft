#version 330 compatibility

// Translucent terrain (water, stained glass, ice). Lit directly with the same
// model as opaque surfaces, minus the shadow map (it holds opaque casters only).

#include "/lib/options.glsl"
#include "/lib/lighting.glsl"
#include "/lib/fog.glsl"

/* RENDERTARGETS: 0 */

uniform sampler2D gtexture;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;
in vec3 viewPos;
flat in int isWater;

layout(location = 0) out vec4 outColor;

#ifdef ENABLE_WATER_RIPPLES
// Wind ripples: every 1/4-block cell (4x4 water-texture pixels) gets its own
// small random tilt that slowly changes, and the whole pattern drifts with the
// wind. Blocky like vanilla's own water animation, with no long smooth waves
// (those read as HD-ocean stripes, not Minecraft).
vec2 rippleSlope(vec2 xz) {
    float t = frameTimeCounter;
    vec2 cell = floor((xz + vec2(0.31, 0.19) * t) * 4.0);    // 4x4 texture pixels per cell; drift with the wind
    // One cheap hash per cell gives each cell its own phase; two detuned sines
    // then rock its tilt back and forth. (Interleaved gradient noise was tried
    // here: on a regular grid it shows as a diagonal mosaic.) The mod keeps
    // the sin argument small, so it stays precise far from the world origin.
    vec2 c = mod(cell, 256.0);
    float r = fract(sin(dot(c, vec2(127.1, 311.7))) * 43758.5453);
    return vec2(sin(t * 1.1 + r * 6.2832), sin(t * 1.43 + r * 25.13)) * 0.045;
}
#endif

void main() {
    vec4 tex = texture(gtexture, texcoord);
    // Terrain programs carry vertex AO in glcolor.a (separateAo=true).
    vec3 lit = shadeSurface(tex.rgb * glcolor.rgb, clamp(lmcoord, 0.0, 1.0),
                            normalize(normal), glcolor.a, 0.0, 0.0, vec2(1.0, 0.0));
    float alpha = tex.a;

    // Water mirrors the sky above it, more at grazing angles (Fresnel). The
    // reflected sky is the same gradient the sky is drawn with, so sunsets and
    // storms show up on lakes for free. Top faces under open sky only: covered
    // water and caves have no sky to reflect.
    vec3 nWS = normalize(normal);
    if (isWater == 1 && hasSkylight && nWS.y > 0.5) {
        vec3 V = normalize(viewPos);
#ifdef ENABLE_WATER_RIPPLES
        // Tilt only the reflection normal; the surface itself stays flat.
        // Far water fades to calm so the ripples don't alias into noise;
        // rain and wind gusts make it choppier.
        float dist = length(viewPos);
        vec3 wp = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz + cameraPosition;
        float calm = 1.0 - smoothstep(12.0, 40.0, dist);
        vec2 g = rippleSlope(wp.xz) * calm * (1.0 + rainStrength);
        nWS = normalize(vec3(-g.x, 1.0, -g.y));
#endif
        // Everything below works in player space, where up is +y.
        vec3 Vp = mat3(gbufferModelViewInverse) * V;
        float c = 1.0 - clamp(dot(nWS, -Vp), 0.0, 1.0);
        float c2 = c * c;
        float fres = 0.04 + 0.96 * c2 * c2 * c;   // Schlick Fresnel
        float open = smoothstep(0.70, 0.95, lmcoord.y);
        // Ripples tilt the surface every which way, so rough water reflects
        // mostly the sky near the horizon, not the zenith a flat mirror would
        // show. Flatten the reflected ray.
        vec3 R = reflect(Vp, nWS);
        R.y *= 0.35;
        R = normalize(R);
        float up = max(R.y, 0.0);
        // Cheap sky: the plain horizon-to-zenith gradient of lib/sky.glsl,
        // without the scattering terms (they hardly show in a rippled
        // reflection), plus its thunder floor so storm water matches the fog.
        vec3 horizon = mix(fogColor, skyColor, 0.60);
        vec3 sky = mix(skyColor, horizon, exp(-up * 2.5))
                 + vec3(0.050, 0.058, 0.075) * thunderStrength * RAIN_MOOD;
        // Sunrise / sunset: vanilla's orange fan is drawn on top of the sky,
        // so it isn't in the gradient. Add a soft warm tint where the
        // reflection looks toward the low sun, and only there.
        float h = sin(sunAngle * 6.28318530718);
        float lowSun = (1.0 - smoothstep(0.02, 0.50, h)) * smoothstep(-0.10, 0.20, h);
        if (lowSun > 0.0) {
            vec3 sunP = normalize(mat3(gbufferModelViewInverse) * sunPosition);
            float sd = dot(R, sunP) * 0.5 + 0.5;
            float sd2 = sd * sd;
            float band = sd2 * sd2 * sd * (1.0 - up) * lowSun * (1.0 - rainStrength);
            sky = mix(sky, sky * vec3(1.45, 0.95, 0.70), band * 0.6);   // warm the sky colour, don't paint orange
        }
        float k = clamp(fres * open, 0.0, 0.85);
        lit = mix(lit, sky, k);
        alpha = mix(alpha, 1.0, k);   // a mirror is opaque where it reflects
    }
    outColor = vec4(applyAtmosphere(lit, viewPos, false), alpha);
}
