#version 330 compatibility

// Shadow map caster pass (only runs with ENABLE_SHADOWS). Depth only: just the
// texture coordinate is needed, for the alpha test on foliage.

#include "/lib/options.glsl"

// Iris only lists an option in the menu if some shader file mentions it.
// SHADOW_ENTITIES itself is read by shaders.properties (shadowEntities=...).
#ifdef SHADOW_ENTITIES
#endif

in vec4 mc_Entity;   // block id from block.properties, -1 if unlisted

out vec2 texcoord;

#ifdef ENABLE_SHADOWS
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
#include "/lib/shadowyaw.glsl"
#ifdef ENABLE_WAVING
#include "/lib/wave.glsl"
#endif
#endif

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
#ifdef ENABLE_SHADOWS
    vec3 sv = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec3 playerPos = mat3(shadowModelViewInverse) * sv + shadowModelViewInverse[3].xyz;
#ifdef ENABLE_WAVING
    // Same sway as the terrain pass, so shadows stay attached to the plants.
    playerPos += waveOffset(playerPos + cameraPosition, int(mc_Entity.x), texcoord);
#endif
    mat3 yaw = shadowYaw();
    gl_Position = gl_ProjectionMatrix * (shadowModelView * vec4(yaw * playerPos, 1.0));
    // Warp the map toward the player: xy is divided by f, so texels near the
    // camera are 1/(1-SHADOW_WARP) times denser. shadowTerm applies the same warp.
    float warpF = length(gl_Position.xy) * SHADOW_WARP + (1.0 - SHADOW_WARP);
    // Thicken back faces. A wall that faces away from the light is often the only
    // caster over the floor at its base, a hair in front of that floor, so any
    // lookup bias bigger than the gap reads the floor as lit (a bright line along
    // the wall base at low sun). Pushing back faces a little toward the light puts
    // them clearly in front; sun-facing faces are untouched.
    vec3 nView = mat3(shadowModelView) * (yaw * (mat3(shadowModelViewInverse) * (gl_NormalMatrix * gl_Normal)));
    if (nView.z < 0.0) {
        // blocks per shadow texel at this vertex
        float texel = 2.0 * SHADOW_DISTANCE / float(SHADOW_RESOLUTION) * warpF * warpF / (1.0 - SHADOW_WARP);
        gl_Position.z += 2.0 * texel * gl_ProjectionMatrix[2][2];
    }
    gl_Position.xy /= warpF;
#ifndef SHADOW_GRASS
    // Grass plants (10003): every vertex of the quad lands outside the clip
    // volume, so the quad is dropped before rasterizing and the alpha-test
    // fragments of dense grass fields are never run.
    if (int(mc_Entity.x) == 10003) gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
#endif
#else
    gl_Position = vec4(2.0, 2.0, 2.0, 1.0);   // clipped: nothing is drawn if the pass runs anyway
#endif
}
