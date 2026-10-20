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

void main() {
#ifdef ENABLE_SHADOWS
    gl_Position = ftransform();
#ifndef SHADOW_GRASS
    // Grass plants (10003): every vertex of the quad lands outside the clip
    // volume, so the quad is dropped before rasterizing and the alpha-test
    // fragments of dense grass fields are never run.
    if (int(mc_Entity.x) == 10003) gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
#endif
#else
    gl_Position = vec4(2.0, 2.0, 2.0, 1.0);   // clipped: nothing is drawn if the pass runs anyway
#endif
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
