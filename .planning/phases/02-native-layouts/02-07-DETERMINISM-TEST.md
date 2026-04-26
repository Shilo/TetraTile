# Phase 2 Determinism Test (Wave 7 closeout)

**Captured:** 2026-04-26
**Phase:** 02-native-layouts
**Baseline reference:** `addons/penta_tile/tests/baselines/four_mode_5x5.txt`

## Test Setup

- Layout: `addons/penta_tile/demo/penta_layout_four_horizontal.tres` (axis=HORIZONTAL, tile_count=FOUR)
- Atlas source: demo's existing 4×1 TileSet (4 tiles authored at (0:0), (1:0), (2:0), (3:0) with collision)
- Painted region: 5×5 area matching demo scene's existing `tile_map_data`
- Test script: `addons/penta_tile/tests/determinism_test.gd` (extends SceneTree; runs headlessly)
- Hash method: `hash(Array(_primary_layer.tile_map_data))` — matches Wave 6 baseline method
  (`PackedByteArray.hash()` does not exist in Godot 4.6; GDScript builtin `hash()` on Array conversion used)
- Run command: `Godot_v4.6.2-stable_win64.exe --headless --path . --script addons/penta_tile/tests/determinism_test.gd`
- Godot version: 4.6.2.stable.official.71f334935

## Results — Sub-test (a): transform_vertex Worked Example (Gate 2)

Vertex `v = Vector2(0.25, 0.75)`. Each row asserts `transform_vertex(v, flags) == expected_out`.
Implementation: TRANSPOSE first, then FLIP_H, then FLIP_V (canonical order matching Godot internals).

| Flag combo | Flags (decimal) | Expected output | Actual output | PASS |
|---|---|---|---|---|
| identity | 0 | (0.25, 0.75) | (0.25, 0.75) | yes |
| FLIP_H | 4096 | (-0.25, 0.75) | (-0.25, 0.75) | yes |
| FLIP_V | 8192 | (0.25, -0.75) | (0.25, -0.75) | yes |
| FLIP_H + FLIP_V | 12288 | (-0.25, -0.75) | (-0.25, -0.75) | yes |
| TRANSPOSE | 16384 | (0.75, 0.25) | (0.75, 0.25) | yes |
| TRANSPOSE + FLIP_H | 20480 | (-0.75, 0.25) | (-0.75, 0.25) | yes |
| TRANSPOSE + FLIP_V | 24576 | (0.75, -0.25) | (0.75, -0.25) | yes |
| TRANSPOSE + FLIP_H + FLIP_V | 28672 | (-0.75, -0.25) | (-0.75, -0.25) | yes |

**Sub-test (a) verdict: PASS** — all 8 flag combinations produce the exact expected output from 02-02-PLAN.md Gate 2.

Console output: `Sub-test (a) — transform_vertex worked example: PASS (8 combinations)`

## Results — Sub-test (b): clip_polygon_to_subrect Determinism

Test inputs (fixed):
- Polygon: `[Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(0,1)]`
- Sub-rect: `Rect2(0.25, 0.25, 0.5, 0.5)`
- Full tile size: `Vector2(1.0, 1.0)`
- Hash method: `hash(Array(PackedVector2Array))` — GDScript builtin hash on Array conversion

| Run | output.hash() | Matches Run 0 |
|---|---|---|
| 0 | 4100093049 | n/a |
| 1 | 4100093049 | yes |
| 2 | 4100093049 | yes |
| 3 | 4100093049 | yes |
| 4 | 4100093049 | yes |
| 5 | 4100093049 | yes |
| 6 | 4100093049 | yes |
| 7 | 4100093049 | yes |
| 8 | 4100093049 | yes |
| 9 | 4100093049 | yes |

All 10 hashes equal `4100093049`.

**Sub-test (b) verdict: PASS** — `clip_polygon_to_subrect` produces identical bit-stable output across 10 consecutive invocations. No hidden randomness or dictionary-iteration-order leak detected.

Console output: `Sub-test (b) — clip_polygon_to_subrect determinism: PASS (10 invocations, hash=4100093049)`

## Results — Main Test (Rebuild Loop)

| Run | Hash | Matches Baseline | Matches Run 0 |
|---|---|---|---|
| 0 (initial rebuild) | 2986698704 | yes | n/a |
| 1 | 2986698704 | yes | yes |
| 2 | 2986698704 | yes | yes |
| 3 | 2986698704 | yes | yes |
| 4 | 2986698704 | yes | yes |
| 5 | 2986698704 | yes | yes |
| 6 | 2986698704 | yes | yes |
| 7 | 2986698704 | yes | yes |
| 8 | 2986698704 | yes | yes |
| 9 | 2986698704 | yes | yes |
| 10 | 2986698704 | yes | yes |

BASELINE_HASH from `addons/penta_tile/tests/baselines/four_mode_5x5.txt`: **2986698704**

All 11 hashes (Run 0 + 10 re-runs) are identical AND match the Wave 6 baseline.

Console output: `MAIN TEST PASSED — 10 re-runs identical AND match BASELINE_HASH=2986698704`

## Verdict — Composite (main + sub-tests a + b)

- [x] **PASS** — All three sub-results green: (1) all 11 main hashes identical AND match `BASELINE_HASH` from `addons/penta_tile/tests/baselines/four_mode_5x5.txt`; (2) all 8 transform_vertex rows match expected output verbatim from 02-02-PLAN.md Gate 2 table; (3) all 10 clip_polygon_to_subrect hashes identical.
- [ ] **FAIL — internal inconsistency (main)**
- [ ] **FAIL — baseline mismatch (main)**
- [ ] **FAIL — sub-test (a) transform_vertex**
- [ ] **FAIL — sub-test (b) clip_polygon_to_subrect**

## Notes

- **PENTA-SYNTH-06 invariant confirmed:** synthesis re-runs only when `(layout, axis, tile_count, source tile_set)` changes. The test invokes `_on_layout_changed()` between runs to force cache invalidation; the subsequent `rebuild()` re-runs synthesis from scratch and produces bit-identical output.
- **Cache-hit path not tested here** (intentional): idempotence guard in `_ensure_synthesized_tile_set` returns the cached TileSet without re-synthesis when the signature is unchanged. That path is its own form of determinism (returns a fixed reference) and is exercised by the demo's normal operation.
- **Baseline hash method note:** `hash(Array(PackedByteArray))` is used because `PackedByteArray.hash()` does not exist in Godot 4.6. This matches the Wave 6 capture method documented in `four_mode_5x5.txt`.
- **Test file committed:** `addons/penta_tile/tests/determinism_test.gd` is committed alongside this report for future re-runs. Phase 5 / future regressions can re-run it headlessly.
- **Exit code:** Godot exited with code 0 (all assertions passed; no `quit(1)` path triggered).
