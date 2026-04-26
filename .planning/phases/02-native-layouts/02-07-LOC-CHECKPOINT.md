# Phase 2 LOC Checkpoint (Wave 7 closeout)

**Captured:** 2026-04-26
**Phase:** 02-native-layouts
**Baseline:** Phase 1 close = 559 LOC (per `.planning/phases/01-contract-skeleton-penta-layouts/01-VERIFICATION.md`)
**Expected range (per CONTEXT.md `<code_context>` LOC budget):** 1230-1530 LOC
**Hard design-review trigger:** ONLY if cumulative > ~1500 (upper bound of expected range)

## Measurement

| File | LOC | Notes |
|---|---|---|
| addons/penta_tile/penta_tile_map_layer.gd | 377 | Modified: -overlay path, -_DEFAULT_LAYOUT, +detection wiring, +preload const fix |
| addons/penta_tile/penta_tile_atlas_slot.gd | 14 | Modified: -diagonal_complement_atlas_coords field |
| addons/penta_tile/penta_tile_synthesis.gd | 685 | NEW: 5-mode synthesis machinery (Gate 1/2 sub-region anchoring + polygon clipping + Liang-Barsky helper) |
| addons/penta_tile/layouts/penta_tile_layout.gd | 70 | Modified: bitmask_template rename, +get_fallback_tile_set virtual stub |
| addons/penta_tile/layouts/penta_tile_layout_penta.gd | 388 | NEW: merged class + axis/tile_count enums + _validate_property hide + AUTO/AUTO_STRIP detection + warnings (Wave 6 additions: +115 LOC) |
| addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd | 64 | NEW |
| addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd | 63 | NEW |
| addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd | 70 | NEW |
| addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd | 96 | NEW (higher than ~60 estimate: mask collapse logic + open-side rule) |
| addons/penta_tile/demo/demo_player.gd | 17 | unchanged from Phase 1 |
| addons/penta_tile/demo/demo_runtime_painter.gd | 54 | unchanged from Phase 1 |
| addons/penta_tile/tests/_capture_baseline.gd | 63 | test utility (NOT runtime addon code; committed for headless regression) |
| **Total (all .gd files)** | **1961** | |

**Runtime-only subtotal** (excluding demo + tests): 1961 - 17 - 54 - 63 = **1827 LOC**

Files DELETED in Phase 2 (counted as 0 in current total, removed from baseline):
- `addons/penta_tile/penta_tile_atlas_contract.gd` (~52 LOC removed)
- `addons/penta_tile/layouts/penta_tile_layout_penta_horizontal.gd` (~133 LOC removed)
- `addons/penta_tile/layouts/penta_tile_layout_penta_vertical.gd` (~40 LOC removed)
- **Total deletion: ~225 LOC**

Net Phase 2 delta (all .gd): 1961 - 559 = **+1402 LOC**
Net Phase 2 delta (runtime only): 1827 - 559 = **+1268 LOC**

## LOC Overage Analysis — Where Did the Extra Lines Come From?

The expected range was 1230-1530 (cumulative). The actual is 1961 (total) / 1827 (runtime).

Top three overrun contributors vs the per-file estimates:

| File | Expected | Actual | Delta | Reason |
|---|---|---|---|---|
| `penta_tile_synthesis.gd` | 250-400 LOC | 685 LOC | +285-435 | Gate 2 polygon clipping is more code than estimated: `_extract_tile_polygons`, `_synthesize_slot_polygons`, `_subrect_for_slot`, `_clip_segment_to_rect` (Liang-Barsky), and `_copy_polygons_to_tile_data` each run 30-60 lines. The three per-type loops (collision / occlusion / navigation) in both extract and synthesize paths contribute heavily. Rule 1 fixes (layer-count bounds, occluder API, layer mirroring) added ~24 LOC in Wave 6. |
| `penta_tile_layout_penta.gd` | 250-320 LOC | 388 LOC | +68-138 | Wave 6 added `resolve_active_mode`, `resolve_strip_modes`, `get_configuration_warnings_for` (+115 LOC spec, realized ~115 LOC actual). Estimate was for Waves 1-5 content only; Wave 6 scope was not back-propagated to the LOC budget table. |
| `penta_tile_map_layer.gd` | ~240-260 LOC | 377 LOC | +117-137 | Original 298 LOC file; estimate assumed -50 to -70 net. Actual delta was +39 (Wave 6). `_get_configuration_warnings`, `update_configuration_warnings()` calls (×3), `_ensure_synthesized_tile_set` extension with `resolve_active_mode`, `preload` const — all added LOC without offsetting deletions. Overlay deletion was ~-40 but net additions swamped it. |
| `tests/_capture_baseline.gd` | 0 (not in estimate) | 63 LOC | +63 | Test utility not anticipated in the LOC budget. |

