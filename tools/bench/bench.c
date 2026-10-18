// Offscreen GPU benchmark for the Filmicsoft passes (macOS / OpenGL 4.1).
//
// Renders every pass as a fullscreen draw into buffers sized and formatted like
// the pack's (size.buffer.*), with synthetic input data, and times each pass.
// This measures the pass cost, not the game: terrain geometry, CPU work and
// overdraw are not included. The terrain pass is drawn as one fullscreen layer
// to show the cost of its 3 render targets.
//
// Usage: bench <width> <height> <shaders-dir-prepared-by-prep.py> <shaders.properties>
#define GL_SILENCE_DEPRECATION
#include <OpenGL/OpenGL.h>
#include <OpenGL/gl3.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

#define MAXTEX 16

static int W, H;
static GLuint colorTex[MAXTEX], altTex[MAXTEX], depthTex;
static int texW[MAXTEX], texH[MAXTEX];
static GLenum texIntFmt[MAXTEX];
static float texScale[MAXTEX], texScaleY[MAXTEX];
static int texAbsW[MAXTEX], texAbsH[MAXTEX];   // size.buffer values without a '.' are pixels (as in Iris)
static GLuint vao, noiseTex;

static const char *VS =
    "#version 410 core\nout vec2 texcoord;out vec2 lmcoord;out vec4 glcolor;out vec3 normal;\n"
    "void main(){vec2 p=vec2((gl_VertexID<<1)&2, gl_VertexID&2);"
    "texcoord=p; lmcoord=vec2(0.8,0.9); glcolor=vec4(1.0,1.0,1.0,0.9); normal=vec3(0.0,1.0,0.0);"
    "gl_Position=vec4(p*2.0-1.0,0.0,1.0);}\n";

static const char *COPY_FS =
    "#version 410 core\nin vec2 texcoord;uniform sampler2D colortex1;out vec4 o;"
    "void main(){o=texture(colortex1,texcoord);}\n";

static double now_ms(void) { return clock_gettime_nsec_np(CLOCK_UPTIME_RAW) / 1e6; }

static char *slurp(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    char *s = malloc(n + 1); fread(s, 1, n, f); s[n] = 0; fclose(f);
    return s;
}

static GLuint compile(GLenum type, const char *src, const char *name) {
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &src, NULL);
    glCompileShader(s);
    GLint ok; glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) { char log[4096]; glGetShaderInfoLog(s, sizeof log, NULL, log); fprintf(stderr, "%s: %s\n", name, log); exit(1); }
    return s;
}

static GLuint link(const char *fs, const char *vs, const char *name) {
    GLuint p = glCreateProgram();
    glAttachShader(p, compile(GL_VERTEX_SHADER, vs ? vs : VS, "vs"));
    glAttachShader(p, compile(GL_FRAGMENT_SHADER, fs, name));
    glLinkProgram(p);
    GLint ok; glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) { char log[4096]; glGetProgramInfoLog(p, sizeof log, NULL, log); fprintf(stderr, "link %s: %s\n", name, log); exit(1); }
    return p;
}

static GLuint makeTex(int w, int h, GLenum ifmt, GLenum fmt, GLenum type, const void *data, int mips) {
    GLuint t; glGenTextures(1, &t); glBindTexture(GL_TEXTURE_2D, t);
    glTexImage2D(GL_TEXTURE_2D, 0, ifmt, w, h, 0, fmt, type, data);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, mips ? GL_LINEAR_MIPMAP_LINEAR : GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    if (mips) glGenerateMipmap(GL_TEXTURE_2D);
    return t;
}

static void parseProps(const char *path) {
    for (int i = 0; i < MAXTEX; i++) { texScale[i] = texScaleY[i] = 1.0f; texAbsW[i] = texAbsH[i] = 0; }
    char *s = slurp(path); if (!s) return;
    for (char *line = strtok(s, "\n"); line; line = strtok(NULL, "\n")) {
        int n; char xs[32], ys[32];
        if (sscanf(line, "size.buffer.colortex%d=%31s %31s", &n, xs, ys) == 3 && n >= 0 && n < MAXTEX) {
            if (strchr(xs, '.')) texScale[n] = (float)atof(xs); else texAbsW[n] = atoi(xs);
            if (strchr(ys, '.')) texScaleY[n] = (float)atof(ys); else texAbsH[n] = atoi(ys);
        }
    }
    free(s);
}

