# Measuring Filmicsoft's performance cost

## Automated: per-pass GPU cost

```sh
tools/bench/run.sh              # 1920x1080 and 2880x1800
tools/bench/run.sh 2560 1440    # any size
PACK=/path/to/shaders tools/bench/run.sh 1920 1080   # benchmark another copy
```

It builds buffers with the pack's real sizes and formats (`size.buffer.*`),
fills them with noise, and times each pass as a fullscreen draw (median and
best of 15 batches). Passes are discovered from the pack directory, so adding or
removing a `compositeN` pass needs no tool change. macOS only (OpenGL 4.1).

What it measures: the GPU cost of the pack's own passes on the machine you run
it on. What it does not: terrain geometry, overdraw, CPU work, the rest of the
game. The terrain pass is drawn as one fullscreen layer, so it shows the cost of
writing the G-buffer, not of a real scene. Use the **best** column to compare
changes (the median wobbles with GPU clocks and other processes).

### Pitfalls this harness had to avoid (and an earlier version fell into)

- **Hidden surface removal.** Apple GPUs skip a fullscreen draw if a later draw
  in the same render pass overwrites it. Drawing the same pass in a loop to one
  framebuffer therefore measures one draw in N. The tool alternates between two
  framebuffers so every draw is its own render pass.
- **Stale attachments.** A framebuffer reused across passes kept old
  attachments; a pass that sampled one of them was treated as a feedback loop
  and silently skipped, producing impossibly fast results. Attachments are now
  detached every pass, and each pass reads back a pixel to prove it ran.
- **Compressible data.** Constant-colour inputs compress to almost nothing and
  make bandwidth look free. All inputs are noise.

### Results

Apple M4, macOS, best-of-15 per pass, noise inputs, 2026-10-18.
(An earlier version of this file quoted 0.26 ms for the post chain. That figure
came from the flawed harness above and was wrong by roughly 4x.)

Before = first complete version. After = current.

| Pass | Before 1080p | After 1080p | Before 2880x1800 | After 2880x1800 |
|---|---|---|---|---|
| terrain layer (G-buffer) | 0.33 | 0.25 | 0.82 | 0.60 |
| deferred lighting | 0.36 | 0.27 | 0.89 | 0.69 |
| haze | 0.27 | (folded into final) | 0.72 | |
| bloom + diffusion passes | 0.46 | 0.22 | 0.95 | 0.56 |
| final grade / grain / lens | 0.69 | 0.59 | 1.80 | 1.53 |
| **post chain** | **1.7** | **1.1** | **4.6** | **2.8** |
| **post chain + terrain layer** | **2.0** | **1.3** | **5.4** | **3.4** |

(Before-numbers at 2880x1800 are approximate: the old pack's per-pass split was
only measured at 1080p; its totals are measured at both.)

Rule of thumb: the pack costs about 0.55 to 0.65 ms per megapixel for the post
chain on this GPU, so cost scales with the window's pixel count.

What changed, and what did not help:

| Change | Effect |
|---|---|
| Pack the G-buffer into 2 render targets instead of 3 | terrain -24%, deferred -25% |
| Fold haze into the final pass (one fewer full-screen read + write) | -0.2 ms |
| Bloom: 3 levels, 4x steps; diffusion shares a pass; no mipmap regeneration | -0.2 ms |
| Grain from Iris's built-in noise texture, fewer bloom taps, unrolled colour mixer | final -0.15 ms |
| Moving per-frame lighting constants into the vertex shader | **no gain**, reverted (the compiler already hoisted them; these passes are bandwidth-bound) |

Where the `final` pass spends its time at 1080p (removing one feature at a
time, before the last round of changes): grain 0.13 ms, atmosphere 0.12, bloom
and diffusion fetches 0.10, colour mixer 0.05, chromatic fringe ~0.

### Projected FPS impact

FPS is nonlinear, so convert to frame time:

    new FPS = 1000 / (1000 / old FPS + cost in ms)

Using the post chain + terrain layer cost, rounded: 1.5 ms at 1080p, 3.6 ms at
2880x1800. These are projections from GPU timings, not game measurements, and
real scenes (overdraw, translucent water) cost more.

| FPS without the pack | At 1080p (+1.5 ms) | At 2880x1800 (+3.6 ms) |
|---|---|---|
| 60 | 55 | 49 |
| 144 | 118 | 95 |
| 300 | 207 | 144 |
| 500 | 286 | 179 |

## Manual: in-game FPS (the ground truth)

The tool cannot see the whole game, so confirm with a real A/B.

Fix the conditions: same world, same coordinates and view direction (F3), same
render distance and window size, V-Sync off, unlimited framerate, plugged in,
window focused (the Dynamic FPS mod throttles background windows), two minutes
of warm-up. Alternate Off, Filmicsoft, Off, Filmicsoft and take medians of three
30-second readings per scene. Good scenes: open plains (haze, bloom), a cave
with torches (block light), and near water (translucent pass).

Result template for `docs/benchmarks/YYYY-MM-DD.md`:

    Machine / GPU:   OS:   Minecraft / Iris / Sodium:   Resolution:   Commit:

    | Scene | Config     | Avg FPS | Low FPS | ms/frame | Cost vs off (ms) |
    |-------|------------|---------|---------|----------|------------------|
    | A     | Off        |         |         |          | -                |
    | A     | Filmicsoft |         |         |          |                  |
