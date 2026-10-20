#version 330 compatibility

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;
out vec3 viewPos;
flat out int foliage;
flat out int emissive;

in vec4 mc_Entity;   // block id from block.properties, -1 if unlisted

uniform mat4 gbufferModelViewInverse;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    lmcoord = lmcoord / (30.0 / 32.0) - (1.0 / 32.0);
    viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    glcolor = gl_Color;
    int id = int(mc_Entity.x);
    foliage = (id == 10001 || id == 10003) ? 1 : 0;
    emissive = id == 10002 ? 1 : 0;
    // View space -> player space, so lighting can use the world-oriented sun.
    normal = mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal);
}
