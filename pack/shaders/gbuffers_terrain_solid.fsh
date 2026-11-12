#version 330 compatibility

// Solid terrain: no alpha test, so the GPU can reject hidden fragments before
// shading them. Body in lib/terrain_frag.glsl.

#define TERRAIN_SOLID
#include "/lib/terrain_frag.glsl"
