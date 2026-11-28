# Mobile optimization pack

This file records the performance techniques being ported or evaluated for the
Haxe/Flixel mobile engine. The reference engine is a separate C++/raylib
implementation, so its algorithms are translated at the design level rather
than copied as incompatible C++.

## Visual quality (implemented)

1. **Compact mobile note atlas**: Android uses 40x25 pixelUI note sheets
   (1,000 source pixels) with the original 4x5 grid and all 20 receptor frames.
   Notes are scaled non-uniformly at render time to retain their original
   on-screen dimensions; the source intentionally has much lower detail.
2. **No unused high-resolution note upload**: skip the 5470x238 Sparrow note
   atlas preload on mobile when the compact pixel atlas is active. This avoids
   uploading a large texture that gameplay does not use.
3. **Pixel-preserving note sampling**: compact mobile arrows use nearest/pixel
   rendering; backgrounds retain the 70% mobile texture policy.
3. **Sustain seam overlap**: adjacent sustain pieces overlap slightly to hide
   atlas/filter seams without changing hit timing or note count.
4. **No visual LOD that removes notes**: every chart note, sustain segment, and
   gameplay animation frame remains available. Do not cap visible notes to fake
   an FPS increase.

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


## HXCPP native C++ kernels (implemented, benchmark pending)

26. **Native note-distance kernel**: primitive-only HXCPP C++ implementation for
    the per-note scroll-distance calculation, with an equivalent Haxe fallback
    for non-C++ targets.
27. **Native sustain-scale kernel**: primitive-only HXCPP C++ implementation
    for sustain scale calculation, including pixel-stage and end-cap cases.
28. **No object marshalling**: these kernels accept only scalar values, avoiding
    conversion of Haxe arrays or sprite objects across the native boundary.

These kernels prove the native integration path and preserve the same formulas.
They are not yet evidence of a measurable speedup: HXCPP already compiles Haxe
to C++, so the next step is profiling and comparing generated native code. Larger
wins are expected only from reducing allocations, traversals, and memory traffic,
not merely rewriting arithmetic in C++.

## Latest measured-risk reductions (build validation pending)

29. **Per-sustain scale cache**: calculate a sustain's vertical scale only when
    BPM step duration, song speed, note speed multiplier, note skin scale,
    pixel-stage mode, pixel zoom, or end-cap state changes. This avoids repeating
    the same native math call for every unchanged sustain on every frame.
30. **Allocation-free rating-rank selection**: replace the temporary ten-item
    Boolean array in rating recalculation with ordered comparisons while keeping
    the exact original priority and fcStrings indexes.
31. **Reusable combo digit storage**: clear the existing combo-digit array rather
    than allocate a new array for every popup.
32. **Seek cleanup consistency**: unregister notes from the compact active-note
    lists before removing them from Flixel groups; clear the group-membership flag
    and guard null group entries to avoid stale references after seeking.

These changes preserve the original note timing, note count, visual frames,
combo ranking precedence, and chart ordering. Confirm the Android build and test
seek/restart, all sustain types, BPM changes, both scroll directions, and dense
BotPlay charts before claiming a device-side FPS gain.

33. **Adaptive stable chart merge**: leave fully sorted charts untouched; merge a
    small number of already-sorted time ranges in linear passes, preserving the
    relative order of equal-time notes. Fall back to the existing general sort
    when there are many disordered ranges.

34. **Scale-aware mobile note sampling**: regular note atlases and receptors
    use smooth filtering and sub-pixel rendering; pixel-art notes retain nearest
    sampling and pixel-aligned rendering. The setting is applied after atlas
    reloads so animation changes cannot reset it.
35. **Cached scroll-distance factor**: each note recalculates its combined
    scroll-speed multiplier only when song speed or that note's speed multiplier
    changes. Per-frame distance updates then use one delta multiplication and
    preserve the existing upscroll/downscroll sign convention.
36. **Cached hit-window multipliers**: each note caches the early/late
    safe-zone products when timing preferences change. The original comparison
    expressions and strict boundaries remain unchanged to preserve hit accuracy.
37. **Hybrid stable lane sorting**: nearly sorted lanes keep the low-cost
    insertion path; heavily disordered lanes switch to a reusable stable merge
    buffer, avoiding quadratic worst-case sorting while preserving equal-Y order.
38. **NPS history cursors**: advance read cursors when old samples leave the
    rolling window and compact the arrays only after a large consumed prefix.
    This avoids shifting every surviving hit/date pair on each update while
    preserving the same rolling-window sums.
