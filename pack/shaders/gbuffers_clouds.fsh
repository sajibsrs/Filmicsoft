#version 330 compatibility

// Clouds. Unlit: they fade into the sky color on their own instead of taking
// terrain distance fog, which would paint far cloud boxes solid fog color.
// Distance fades the cloud into transparency, like vanilla, so the grid of
// boxes dissolves toward the horizon instead of ending in hard edges.
// Lit by the sun's direction (CLOUD_LIGHTING): faces toward the sun are bright,
// faces away are shaded, and at sunrise / sunset the sun-facing sides and the
// undersides glow warm. Vanilla's own per-face shade and tint stay underneath.

/* RENDERTARGETS: 0 */

uniform sampler2D gtexture;
uniform vec3 skyColor;
uniform vec3 fogColor;
uniform vec3 upPosition;
uniform vec3 sunPosition;
uniform float sunAngle;
uniform float rainStrength;
uniform bool hasSkylight;
uniform float far;
uniform mat4 gbufferModelViewInverse;

#include "/lib/options.glsl"
#include "/lib/sky.glsl"

in vec2 texcoord;
in vec4 glcolor;
in vec3 viewPos;
in vec3 viewNormal;

layout(location = 0) out vec4 outColor;

void main() {
    vec4 c = texture(gtexture, texcoord) * glcolor;

    // Sun lighting per face. Normal and sun direction are both in view space.
    if (hasSkylight) {
        float h = sin(sunAngle * 6.28318530718);
        float dayAmt = smoothstep(-0.10, 0.20, h);
        float lowSun = (1.0 - smoothstep(0.02, 0.50, h)) * dayAmt;
        vec3 n = normalize(viewNormal);
        float facing = dot(n, normalize(sunPosition));                // -1 away .. 1 toward
        float under = clamp(-dot(n, normalize(upPosition)), 0.0, 1.0); // underside
        float shade = 1.0 + 0.30 * facing * dayAmt;
        // Sunset: sun-facing sides and undersides catch the low warm light.
        float glow = lowSun * clamp(max(facing, 0.0) + 0.7 * under, 0.0, 1.0) * (1.0 - rainStrength);
        vec3 warm = vec3(1.00, 0.62, 0.34);
        c.rgb *= mix(vec3(1.0), shade * vec3(1.0), CLOUD_LIGHTING);
        c.rgb = mix(c.rgb, c.rgb * warm * 1.5, clamp(glow * CLOUD_LIGHTING, 0.0, 1.0));
    }

    // Clouds reach well past the terrain render distance (vanilla draws them out to
    // ~1000 blocks), so fade over CLOUD_DISTANCE x far.
    // Horizontal distance only: clouds sit far above the camera, so straight-line
    // distance would half-fade even a cloud directly overhead.
    float dist = length(viewPos);
    vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos;
    float t = clamp(length(playerPos.xz) / (max(far, 64.0) * CLOUD_DISTANCE), 0.0, 1.0);

    // Melt into the sky color behind the cloud, then into transparency, so
    // far cloud boxes dissolve instead of showing as pale flat blocks.
    c.rgb = mix(c.rgb, skyGradient(viewPos / max(dist, 0.0001)), smoothstep(0.30, 1.00, t));
    c.a *= 1.0 - smoothstep(0.55, 1.00, t);
    if (c.a < 0.01) discard;

    outColor = c;
}
