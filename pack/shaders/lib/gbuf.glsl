// G-buffer packing shared by the geometry programs and deferred.fsh.
//   colortex0 : rgb = albedo (display space), a = vertex ambient occlusion
//   colortex1 : r = block light + surface kind (see packLight), g = sky light,
//               ba = octahedral normal
// A cleared colortex1 is all zeros, so "ba both non-zero" doubles as the flag
// for "this pixel was written by one of our geometry programs".

vec2 octEncode(vec3 n) {
    n /= (abs(n.x) + abs(n.y) + abs(n.z));
    vec2 e = n.xy;
    if (n.z < 0.0) {
        e = (1.0 - abs(n.yx)) * vec2(n.x >= 0.0 ? 1.0 : -1.0, n.y >= 0.0 ? 1.0 : -1.0);
    }
    return e;
}

vec3 octDecode(vec2 e) {
    vec3 n = vec3(e, 1.0 - abs(e.x) - abs(e.y));
    if (n.z < 0.0) {
        n.xy = (1.0 - abs(n.yx)) * vec2(n.x >= 0.0 ? 1.0 : -1.0, n.y >= 0.0 ? 1.0 : -1.0);
    }
    return normalize(n);
}

// Normal -> two channels in (0,1], never exactly 0 (that is the "unlit" flag).
vec2 packNormal(vec3 n) {
    return max(octEncode(normalize(n)) * 0.5 + 0.5, vec2(1.0 / 255.0));
}

vec3 unpackNormal(vec2 p) {
    return octDecode(p * 2.0 - 1.0);
}

// Block light shares colortex1.r with a surface kind: r = (kind + 0.97 * blk) / 3,
// kind 0 = plain, 1 = foliage (leaves, grass, vines: lit as thin, light-
// scattering material), 2 = emissive (lava, glowstone...: adds its own colour).
// The 0.97 keeps a full-bright block inside its own third of the range.
vec2 packLight(vec2 lm, float kind) {
    return vec2((kind + 0.97 * clamp(lm.x, 0.0, 1.0)) / 3.0, clamp(lm.y, 0.0, 1.0));
}

vec2 unpackLight(vec2 p, out float foliage, out float emissive) {
    float k = clamp(floor(p.x * 3.0 + 0.001), 0.0, 2.0);
    foliage = step(0.5, k) - step(1.5, k);
    emissive = step(1.5, k);
    return vec2(clamp((p.x * 3.0 - k) / 0.97, 0.0, 1.0), p.y);
}
