// Filmicsoft shared options. Included by every pass so values stay in sync.

// ---- Effects on/off (a disabled effect costs nothing: code and passes are removed)
#define ENABLE_BLOOM             // Glow around bright lights (2 extra passes)
#define ENABLE_DIFFUSION         // Soft pro-mist haze (shares the bloom passes)
#define ENABLE_HAZE              // Distance haze, sun glow, water/lava fog
#define ENABLE_GODRAYS           // Light shafts and sun glare (half-res march inside the bloom pass; skipped when the sun is not in view)
#define ENABLE_GRAIN             // Film grain
#define ENABLE_FXAA              // Edge anti-aliasing (FXAA, one extra texture neighbourhood)
#define ENABLE_WAVING            // Subtle wind sway on leaves, vines and grass (vertex shader only, costs ~nothing)
#define ENABLE_WATER_RIPPLES     // Blocky wind ripples in the water's sky reflection (~0.05 ms worst case)
#define ENABLE_UNDERWATER        // Underwater look: colour absorption and teal fog (off = vanilla water fog)
#define ENABLE_CAUSTICS          // Drifting light pattern on sunlit surfaces under water (only costs while submerged)
#define ENABLE_SHADOWS           // Real sun/moon shadow map (extra geometry pass + filtered lookups; off = sky-light fake shadow)

// ---- Grading ---------------------------------------------------------------
#define EXPOSURE 1.00            // [0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50]
#define CONTRAST 0.30            // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.80 1.00]  1.00 = full S-curve
#define BLACK_LIFT 0.010         // [0.000 0.010 0.015 0.025 0.040 0.060]
#define SATURATION 0.90         // [0.00 0.25 0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.50 1.75 2.00]
#define VIBRANCE 0.20           // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]
#define CHROMA_LIMIT 1.00        // [0.00 0.25 0.50 0.70 0.80 0.90 1.00]
// Tone colours: a preset sets the shadow / midtone / highlight colours (lib/grade.glsl);
// the strength says how strongly all three ranges are tinted.
// Presets: 0 None, 1 Teal & Orange, 2 Warm Film, 3 Cool Blue, 4 Golden Hour, 5 Rose Dusk, 6 Forest, 7 Neon
#define GRADE_PRESET 1           // [0 1 2 3 4 5 6 7]
#define GRADE_STRENGTH 1.00      // [0.00 0.25 0.50 1.00 1.50 2.00]

// ---- Glow ------------------------------------------------------------------
#define BLOOM_STRENGTH 0.75      // [0.10 0.25 0.50 0.75 0.90 1.00 1.25 1.50 1.75 2.00]

// ---- Lens ------------------------------------------------------------------
#define VIGNETTE 0.45            // [0.00 0.15 0.30 0.45 0.60 0.80 1.00]

// ---- Grain (size is relative to a 1080p screen so Retina looks the same) ---
#define GRAIN_AMOUNT 0.005        // [0.000 0.0025 0.005 0.0075 0.010]

// ---- Lighting (forward, in the geometry programs) ---------------------------
#define SUN_INTENSITY 1.75     // [1.00 1.25 1.50 1.75 2.00 2.25 2.50 3.00]  noon strength; low sun is scaled down automatically
#define AMBIENT_INTENSITY 1.00 // [0.00 0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00]
#define MOON_BRIGHTNESS 0.50    // [0.00 0.50 0.75 1.00 1.50 2.00 3.00]

// ---- Shadows (only used when ENABLE_SHADOWS is on) -------------------------
// Map covers SHADOW_CHUNKS chunks (SHADOW_DISTANCE blocks) around the player; beyond it the sky-light
// fake shadow takes over (cross-faded). Texel size = 2 * distance / SHADOW_MAP_RES.
// Detail is kept near the player, whatever the distance: the map is warped
// (SHADOW_WARP), and while the sun is high, small casters (grass, plants, thin
// blocks) stop casting past SHADOW_NEAR * 2. At low sun their shadows are long
// and they keep casting.
#define SHADOW_NEAR 16.0
#define SHADOW_CHUNKS 4          // [1 2 3 4 6 8 12 16 20 24 32]  chunks, like Minecraft's render distance (1 chunk = 16 blocks)
// The same distance in blocks, as a plain literal: Iris reads shadowDistance
// straight from the source and does not evaluate an expression like 4 * 16.
// SHADOW_DEPTH is how far the map reaches along the light, toward the sun and
// away from it. A fixed 576 blocks each way at every distance (768 at 32
// chunks): with Iris's default reach (100 toward, 156 away) a thin, crisp
// "stick" line flicked across stepped cliffs at low sun; the longer reach
// removes it.
#if SHADOW_CHUNKS == 1
#define SHADOW_DISTANCE 16
#elif SHADOW_CHUNKS == 2
#define SHADOW_DISTANCE 32
#elif SHADOW_CHUNKS == 3
#define SHADOW_DISTANCE 48
#elif SHADOW_CHUNKS == 6
#define SHADOW_DISTANCE 96
#elif SHADOW_CHUNKS == 8
#define SHADOW_DISTANCE 128
#elif SHADOW_CHUNKS == 12
#define SHADOW_DISTANCE 192
#elif SHADOW_CHUNKS == 16
#define SHADOW_DISTANCE 256
#elif SHADOW_CHUNKS == 20
#define SHADOW_DISTANCE 320
#elif SHADOW_CHUNKS == 24
#define SHADOW_DISTANCE 384
#elif SHADOW_CHUNKS == 32
#define SHADOW_DISTANCE 512
#define SHADOW_DEPTH 768.0
#define SHADOW_DEPTH_NEG -768.0
#else
#define SHADOW_DISTANCE 64
#endif
#ifndef SHADOW_DEPTH
#define SHADOW_DEPTH 576.0
#define SHADOW_DEPTH_NEG -576.0
#endif
#define SHADOW_RESOLUTION 0      // [0 512 1024 2048 4096]  0 = Auto: follows Shadow Distance
// The map size actually used, as a plain literal (Iris reads shadowMapResolution
// from the source). Auto: under 4 chunks 512, 4+ 1024, 8+ 2048, 16+ 4096, so a
// longer distance keeps roughly the same shadow sharpness.
#if SHADOW_RESOLUTION == 512
#define SHADOW_MAP_RES 512
#elif SHADOW_RESOLUTION == 1024
#define SHADOW_MAP_RES 1024
#elif SHADOW_RESOLUTION == 2048
#define SHADOW_MAP_RES 2048
#elif SHADOW_RESOLUTION == 4096
#define SHADOW_MAP_RES 4096
#elif SHADOW_CHUNKS >= 16
#define SHADOW_MAP_RES 4096
#elif SHADOW_CHUNKS >= 8
#define SHADOW_MAP_RES 2048
#elif SHADOW_CHUNKS >= 4
#define SHADOW_MAP_RES 1024
#else
#define SHADOW_MAP_RES 512
#endif
#define SHADOW_AA                // shadow edge antialiasing: off = hard, stair-stepped edges. Tap count follows SHADOW_SOFTNESS
#define SHADOW_ENTITIES          // Mobs and items cast shadows too (every entity is drawn a second time: costs CPU)
#define SHADOW_GRASS             // Grass and ferns cast shadows (dense fields put many extra cutout quads in the shadow map: costs GPU)

