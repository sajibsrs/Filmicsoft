#version 330 compatibility

// Block-breaking cracks: plain textured geometry, no lighting.

out vec2 texcoord;
out vec4 glcolor;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex;
    glcolor = gl_Color;
}
