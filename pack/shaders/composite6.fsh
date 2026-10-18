#version 330 compatibility

// Diffusion ("pro-mist") source: a heavily blurred copy of the whole frame,
// unthresholded, built from a high mip level of the scene. Stored at 1/4 res
// in colortex9 and blended softly over the image in the final pass.

/* RENDERTARGETS: 9 */

// Iris builds the mip chain of colortex0 right before this program runs.
const bool colortex0MipmapEnabled = true;

uniform sampler2D colortex0;
uniform float viewWidth;
uniform float viewHeight;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

void main() {
    vec2 o = vec2(6.0 / viewWidth, 6.0 / viewHeight);
    vec3 sum = textureLod(colortex0, texcoord, 3.0).rgb * 2.0;
    sum += textureLod(colortex0, texcoord + vec2( o.x, 0.0), 3.0).rgb;
    sum += textureLod(colortex0, texcoord + vec2(-o.x, 0.0), 3.0).rgb;
    sum += textureLod(colortex0, texcoord + vec2(0.0,  o.y), 3.0).rgb;
    sum += textureLod(colortex0, texcoord + vec2(0.0, -o.y), 3.0).rgb;
    outColor = vec4(sum / 6.0, 1.0);
}