// ---- Atmosphere ------------------------------------------------------------
#define WAVING_STRENGTH 1.00     // [0.25 0.50 0.75 1.00 1.50 2.00]  only used when ENABLE_WAVING is on
#define HAZE_AMOUNT 0.50         // [0.00 0.50 1.00 1.50 2.00]
#define RAIN_MOOD 1.00           // [0.00 0.50 1.00 1.50 2.00]  rain look: cooler, flatter colour, thicker haze, wet darker ground (0 = vanilla-like rain)

// ---- Debug (terrain only): 1 vertex color, 2 AO, 3 normals, 4 lightmap, 5 shadow map ----
#define DEBUG_VIEW 0             // [0 1 2 3 4 5]

// Fixed look, not exposed as sliders.
#define CLOUD_OPACITY 0.75       // clouds are 25% see-through
#define CLOUD_LIGHTING 1.00     // sun-angle shading of clouds, warm sides and undersides at sunrise / sunset
#define HORIZON_MIST 0.60        // pale haze band where the sky meets the horizon (far clouds and terrain fade into it)
#define CAL_RED 0.00
#define CAL_GREEN 0.10
#define CAL_BLUE -0.05
#define RED_H 0.00
#define RED_S -0.10
#define RED_L 0.00
#define ORANGE_H 0.00
#define ORANGE_S 0.00
#define ORANGE_L 0.00
#define YELLOW_H 0.00
#define YELLOW_S -0.10
#define YELLOW_L 0.00
#define GREEN_H -0.10
#define GREEN_S -0.20
#define GREEN_L -0.10
#define AQUA_H 0.00
#define AQUA_S 0.00
#define AQUA_L 0.00
#define BLUE_H 0.00
#define BLUE_S 0.00
#define BLUE_L 0.00
#define PURPLE_H 0.00
#define PURPLE_S -0.30
#define PURPLE_L 0.00
#define MAGENTA_H 0.00
#define MAGENTA_S -0.30
#define MAGENTA_L 0.00
#define BLOOM_THRESHOLD 0.60
#define DIFFUSION 0.05
#define CHROMA_FRINGE 0.05
#define GRAIN_SIZE 4.0
#define GRAIN_SPEED 24  // pattern changes per second (0 = still)
#define BLOCKLIGHT_INTENSITY 1.25
#define HIGHLIGHT_KNEE 0.45  // lower = earlier, softer rolloff
#define EMISSIVE_GLOW 1.50  // lava, glowstone, lanterns, torches
#define SURFACE_SHEEN 25  // percent. View-dependent sun sheen on all surfaces (0 = off, flat Lambert look); strongest at grazing angles
#define AO_STRENGTH 3.00
#define SHADOW_WARP 0.75  // shadow map warp: texels near the player are 1/(1-this) times denser (4x), far ones coarser; same cost
#define SHADOW_YAW 25.0  // degrees the shadow light is turned from the real sun around the vertical axis (0 = true direction)
#define SHADOW_MIN_ELEVATION 22.0  // degrees; the shadow light never drops lower, so sunset shadows stay under ~2.5x their caster
#define SHADOW_SOFTNESS 1.0  // blur radius of the shadow edge, in shadow-map texels (0 = no blur)
#define CLOUD_DISTANCE 5.0  // cloud fade length, in render distances (higher = clouds reach the horizon)
#define HAZE_SUN_GLOW 0.50
#define SKY_SCATTER 1.00  // deeper blue overhead, warm glow around the sun (0 = plain vanilla gradient)
#define GODRAY_STRENGTH 1.00
#define GODRAY_SAMPLES 16  // taps per pixel at half resolution
