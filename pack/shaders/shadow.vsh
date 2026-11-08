#version 330 compatibility

// Shadow map caster pass (only runs with ENABLE_SHADOWS). Depth only: just the
// texture coordinate is needed, for the alpha test on foliage.

#include "/lib/options.glsl"

// Iris only lists an option in the menu if some shader file mentions it.
// SHADOW_ENTITIES itself is read by shaders.properties (shadowEntities=...).
#ifdef SHADOW_ENTITIES
#endif

in vec4 mc_Entity;   // block id from block.properties, -1 if unlisted
in vec3 at_midBlock; // offset to the block centre, in 1/64 block

flat out int solidCutout;   // far leaves: skip the alpha test (holes are sub-texel there)

out vec2 texcoord;

#ifdef ENABLE_SHADOWS
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform float sunAngle;
#include "/lib/shadowyaw.glsl"
#ifdef ENABLE_WAVING
#include "/lib/wave.glsl"
#endif
#endif

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    solidCutout = 0;
#ifdef ENABLE_SHADOWS
    vec3 sv = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec3 playerPos = mat3(shadowModelViewInverse) * sv + shadowModelViewInverse[3].xyz;
    float blockDist = length(playerPos + at_midBlock / 64.0);   // before waving, so a quad's vertices agree
#ifdef ENABLE_WAVING
    // Same sway as the terrain pass, so shadows stay attached to the plants.
    playerPos += waveOffset(playerPos + cameraPosition, int(mc_Entity.x), texcoord);
#endif
    mat3 yaw = shadowYaw();
    gl_Position = gl_ProjectionMatrix * (shadowModelView * vec4(shadowYawPos(playerPos), 1.0));
    // Warp the map toward the player: xy is divided by f, so texels near the
    // camera are 1/(1-SHADOW_WARP) times denser. shadowTerm applies the same warp.
    float warpF = length(gl_Position.xy) * SHADOW_WARP + (1.0 - SHADOW_WARP);
    // Thicken back faces. A wall that faces away from the light is often the only
    // caster over the floor at its base, a hair in front of that floor, so any
    // lookup bias bigger than the gap reads the floor as lit (a bright line along
    // the wall base at low sun). Pushing back faces a little toward the light puts
    // them clearly in front; sun-facing faces are untouched.
    vec3 nView = mat3(shadowModelView) * (yaw * (mat3(shadowModelViewInverse) * (gl_NormalMatrix * gl_Normal)));
    // Not for thin cutouts (leaves, grass, litter, roots, flowers): their back face
    // sits on top of the sunlit front face, so pushing it would shade the plant itself.
    int id = int(mc_Entity.x);
    bool thin = id == 10001 || id == 10003 || id == 10005;
    if (nView.z < 0.0 && !thin) {
        // blocks per shadow texel at this vertex
        float texel = 2.0 * SHADOW_DISTANCE / float(SHADOW_MAP_RES) * warpF * warpF / (1.0 - SHADOW_WARP);
        // Capped in blocks: at long range a texel is up to half a block, and a full
        // block of push makes ledges throw a dark line onto the step below.
        gl_Position.z += min(2.0 * texel, 0.25) * gl_ProjectionMatrix[2][2];
    }
    gl_Position.xy /= warpF;
#ifndef SHADOW_GRASS
    // Grass plants (10003): every vertex of the quad lands outside the clip
    // volume, so the quad is dropped before rasterizing and the alpha-test
    // fragments of dense grass fields are never run.
    if (int(mc_Entity.x) == 10003) gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
#endif
    // Far away, small casters (grass, plants, thin blocks) are smaller than a
    // shadow texel: drop them. Decided per block (centre distance) so all
    // vertices of a quad agree and no triangle is half-clipped.
    // Only while the sun is above 30 degrees: then a shadow is at most ~1.7x its
    // caster's height. At low sun a sugar cane or grass shadow runs 10-40 blocks
    // toward the player, and dropping it at this distance made whole long shadows
    // pop in and out while walking across the threshold.
    float sunH = sin(sunAngle * 6.28318530718);
    if (blockDist > 2.0 * SHADOW_NEAR) {
        if ((id == 10003 || id == 10005) && sunH > 0.5) gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
        if (id == 10001) solidCutout = 1;
    }
#else
    gl_Position = vec4(2.0, 2.0, 2.0, 1.0);   // clipped: nothing is drawn if the pass runs anyway
#endif
}
