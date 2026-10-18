# Filmicsoft

A lightweight, cinematic post-processing shader pack for Minecraft: Java Edition
(Iris + Sodium). Soft diffusion, bloom, Lightroom-style color grading, chromatic
fringe and film grain. Written for GLSL 330 so it runs on macOS (OpenGL 4.1),
Windows and Linux: no compute shaders, no SSBOs.

## Layout

- `pack/shaders/` - the shader pack itself (installed as `Filmicsoft` in `shaderpacks/`)
  - `lib/options.glsl` - every user option, shared by all passes
  - `composite*.fsh` - bloom prefilter, downsample chain, diffusion source
  - `final.fsh` - glow compositing, tone, calibration, color mixer, lens, grain
- `scripts/install.sh` - copy the pack into a Prism Launcher instance
- `tools/glcheck/` - compile every pass with the macOS GLSL compiler

## Workflow

```sh
tools/glcheck/run.sh          # compile check (macOS)
scripts/install.sh            # install into the "Fabulously Optimized" instance
scripts/install.sh "Other"    # or another Prism instance
```

Then in game: Video Settings > Shader Packs > Filmicsoft > Apply. After editing
files, press R in the shader screen (or re-apply) to reload. Check
`<instance>/minecraft/logs/latest.log` if the pack reports a failed load.

## Gotchas learned

- Buffer-format constants (`const int colortex4Format = RGBA16F;`) must be in a
  comment block; `RGBA16F` is not a real GLSL identifier.
- Iris pastes option values in as plain text. Never write `-OPTION` (a negative
  value becomes `--0.10`, a decrement); copy the option into a local variable
  first. `tools/glcheck` substitutes values the same way, so it catches this.
- `#version 330 compatibility` is fine; Iris translates it for macOS's core profile.
- The mipmap flag is only valid in composite-stage programs, not `final`.

## Status

Tested: Minecraft 26.1.2, Fabric, Iris 1.11.4, Sodium 0.9.2, macOS (Apple Silicon).
Not yet tested: Windows, Linux.
Planned: global lighting (gbuffers), presets, optional cheap AO.
