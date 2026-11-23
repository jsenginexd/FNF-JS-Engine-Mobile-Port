# Mobile optimization pack

This file records the performance techniques being ported or evaluated for the
Haxe/Flixel mobile engine. The reference engine is a separate C++/raylib
implementation, so its algorithms are translated at the design level rather
than copied as incompatible C++.

## Visual quality (implemented)

1. **Scale-aware note filtering**: non-pixel note and receptor sprites use
   antialiasing on mobile; pixel-art notes remain nearest-neighbour/crisp.
2. **Sustain seam overlap**: adjacent sustain pieces overlap slightly to hide
   atlas/filter seams without changing hit timing or note count.
3. **No visual LOD that removes notes**: every chart note and animation frame
   remains available. Do not cap visible notes to fake an FPS increase.

## Runtime optimizations already present on the mobile branch

4. **Compact live-note lists**: update only active chart notes rather than
   repeatedly traversing dead pooled group members.
5. **O(1) pool bookkeeping**: maintain free-note pools and active-list indices
   so dense spawn/cleanup bursts do not repeatedly scan whole groups.
6. **Cached chart fields**: read raw time, lane, sustain length, and note type
   once during chart generation instead of resolving them repeatedly.
7. **Monotonic event cursors**: advance event indices instead of shifting arrays
   or rescanning already-processed events.
8. **Reusable lane buckets**: reuse per-lane arrays for ordering work and avoid
   per-frame temporary allocations.
9. **Lua dispatch guards**: skip callback dispatch entirely when no Lua scripts
   are loaded; preserve script-aware fallback behavior.
10. **HUD dirty checks**: update text, colour, and positions only when values
    actually change.
11. **Sustain state caches**: cache animation and clipping state while the
    underlying frame/geometry remains unchanged.
12. **Hitbox invalidation**: rebuild sustain hitboxes only after scale or frame
    dimensions change.
13. **Safe note cleanup**: reset active-list indices when notes leave a group or
    are recycled, preventing stale references.

## Additional techniques adapted from the reference engine

14. **Parse hot fields once**: chart parsing should extract time/lane/type/
    sustain data into compact records, then avoid repeated dynamic reflection.
15. **Bounded read-ahead**: for very large chart files, overlap file reads and
    parsing with a bounded queue so memory use cannot grow without limit.
16. **Streaming large charts**: reserve full DOM parsing for small files; use a
    streaming parser for large charts only after compatibility tests cover
    events, custom fields, alternate chart formats, and Lua/modchart metadata.
17. **Monotonic spawn cursors**: keep the next-note index moving forward as song
    time advances; never search the full unspawned list every frame.
18. **Cached raster variants**: cache rendered note images by direction, pixel
    size, skin/theme generation, and filtering mode. Invalidate only when one
    of those keys changes.
19. **Span/dirty-region rendering**: upload only changed texture rows/columns
    when a renderer backend supports partial texture updates.
20. **Frame-work budgeting**: spread non-critical preparation (skin baking,
    cache warmup, expensive preview work) across frames; never defer hit
    detection, input, or note timing.
21. **Adaptive frame pacing**: measure actual frame work and display interval
    before changing scheduling margins. Do not guess refresh rate or insert
    sleeps into the gameplay update loop.
22. **Android performance hints**: optionally report measured frame work through
    the Android Performance Hint API when available, with runtime symbol checks
    and a safe fallback on older Android versions.
23. **SIMD only behind parity tests**: vectorized paths must compare against a
    scalar reference on randomized inputs before being enabled.
24. **Cache invalidation by generation**: theme/skin changes should increment a
    generation key so cached graphics cannot display stale assets.
25. **No unsafe parallel gameplay mutation**: worker threads may read/parse
    immutable chart data, but Flixel sprites, groups, hit state, and Lua callbacks
    remain on the main thread unless the engine explicitly guarantees otherwise.

## Safety and correctness gates

- Preserve every note, sustain segment, and animation frame.
- Preserve stable ordering for simultaneous notes and hit-priority rules.
- Keep Lua/modchart compatibility; use the full compatibility path when scripts
  can inspect or mutate note objects.
- Do not claim an FPS gain without a repeatable before/after benchmark on the
  same chart, settings, device, and thermal state.
- Treat visual filtering and gameplay simulation as separate systems.
- Any streaming parser must round-trip representative Psych, legacy, and
  custom chart data before it replaces the current loader.

## Next measured targets

- Profile BotPlay CPU time by phase: note update, sustain clipping, sorting,
  group traversal, Lua dispatch, and rendering submission.
- Profile GPU time separately from CPU time; antialiasing may improve edges but
  can slightly increase texture sampling cost.
- Benchmark dense charts at fixed scroll speed and fixed camera zoom.
- Verify sustain seams at multiple zoom levels and both scroll directions.
