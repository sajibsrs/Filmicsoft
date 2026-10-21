# Filmicsoft to-do

## Ideas (from the 2026-10-21 shortlist)

Nothing queued from the shortlist.

Done: #5 cloud lighting + horizon mist, #7 underwater look (toggle on the Effects page). Sun glint (#2) was tried and dropped: it did not fit the Minecraft look. #1 waving plants (220bc02), #4 sky scattering (f1af8cf), #6 rain atmosphere (3382a39),
#3 water sky + sunset reflection and water ripples (measured +0.13 ms worst case together,
full-screen water at 1080p: reflection +0.08, ripples +0.05).

## Rain follow-ups

- Benchmark again with `RAIN=1 tools/bench/run.sh`: the last run predates the
  thunder sky floor.
- Rain streaks and splashes are back to vanilla colour (streak opacity is 0.55).