static void setUniforms(GLuint prog, int *attachIdx, int nAttach, int parity) {
    GLint count; glGetProgramiv(prog, GL_ACTIVE_UNIFORMS, &count);
    int unit = 0;
    float proj[16] = {0};
    float fov = 1.2217f, a = (float)W / H, N = 0.05f, F = 512.0f, f = 1.0f / tanf(fov / 2.0f);
    // inverse perspective, column-major
    proj[0] = a / f; proj[5] = 1.0f / f; proj[11] = (N - F) / (2 * F * N);
    proj[14] = -1.0f; proj[15] = (F + N) / (2 * F * N);
    float ident[16] = {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1};
    for (int i = 0; i < count; i++) {
        char name[128]; GLsizei len; GLint size; GLenum type;
        glGetActiveUniform(prog, i, sizeof name, &len, &size, &type, name);
        GLint loc = glGetUniformLocation(prog, name);
        if (loc < 0) continue;
        if (type == GL_SAMPLER_2D) {
            GLuint t = depthTex; int n = -1;
            if (sscanf(name, "colortex%d", &n) == 1 && n >= 0 && n < MAXTEX) {
                t = colorTex[n];
                for (int k = 0; k < nAttach; k++) if (attachIdx[k] == n) t = parity ? colorTex[n] : altTex[n]; // avoid read/write feedback
            } else if (!strcmp(name, "gtexture")) t = colorTex[0];
            else if (!strcmp(name, "noisetex")) t = noiseTex;
            glActiveTexture(GL_TEXTURE0 + unit); glBindTexture(GL_TEXTURE_2D, t);
            glUniform1i(loc, unit++);
        } else if (type == GL_FLOAT) {
            float v = 0.0f;
            if (!strcmp(name, "viewWidth")) v = W; else if (!strcmp(name, "viewHeight")) v = H;
            else if (!strcmp(name, "far")) v = 128; else if (!strcmp(name, "sunAngle")) v = 0.2f;
            else if (!strcmp(name, "frameTimeCounter")) v = 12.5f; else if (!strcmp(name, "alphaTestRef")) v = 0.1f;
            glUniform1f(loc, v);
        } else if (type == GL_FLOAT_VEC3) {
            if (!strcmp(name, "sunPosition") || !strcmp(name, "shadowLightPosition")) glUniform3f(loc, 30, 80, -50);
            else if (!strcmp(name, "fogColor")) glUniform3f(loc, 0.75f, 0.85f, 1.0f);
            else glUniform3f(loc, 0.5f, 0.6f, 0.9f);
        } else if (type == GL_FLOAT_VEC4) glUniform4f(loc, 0, 0, 0, 0);
        else if (type == GL_BOOL || type == GL_INT) glUniform1i(loc, !strcmp(name, "hasSkylight") ? 1 : 0);
        else if (type == GL_INT_VEC2) glUniform2i(loc, 240, 240);
        else if (type == GL_FLOAT_MAT4) glUniformMatrix4fv(loc, 1, GL_FALSE, !strcmp(name, "gbufferProjectionInverse") ? proj : ident);
    }
}

