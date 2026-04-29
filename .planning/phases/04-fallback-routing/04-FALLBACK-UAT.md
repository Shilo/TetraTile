---
status: complete
phase: 04-fallback-routing
source: [04-CONTEXT.md (D-04-05, D-04-06, D-04-07)]
started: 2026-04-29T13:31:50Z
updated: 2026-04-29T14:08:41-07:00
---

# Phase 4 Fallback-Routing Manual UAT

## Current Test

All 9 tests passed. Manual demo eyeball sign-off approved by user on 2026-04-29, backed by `fallback_routing_test.gd` and the full 18-test suite.

## Tests

### 1. Penta fallback eyeball pass (PREVIEW-03 per D-04-05)
expected: With `layout = PentaTileLayoutPenta.new()` and no manual `tile_set`
assigned, `addons/penta_tile/demo/penta_tile_demo.tscn` paints visibly correct
tiles for a small drag-painted region. No editor errors, no empty cells.
result: pass
Signed-off: user 2026-04-29
note: Manual demo eyeball approved; `fallback_routing_test.gd` composed the fallback-rendered canvas for this layout and reported PASS.

### 2. DualGrid16 fallback eyeball pass (PREVIEW-03)
expected: Same shape as #1 with `layout = PentaTileLayoutDualGrid16.new()`.
result: pass
Signed-off: user 2026-04-29
note: Manual demo eyeball approved; `fallback_routing_test.gd` composed the fallback-rendered canvas for this layout and reported PASS.

### 3. Wang2Edge fallback eyeball pass (PREVIEW-03)
expected: Same with `PentaTileLayoutWang2Edge.new()`.
result: pass
Signed-off: user 2026-04-29
note: Manual demo eyeball approved; `fallback_routing_test.gd` composed the fallback-rendered canvas for this layout and reported PASS.

### 4. Wang2Corner fallback eyeball pass (PREVIEW-03)
expected: Same with `PentaTileLayoutWang2Corner.new()`.
result: pass
Signed-off: user 2026-04-29
note: Manual demo eyeball approved; `fallback_routing_test.gd` composed the fallback-rendered canvas for this layout and reported PASS.

### 5. Min3x3 fallback eyeball pass (PREVIEW-03)
expected: Same with `PentaTileLayoutMinimal3x3.new()`.
result: pass
Signed-off: user 2026-04-29
note: Manual demo eyeball approved; `fallback_routing_test.gd` composed the fallback-rendered canvas for this layout and reported PASS.

### 6. Blob47Godot fallback eyeball pass (PREVIEW-03)
expected: Same with `PentaTileLayoutBlob47Godot.new()`.
result: pass
Signed-off: user 2026-04-29
note: Manual demo eyeball approved; `fallback_routing_test.gd` composed the fallback-rendered canvas for this layout and reported PASS.

### 7. PixelLabTopDown fallback eyeball pass (PREVIEW-03)
expected: Same with `PentaTileLayoutPixelLabTopDown.new()`.
result: pass
Signed-off: user 2026-04-29
note: Manual demo eyeball approved; `fallback_routing_test.gd` composed the fallback-rendered canvas for this layout and reported PASS.

### 8. PixelLabSideScroller fallback eyeball pass (PREVIEW-03)
expected: Same with `PentaTileLayoutPixelLabSideScroller.new()`.
result: pass
Signed-off: user 2026-04-29
note: Manual demo eyeball approved; `fallback_routing_test.gd` composed the fallback-rendered canvas for this layout and reported PASS.

### 9. PREVIEW-04 user-override regression (per D-04-06 belt+suspenders)
expected: Assigning a custom `tile_set` directly flips `_tile_set_is_fallback`
to false; clearing back to null + re-assigning `layout` re-routes to fallback.
Verified via inspector and by `addons/penta_tile/tests/fallback_routing_test.gd`
sub-tests `_test_preview_04_override` + `_test_preview_04_reroute` +
`_test_preview_04_user_tileset_preserved` (SC-4 regression).
result: pass
Signed-off: user 2026-04-29
note: Manual demo eyeball approved. Programmatic backing: `_test_preview_04_override`, `_test_preview_04_reroute`, and `_test_preview_04_user_tileset_preserved` all passed in `fallback_routing_test.gd`.

## Summary

total: 9
passed: 9
partial: 0
pending: 0
issues: 0
skipped: 0
blocked: 0

## Gaps

None.

## Closure Notes

Manual demo eyeball sign-off approved by user on 2026-04-29 for all 8 actually-shipped layouts and the PREVIEW-04 override/reroute contract. Programmatic backing: `fallback_routing_test.gd` passed directly and through `run_tests.ps1`; the full suite reported `ALL GREEN (18 tests)`.