**Key finding:** The LOC overage is driven by legitimate implementation scope (polygon clipping is inherently verbose; Wave 6 warnings/detection was not back-reflected in the per-file budget). However, the TOTAL is 31% above the hard trigger (~1500) which crosses the design-review threshold.

## Audit Decision

- [ ] **CLEAN** (TOTAL ≤ ~1400): execution within the lower half of the expected range; Phase 2 closes with no design review needed.
- [ ] **EXPECTED** (TOTAL 1400-1500): execution in the upper half; still within budget; no review needed.
- [x] **REVIEW REQUIRED** (TOTAL > 1500): hard design-review trigger fires.

**TOTAL = 1961 LOC (31% above the ~1500 hard trigger).** Investigate:

- **Polygon clipping verbosity:** `penta_tile_synthesis.gd` is 685 LOC vs 250-400 estimated. The Liang-Barsky `_clip_segment_to_rect` helper, the three per-type extract/synthesize loops (collision/occlusion/navigation in both `_extract_tile_polygons` AND `_synthesize_slot_polygons`), and the `_copy_polygons_to_tile_data` function together add ~200 lines of code that are intrinsic to the spec. They are NOT over-spec'd; they implement exactly what Gate 2 required. However, the budget estimate was too optimistic.
- **Wave 6 not back-propagated:** `resolve_active_mode` / `resolve_strip_modes` / `get_configuration_warnings_for` (+115 LOC) were Wave 6 additions not reflected in the CONTEXT.md per-file budget table.
- **Test utility file:** `_capture_baseline.gd` (63 LOC) was committed but not in the budget.
- **`penta_tile_map_layer.gd` net-add-not-net-delete:** The overlay deletion was ~-40 LOC but Wave 6 additions were +39 LOC net — so the file grew from 298 → 377 (+79) vs estimated ~240-260 post-Phase-2.

**Design review questions the user should resolve:**
1. Is the polygon clipping (collision/occlusion/navigation) via `_synthesize_slot_polygons` + `_extract_tile_polygons` warranted at this scope? Phase 2 success criterion 13 explicitly requires it ("synthesis collision support"). No over-spec'd code detected here.
2. Should `tests/_capture_baseline.gd` be excluded from LOC counts going forward (test utility, not runtime)?
3. Wave 6 AUTO/AUTO_STRIP detection + warnings added ~115 LOC to `penta_tile_layout_penta.gd`. Is this within the spirit of the Phase 2 scope or should it have been its own budget line?
4. Is the **runtime-only total of 1827 LOC** (excluding demo + tests) the more appropriate comparison vs TileMapDual (which also doesn't count its demo scenes in its LOC)?

## Identity Guardrail Check

TileMapDual reference: ~700-900 LOC for its core scripts (per PROJECT.md + ROADMAP.md). TileBitTools full addon: ~3800 LOC (includes EditorInspectorPlugin UI).

PentaTile after Phase 2:
- **All .gd files: 1961 LOC**
- **Runtime only (excluding demo + tests): 1827 LOC**

Identity constraint per PROJECT.md: "PentaTile must remain visibly smaller and simpler than TileMapDual."

- [x] **AT RISK** — PentaTile runtime (1827 LOC) is already 2-2.6× TileMapDual's core scripts (~700-900 LOC). The runtime hot path remains simpler (no terrain-rule trie, no persistent coordinate cache, no watcher/signal-fanout), but raw LOC is not favorable.
- [ ] **INTACT** if PentaTile total ≤ TileMapDual full-addon LOC (~1500-1800 with editor scripts)
- [ ] **VIOLATED** — approaches TileMapDual full-addon LOC

**Note for Phase 5 final audit:** The identity guardrail compares runtime hot-path complexity, not raw LOC. TileMapDual's core scripts (~700-900 LOC) handle terrain-rule tries, coordinate caches, and watcher systems that PentaTile deliberately omits. PentaTile's extra LOC comes from synthesis machinery (polygon clipping, image sub-region extraction) that is a one-time load-time cost. The per-tile runtime dispatch (_update_cells → layout.compute_mask → layout.mask_to_atlas → set_cell) remains a straight-line function without the branching complexity of terrain peers. This nuance should be called out in the Phase 5 release notes audit rather than treating raw LOC as the sole metric.

## Conclusion

- [x] Phase 2 **PAUSED PENDING DESIGN REVIEW** — LOC hard gate triggered (1961 total, 31% above ~1500 trigger).
- [x] Identity guardrail: **AT RISK** — runtime LOC exceeds TileMapDual core; hot-path complexity still simpler but warrants note in Phase 5 final audit.
- [x] Determinism test: **PASS** (recorded in `02-07-DETERMINISM-TEST.md`). All three sub-tests green. No code changes needed for determinism.
- [x] Phase 2 ROADMAP.md entry remains `[ ]` pending user decision on design review.
- [x] Next step: User should review the three design-review questions above and either (a) accept current LOC and close Phase 2, or (b) identify specific simplification targets.