int main(int argc, char **argv) {
    if (argc < 5) { fprintf(stderr, "usage: bench W H shaders-dir shaders.properties\n"); return 2; }
    W = atoi(argv[1]); H = atoi(argv[2]);
    const char *dir = argv[3];
    parseProps(argv[4]);

    CGLPixelFormatAttribute attrs[] = { kCGLPFAOpenGLProfile, (CGLPixelFormatAttribute)kCGLOGLPVersion_GL4_Core,
                                        kCGLPFAAccelerated, (CGLPixelFormatAttribute)0 };
    CGLPixelFormatObj pf; GLint npf; CGLContextObj ctx;
    if (CGLChoosePixelFormat(attrs, &pf, &npf) || !pf) { fprintf(stderr, "no GL context\n"); return 2; }
    CGLCreateContext(pf, NULL, &ctx); CGLSetCurrentContext(ctx);
    printf("%s | %s | %dx%d\n", glGetString(GL_RENDERER), glGetString(GL_VERSION), W, H);
    glGenVertexArrays(1, &vao); glBindVertexArray(vao);

    // Buffers: 0-3 RGBA8 full size, 4-9 RGBA16F at the pack's scales.
    for (int i = 0; i < 11; i++) {
        int half = i >= 4;
        texW[i] = texAbsW[i] ? texAbsW[i] : (int)fmaxf(1, W * texScale[i]);
        texH[i] = texAbsH[i] ? texAbsH[i] : (int)fmaxf(1, H * texScaleY[i]);
        texIntFmt[i] = half ? GL_RGBA16F : GL_RGBA8;
        size_t n = (size_t)texW[i] * texH[i] * 4;
        unsigned char *px = malloc(n);
        for (size_t k = 0; k < n; k += 4) {
            unsigned r = (unsigned)(k * 2654435761u) >> 24;
            // Noise everywhere: constant data compresses to nothing on tile-based GPUs
            // and would make bandwidth look free. Values stay valid for both G-buffer
            // layouts (flag/normal channels never zero).
            unsigned r1 = (unsigned)((k + 1) * 2246822519u) >> 24, r2 = (unsigned)((k + 7) * 3266489917u) >> 24;
            unsigned r3 = (unsigned)((k + 13) * 668265263u) >> 24;
            if (i == 0) { px[k] = 90 + r % 150; px[k+1] = 90 + r1 % 150; px[k+2] = 90 + r2 % 150; px[k+3] = 255; }
            else if (i == 1) { px[k] = r1; px[k+1] = r2; px[k+2] = 1 + r3 % 254; px[k+3] = 200 + r % 56; }
            else if (i == 2) { px[k] = r1; px[k+1] = 200 + r2 % 56; px[k+2] = r3; px[k+3] = 255; }
            else { px[k] = r; px[k+1] = r1; px[k+2] = r2; px[k+3] = 255; }
        }
        colorTex[i] = makeTex(texW[i], texH[i], texIntFmt[i], GL_RGBA, GL_UNSIGNED_BYTE, px, i == 0);
        altTex[i] = makeTex(texW[i], texH[i], texIntFmt[i], GL_RGBA, GL_UNSIGNED_BYTE, px, i == 0);
        free(px);
    }
    { unsigned char *nz = malloc(256 * 256 * 4);
      for (int k = 0; k < 256 * 256 * 4; k++) nz[k] = (unsigned char)(((unsigned)(k + 3) * 2654435761u) >> 24);
      noiseTex = makeTex(256, 256, GL_RGBA8, GL_RGBA, GL_UNSIGNED_BYTE, nz, 0);
      glBindTexture(GL_TEXTURE_2D, noiseTex);
      glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT); glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
      free(nz); }
    float *dp = malloc((size_t)W * H * sizeof(float));
    for (size_t k = 0; k < (size_t)W * H; k++) dp[k] = 0.9f + 0.09f * ((k % 977) / 977.0f);
    depthTex = makeTex(W, H, GL_R32F, GL_RED, GL_FLOAT, dp, 0);
    free(dp);

    // Discover passes in execution order: terrain, deferred, composite, composite1.., final.
    const char *passes[40]; char names[40][32]; int nPass = 0;
    const char *wanted[] = { "gbuffers_terrain", "deferred", "composite" };
    for (int w = 0; w < 3; w++) { snprintf(names[nPass], 32, "%s", wanted[w]); passes[nPass] = names[nPass]; nPass++; }
    for (int c = 1; c < 30; c++) { snprintf(names[nPass], 32, "composite%d", c); passes[nPass] = names[nPass]; nPass++; }
    snprintf(names[nPass], 32, "final"); passes[nPass] = names[nPass]; nPass++;
    snprintf(names[nPass], 32, "__copy"); passes[nPass] = names[nPass]; nPass++;
    double total = 0, post = 0, bestTotal = 0, bestPost = 0;
    GLuint fbos[2]; glGenFramebuffers(2, fbos);

    printf("\n%-18s %9s %9s   %s\n", "pass", "median", "best", "targets");
    for (int p = 0; p < nPass; p++) {
        char path[1024]; char *src;
        if (!strcmp(passes[p], "__copy")) src = strdup(COPY_FS);
        else { snprintf(path, sizeof path, "%s/%s.fsh", dir, passes[p]); src = slurp(path); }
        if (!src) continue;

        int tgt[8], nt = 0;
        char *rt = strstr(src, "RENDERTARGETS:");
        if (rt) { rt += 14; while (nt < 8) { while (*rt == ' ' || *rt == ',') rt++; if (*rt < '0' || *rt > '9') break; tgt[nt++] = (int)strtol(rt, &rt, 10); } }
        else { tgt[0] = 3; nt = 1; }  // final / copy: dedicated full-res RGBA8 scratch target

        char vpath[1024]; snprintf(vpath, sizeof vpath, "%s/%s.vsh", dir, passes[p]);
        char *vsrc = slurp(vpath);
        GLuint prog = link(src, vsrc, passes[p]);
        free(vsrc);
        glUseProgram(prog);
        GLenum bufs[8];
        for (int f = 0; f < 2; f++) {
            glBindFramebuffer(GL_FRAMEBUFFER, fbos[f]);
            for (int k = 0; k < nt; k++) {
                glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + k, GL_TEXTURE_2D,
                                       f ? altTex[tgt[k]] : colorTex[tgt[k]], 0);
                bufs[k] = GL_COLOR_ATTACHMENT0 + k;
            }
            glDrawBuffers(nt, bufs);
            for (int k = nt; k < 8; k++)   // detach stale attachments from the previous pass
                glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + k, GL_TEXTURE_2D, 0, 0);
        }
        glViewport(0, 0, texW[tgt[0]], texH[tgt[0]]);
        int mip = strstr(src, "MipmapEnabled") != NULL;

        enum { NS = 15 };
        double samples[NS];
        for (int s = 0; s < NS; s++) {
            int iters = 40;
            glFinish(); double t0 = now_ms();
            for (int it = 0; it < iters; it++) {
                // Alternate framebuffers: each draw is its own render pass, so the
                // GPU cannot discard a draw that a later one would overwrite.
                int par = it & 1;
                glBindFramebuffer(GL_FRAMEBUFFER, fbos[par]);
                setUniforms(prog, tgt, nt, par);
                if (mip) { glActiveTexture(GL_TEXTURE0); glBindTexture(GL_TEXTURE_2D, colorTex[0]); glGenerateMipmap(GL_TEXTURE_2D); }
                glDrawArrays(GL_TRIANGLES, 0, 3);
            }
            glFinish(); samples[s] = (now_ms() - t0) / iters;
        }
        // Verify the pass really produces output: one extra draw, then read the centre pixel.
        float pxv[4] = {-1, -1, -1, -1};
        glBindFramebuffer(GL_FRAMEBUFFER, fbos[0]);
        setUniforms(prog, tgt, nt, 0);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        glFinish();
        glReadBuffer(GL_COLOR_ATTACHMENT0);
        glReadPixels(texW[tgt[0]] / 2, texH[tgt[0]] / 2, 1, 1, GL_RGBA, GL_FLOAT, pxv);
        { GLenum err = glGetError(); if (err) fprintf(stderr, "  [%s] glReadPixels error 0x%x\n", passes[p], err); }
        for (int a = 0; a < NS; a++) for (int b = a + 1; b < NS; b++) if (samples[b] < samples[a]) { double t = samples[a]; samples[a] = samples[b]; samples[b] = t; }
        double ms = samples[NS / 2];  // median
        double best = samples[0];
        char tl[64] = ""; for (int k = 0; k < nt; k++) { char b[8]; snprintf(b, sizeof b, "%d ", tgt[k]); strcat(tl, b); }
        printf("%-18s %9.3f %9.3f   colortex %-6s centre px %.3f %.3f %.3f%s\n", !strcmp(passes[p], "__copy") ? "(fullscreen copy)" : passes[p], ms, best, tl, pxv[0], pxv[1], pxv[2], mip ? " (+mipmaps)" : "");
        if (strcmp(passes[p], "__copy")) { total += ms; bestTotal += best; if (strcmp(passes[p], "gbuffers_terrain")) { post += ms; bestPost += best; } }
        free(src);
    }
    printf("\n%-18s %9.3f %9.3f\n%-18s %9.3f %9.3f\n", "post chain total", post, bestPost, "+ terrain layer", total, bestTotal);
    return 0;
}
