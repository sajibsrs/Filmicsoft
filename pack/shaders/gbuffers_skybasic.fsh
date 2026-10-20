#version 330 compatibility

// Sky dome. Vanilla draws a flat sky plane and relies on its fog to blend it
// into the horizon; Iris removes that fog, which leaves a hard pale band where
// the clear color shows through. Rebuild the gradient per pixel instead.
// Underwater, in lava and when blind the sky takes that fog (lib/fog.glsl).

/* RENDERTARGETS: 0 */

#include "/lib/options.glsl"
#include "/lib/lighting.glsl"
#include "/lib/fog.glsl"

uniform mat4 gbufferProjectionInverse;
uniform float viewWidth;
uniform float viewHeight;
uniform int renderStage;

in vec4 glcolor;

layout(location = 0) out vec4 outColor;

// The sky is at "infinite" distance, so the in-medium fogs cover it fully.
vec3 skyFog(vec3 c) {
    return applyAtmosphere(c, vec3(0.0, 0.0, -1024.0), true);
}

void main() {
    // Sunrise/sunset glow is a vertex-colored fan: draw it as vanilla does.
    if (renderStage == MC_RENDER_STAGE_SUNSET) {
        outColor = vec4(skyFog(glcolor.rgb), glcolor.a);
        return;
    }
    // Stars: on this Minecraft/Iris combo they do not report
    // MC_RENDER_STAGE_STARS, so anything that is neither the dome nor the sunset
    // fan is a star. Their vertex color is not a usable brightness here, so fade
    // them in only as the sky gets dark (and out in rain).
    if (renderStage != MC_RENDER_STAGE_SKY) {
        float skyLum = dot(skyColor, vec3(0.2126, 0.7152, 0.0722));
        float a = (1.0 - smoothstep(0.02, 0.15, skyLum)) * (1.0 - rainStrength);
        if (a <= 0.0) discard;
        outColor = vec4(skyFog(vec3(1.0)), a);
        return;
    }

    vec4 p = gbufferProjectionInverse *
             vec4(gl_FragCoord.xy / vec2(viewWidth, viewHeight) * 2.0 - 1.0, 1.0, 1.0);
    outColor = vec4(skyFog(skyGradient(normalize(p.xyz / p.w))), 1.0);
}
