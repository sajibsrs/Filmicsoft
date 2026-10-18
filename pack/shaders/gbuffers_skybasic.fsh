#version 330 compatibility

// Sky dome. Vanilla draws a flat sky plane and relies on its fog to blend it
// into the horizon; Iris removes that fog, which leaves a hard pale band where
// the clear color shows through. Rebuild the gradient per pixel instead.

/* RENDERTARGETS: 0 */

uniform mat4 gbufferProjectionInverse;
uniform vec3 skyColor;
uniform vec3 fogColor;
uniform vec3 upPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform int renderStage;

#include "/lib/sky.glsl"

in vec4 glcolor;

layout(location = 0) out vec4 outColor;

void main() {
    // Sunrise/sunset glow is a vertex-colored fan: draw it as vanilla does.
    if (renderStage == MC_RENDER_STAGE_SUNSET) {
        outColor = glcolor;
        return;
    }
    // Stars: their vertex color is not a usable brightness here, so fade them
    // in only as the sky gets dark (and out in rain).
    if (renderStage == MC_RENDER_STAGE_STARS) {
        float skyLum = dot(skyColor, vec3(0.2126, 0.7152, 0.0722));
        float a = (1.0 - smoothstep(0.02, 0.15, skyLum)) * (1.0 - rainStrength);
        if (a <= 0.0) discard;
        outColor = vec4(vec3(1.0), a);
        return;
    }

    vec4 p = gbufferProjectionInverse *
             vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0, 1.0, 1.0);
    outColor = vec4(skyGradient(normalize(p.xyz / p.w)), 1.0);
}
