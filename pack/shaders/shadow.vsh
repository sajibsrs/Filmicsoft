#version 330 compatibility

// Shadow map caster pass (only runs with ENABLE_SHADOWS). Depth only: just the
// texture coordinate is needed, for the alpha test on foliage.

#include "/lib/options.glsl"

// Iris only lists an option in the menu if some shader file mentions it.
// SHADOW_ENTITIES itself is read by shaders.properties (shadowEntities=...).
#ifdef SHADOW_ENTITIES
#endif

out vec2 texcoord;

void main() {
#ifdef ENABLE_SHADOWS
    gl_Position = ftransform();
#else
    gl_Position = vec4(2.0, 2.0, 2.0, 1.0);   // clipped: nothing is drawn if the pass runs anyway
#endif
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
