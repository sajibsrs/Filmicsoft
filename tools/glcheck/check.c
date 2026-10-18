#define GL_SILENCE_DEPRECATION
#include <OpenGL/OpenGL.h>
#include <OpenGL/gl3.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Usage: check <vs|fs> <file> ; file already preprocessed (includes expanded).
int main(int argc, char **argv) {
    CGLPixelFormatAttribute attrs[] = { kCGLPFAOpenGLProfile, (CGLPixelFormatAttribute)kCGLOGLPVersion_GL4_Core,
                                        kCGLPFAAccelerated, (CGLPixelFormatAttribute)0 };
    CGLPixelFormatObj pf; GLint n; CGLContextObj ctx;
    if (CGLChoosePixelFormat(attrs, &pf, &n) || !pf) { fprintf(stderr, "no pixel format\n"); return 2; }
    CGLCreateContext(pf, NULL, &ctx); CGLSetCurrentContext(ctx);
    printf("GL_VERSION: %s\nGLSL: %s\n", glGetString(GL_VERSION), glGetString(GL_SHADING_LANGUAGE_VERSION));
    int bad = 0;
    for (int i = 1; i + 1 < argc; i += 2) {
        GLenum type = strcmp(argv[i], "vs") == 0 ? GL_VERTEX_SHADER : GL_FRAGMENT_SHADER;
        FILE *f = fopen(argv[i+1], "rb"); if (!f) { printf("cannot open %s\n", argv[i+1]); return 2; }
        fseek(f, 0, SEEK_END); long len = ftell(f); fseek(f, 0, SEEK_SET);
        char *src = malloc(len + 1); fread(src, 1, len, f); src[len] = 0; fclose(f);
        GLuint s = glCreateShader(type); glShaderSource(s, 1, (const char**)&src, NULL); glCompileShader(s);
        GLint ok; glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
        char log[8192]; glGetShaderInfoLog(s, sizeof log, NULL, log);
        printf("%-40s %s\n%s", argv[i+1], ok ? "OK" : "FAILED", log);
        if (!ok) bad = 1;
    }
    return bad;
}
