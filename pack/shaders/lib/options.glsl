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
#define ENABLE_SHADOWS           // Real sun/moon shadow map (extra geometry pass + filtered lookups; off = sky-light fake shadow)

// ---- Grading ---------------------------------------------------------------
#define EXPOSURE 1.00            // [0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.40 1.50]
#define CONTRAST 0.30            // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.80 1.00]  1.00 = full S-curve
#define BLACK_LIFT 0.010         // [0.000 0.010 0.015 0.025 0.040 0.060]
#define SATURATION 0.90         // [0.00 0.25 0.50 0.60 0.70 0.80 0.90 1.00 1.10 1.20 1.30 1.50 1.75 2.00]
#define VIBRANCE 0.20           // [0.00 0.10 0.20 0.30 0.40 0.50 0.60 0.70 0.80 0.90 1.00]
#define CHROMA_LIMIT 1.00        // [0.00 0.25 0.50 0.70 0.80 0.90 1.00]
#define SHADOW_TINT 0.10         // [0.00 0.10 0.25 0.50 0.75 1.00]
#define HIGHLIGHT_TINT 0.10    // [0.00 0.10 0.25 0.50 0.75 1.00]

// ---- Calibration (Lightroom-style primary shifts) --------------------------
// Red:   + toward orange, - toward magenta
// Green: + toward teal,   - toward yellow
// Blue:  + toward purple, - toward cyan
#define CAL_RED 0.00             // [-0.30 -0.25 -0.20 -0.15 -0.10 -0.05 0.00 0.05 0.10 0.15 0.20 0.25 0.30]
#define CAL_GREEN 0.10           // [-0.30 -0.25 -0.20 -0.15 -0.10 -0.05 0.00 0.05 0.10 0.15 0.20 0.25 0.30]
#define CAL_BLUE -0.05           // [-0.30 -0.25 -0.20 -0.15 -0.10 -0.05 0.00 0.05 0.10 0.15 0.20 0.25 0.30]

// ---- Color mixer (Hue / Saturation / Luminance per color band) -------------
#define RED_H 0.00               // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define RED_S -0.10              // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define RED_L 0.00               // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define ORANGE_H 0.00            // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define ORANGE_S 0.00            // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define ORANGE_L 0.00            // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define YELLOW_H 0.00            // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define YELLOW_S -0.10           // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define YELLOW_L 0.00            // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define GREEN_H -0.10            // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define GREEN_S -0.20            // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define GREEN_L -0.10            // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define AQUA_H 0.00              // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define AQUA_S 0.00              // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define AQUA_L 0.00              // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define BLUE_H 0.00              // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define BLUE_S 0.00              // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define BLUE_L 0.00              // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define PURPLE_H 0.00            // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define PURPLE_S -0.30           // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define PURPLE_L 0.00            // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define MAGENTA_H 0.00           // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define MAGENTA_S -0.30          // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]
#define MAGENTA_L 0.00           // [-0.60 -0.50 -0.40 -0.30 -0.20 -0.10 0.00 0.10 0.20 0.30 0.40 0.50 0.60]

// ---- Glow ------------------------------------------------------------------
#define BLOOM_STRENGTH 0.20      // [0.00 0.10 0.20 0.30 0.40 0.55 0.70 0.90 1.20 1.50 2.00]
#define BLOOM_THRESHOLD 0.60     // [0.40 0.50 0.60 0.70 0.80 0.90]
#define DIFFUSION 0.05           // [0.00 0.05 0.08 0.12 0.16 0.20 0.28 0.36 0.50]

// ---- Lens ------------------------------------------------------------------
#define VIGNETTE 0.45            // [0.00 0.15 0.30 0.45 0.60 0.80 1.00]
#define CHROMA_FRINGE 0.05       // [0.00 0.05 0.10 0.15 0.25 0.40]

// ---- Grain (size is relative to a 1080p screen so Retina looks the same) ---
#define GRAIN_AMOUNT 0.005        // [0.000 0.0025 0.005 0.0075 0.010]
#define GRAIN_SIZE 4.0           // [1.0 1.5 2.2 3.0 4.0 5.0 6.0 8.0 10.0]
#define GRAIN_SPEED 24           // [0 6 10 16 24 36]  pattern changes per second (0 = still)

