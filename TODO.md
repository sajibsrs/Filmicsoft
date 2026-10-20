# Filmicsoft to-do

## Ideas (from the 2026-10-21 shortlist)

| # | Idea | Visual gain | Cost | Notes |
|---|------|-------------|------|-------|
| 2 | Better water (rest) | High in villages, rivers and oceans | Low | Sky reflection + Fresnel done with #3; still to do: sun glint and animated normal ripples. No screen-space reflections, so no extra pass. |
| 5 | Cloud lighting | Medium | ~0 | Shade clouds by sun angle (warm undersides at sunset), plus a cloud brightness slider. |
| 7 | Underwater look | Medium | Low | Caustic shimmer and a stronger blue-green fall-off. |

Done: #1 waving plants (220bc02), #4 sky scattering (f1af8cf), #6 rain atmosphere (3382a39),
#3 water sky + sunset reflection (measured +0.15 ms worst case, full-screen water at 1080p).

## Rain follow-ups

- Benchmark again with `RAIN=1 tools/bench/run.sh`: the last run predates the
  thunder sky floor, brighter streaks and splash recolouring.
- Splash particles are picked by colour (deep blue, only while it rains), so a
  deep-blue potion swirl in the rain also turns grey-blue. Rare; left as is.
- Possibly a separate slider for rain streak visibility (now fixed in
  `gbuffers_weather.fsh`: brightness 1.35, opacity 0.55).
