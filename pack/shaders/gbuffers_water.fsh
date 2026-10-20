#version 330 compatibility

// Translucent terrain (water, stained glass, ice). Lit directly with the same
// model as opaque surfaces, minus the shadow map (it holds opaque casters only).

#include "/lib/options.glsl"
#include "/lib/lighting.glsl"
#include "/lib/fog.glsl"

/* RENDERTARGETS: 0 */

uniform sampler2D gtexture;

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;
in vec3 viewPos;
flat in int isWater;

layout(location = 0) out vec4 outColor;

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
        vec3 nVS = transpose(mat3(gbufferModelViewInverse)) * nWS;   // player -> view (orthonormal)
        float fres = 0.04 + 0.96 * pow(1.0 - clamp(dot(nVS, -V), 0.0, 1.0), 5.0);
        float open = smoothstep(0.70, 0.95, lmcoord.y);
        // Ripples tilt the surface every which way, so rough water reflects
        // mostly the sky near the horizon (where the sunset colour is), not
        // the zenith a flat mirror would show. Flatten the reflected ray.
        vec3 R = mat3(gbufferModelViewInverse) * reflect(V, nVS);
        R.y *= 0.35;
        vec3 Rv = transpose(mat3(gbufferModelViewInverse)) * normalize(R);
        vec3 sky = skyGradient(Rv);
        // The orange sunset band is vanilla's sunset fan, drawn on top of the
        // sky (gbuffers_skybasic), not part of skyGradient. Rebuild a soft
        // version for the reflection: low on the horizon, on the sun's side.
        float h = sin(sunAngle * 6.28318530718);
        float lowSun = (1.0 - smoothstep(0.02, 0.50, h)) * smoothstep(-0.10, 0.20, h);
        if (lowSun > 0.0) {
            vec3 sunV = normalize(sunPosition);
            float sd = dot(Rv, sunV) * 0.5 + 0.5;
            float up = max(dot(Rv, normalize(upPosition)), 0.0);
            float band = pow(sd, 2.5) * exp(-up * 3.0) * lowSun * (1.0 - rainStrength);
            sky = mix(sky, vec3(1.00, 0.48, 0.18), clamp(band * 1.3, 0.0, 0.90));
        }
        float k = clamp(fres * open, 0.0, 0.85);
        lit = mix(lit, sky, k);
        alpha = mix(alpha, 1.0, k);   // a mirror is opaque where it reflects
    }
    outColor = vec4(applyAtmosphere(lit, viewPos, false), alpha);
}