// ---- Lighting (forward, in the geometry programs) ---------------------------
#define SUN_INTENSITY 1.25     // [0.00 0.25 0.50 0.75 1.00 1.10 1.20 1.25 1.30 1.35 1.50 1.75 2.00]
#define AMBIENT_INTENSITY 1.00 // [0.00 0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00]
#define BLOCKLIGHT_INTENSITY 1.25 // [0.00 0.50 0.75 1.00 1.25 1.50 2.00]
#define HIGHLIGHT_KNEE 0.45      // [0.30 0.40 0.50 0.55 0.60 0.70 0.80 0.90]  lower = earlier, softer rolloff
#define EMISSIVE_GLOW 1.50       // [0.00 0.50 1.00 1.25 1.50 2.00 2.50 3.00]  lava, glowstone, lanterns, torches
#define MOON_BRIGHTNESS 0.50    // [0.00 0.50 0.75 1.00 1.50 2.00 3.00]
#define SURFACE_SHEEN 25       // [0 25 50 100 150 200 300]  percent. View-dependent sun sheen on all surfaces (0 = off, flat Lambert look); strongest at grazing angles
#define AO_STRENGTH 3.00        // [0.00 0.50 1.00 1.30 1.60 2.00 2.50 3.00 3.50 4.00 4.50 5.00]

// ---- Wind (only used when ENABLE_WAVING is on) ----------------------------
#define WAVING_STRENGTH 1.00     // [0.25 0.50 0.75 1.00 1.50 2.00]

// ---- Shadows (only used when ENABLE_SHADOWS is on) -------------------------
// Map covers SHADOW_DISTANCE blocks around the player; beyond it the sky-light
// fake shadow takes over (cross-faded). Texel size = 2 * distance / resolution.
#define SHADOW_DISTANCE 64       // [16 24 36 48 64 128]  blocks
#define SHADOW_RESOLUTION 1024   // [256 512 1024 2048]
#define SHADOW_SAMPLES 4        // [0 1 2 4 8 16 32 64]  edge antialiasing taps: 0 = off (hard, stair-stepped); more = smoother, costs GPU
#define SHADOW_SOFTNESS 0.5    // [0.0 0.5 1.0 1.5 2.0 3.0 4.0]  blur radius of the shadow edge, in shadow-map texels (0 = no blur)
#define SHADOW_ENTITIES          // Mobs and items cast shadows too (every entity is drawn a second time: costs CPU)
#define SHADOW_GRASS             // Grass and ferns cast shadows (dense fields put many extra cutout quads in the shadow map: costs GPU)

// ---- Atmosphere ------------------------------------------------------------
#define HAZE_AMOUNT 0.50         // [0.00 0.50 1.00 1.50 2.00]
#define CLOUD_DISTANCE 5.0       // [2.0 3.0 4.0 5.0 6.0 8.0]  cloud fade length, in render distances (higher = clouds reach the horizon)
#define HAZE_SUN_GLOW 0.50       // [0.00 0.25 0.50 0.75 1.00]
#define SKY_SCATTER 1.00         // [0.00 0.25 0.50 0.75 1.00 1.25 1.50 2.00]  deeper blue overhead, warm glow around the sun (0 = plain vanilla gradient)
#define RAIN_MOOD 1.00           // [0.00 0.50 1.00 1.50 2.00]  rain look: cooler, flatter colour, thicker haze, wet darker ground (0 = vanilla-like rain)
#define GODRAY_STRENGTH 1.00     // [0.00 0.10 0.20 0.30 0.50 0.75 1.00 1.50 2.00]
#define GODRAY_SAMPLES 16        // [8 12 16 24 32]  taps per pixel at half resolution

// ---- Debug (terrain only): 1 vertex color, 2 AO, 3 normals, 4 lightmap ----
#define DEBUG_VIEW 0             // [0 1 2 3 4]

// Fixed look, not exposed as sliders.
#define CLOUD_LIGHTING 1.00      // sun-angle shading of clouds, warm sides and undersides at sunrise / sunset
#define HORIZON_MIST 0.60        // pale haze band where the sky meets the horizon (far clouds and terrain fade into it)
