---
gsd_state_version: 1.0
milestone: v0.2.0
milestone_name: milestone
status: ready_to_plan
stopped_at: Phase 3 closed (Plan 06 complete; D-86 = b reduced scope; Tilesetter deferred to v0.3+); Phase 4 (Fallback Routing) is next planning step
last_updated: "2026-04-29T08:08:59.763Z"
last_activity: 2026-04-29
progress:
  total_phases: 8
  completed_phases: 5
  total_plans: 21
  completed_plans: 21
  percent: 63
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-25 after v0.2 pivot to layout library)

**Core value:** Painting tiles with the native `TileMapLayer` API produces correct dual-grid autotiled visuals — without the user maintaining caches, terrain metadata, or 16-tile blob sets.
**Current focus:** Phase 03 — Public-Convention Layouts (Blob47 + Tilesetter)

## Current Position

Phase: 06
Plan: Not started
Status: Ready to plan
Last activity: 2026-04-29

> Phase 03 closed 2026-04-29 with reduced scope per D-86 = (b). Blob47Godot shipped (TBT-03 + TEMPLATE-02 partial); audit deliverable + README footnote landed (TBT-04, DOC-05); 8-Moore single-grid propagation patch landed (D-87); Tilesetter pair + Tilesetter half of TEMPLATE-02 deferred to v0.3+ backlog (`TBT-01-DEFERRED` / `TBT-02-DEFERRED` / `TEMPLATE-02-DEFERRED`). Plan 06 (closeout) extended `comprehensive_bitmask_test` + `bitmask_bounds_test` with Blob47Godot, added 2 new 8-Moore-revealing patterns (plus_with_diagonals, diag_chain), recorded the deferred-backlog entries in REQUIREMENTS.md, and flipped Phase 3 ROADMAP entry to `[x]`.

Progress: [██████████] 100%

> Out-of-band progress: 5 of 8 greyboxed template PNGs + the generator script shipped in commit e86036f as part of the discovery pass. Counted as TEMPLATE-01 + TEMPLATE-03 covered. The remaining 3 templates (Blob47Godot, TilesetterWang15, TilesetterBlob47) ship in Phase 3 once their slot tables are transcribed from TileBitTools.

## Performance Metrics

**Velocity:**

- Total plans completed: 11
- Average duration: —
- Total execution time: 0.0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01 | 5 | - | - |
| 03 | 6 | - | - |

**Recent Trend:**

- Last 5 plans: —
- Trend: —

*Updated after each plan completion*
| Phase 02 P01 | 147 | 2 tasks | 3 files |
| Phase 02 P02 | 539 | 3 tasks | 8 files |
| Phase 02 P03 | 331 | 2 tasks | 5 files |
| Phase 02-native-layouts P4 | 91 | 4 tasks | 4 files |
| Phase 02 P05 | 209 | 2 tasks | 16 files |
| Phase 02 P06 | 850 | 2 tasks | 9 files |
| Phase 02-native-layouts P7 | 272 | 2 tasks | 4 files |
| Phase 03 P02 | 9min | 1 tasks | 1 files |
| Phase 03 P03 | 3min | 2 tasks tasks | 3 files files |
| Phase 03 P01 | 12min | 2 tasks tasks | 4 files files |
| Phase Phase 03 P04 P04 | 12min | 3 tasks tasks | 9 files files |
| Phase Phase 03 PP05 | 2min | 0 tasks (skipped) tasks | 1 file files |
| Phase 03 P06 | 25min | 2 tasks tasks | 5 files files |

## Accumulated Context

### Roadmap Evolution

- 2026-04-26: Phase 2.1 inserted after Phase 2 (single-tile-layout) — ships `PentaTileLayoutSingleTile`. Adds 5 requirements (SINGLE-01..05). Companion artifact: `.planning/research/layouts/RPG_MAKER.md` audits the RPG Maker family and recommends offline-importer path for v0.3+ — out of scope for v0.2.0.
- 2026-04-26 (later): **Architectural pivot — overlay-layer removal + unified Tetra synthesis.** The Phase 2.1 brainstorm session reframed Phase 2's Penta5 work. Instead of shipping `PentaTileLayoutPenta5Horizontal`/`Vertical` as separate classes (CONTEXT.md D-28..D-46), the existing Tetra layouts gain load-time synthesis of the 5th OppositeCorners archetype from the OuterCorner tile. The runtime `_overlay_layer` is **deleted entirely** — every v0.2 layout renders via single-layer 5-archetype dispatch. Tetra layouts auto-detect 4-vs-5 source tiles. Single-Tile (Phase 2.1) updated to slice into 5 archetypes (not 4). Adds 6 new requirements (PENTA-SYNTH-01..06), supersedes Phase 2's planned TETRA5-* IDs (which never landed in REQUIREMENTS.md). Multi-terrain Y-axis convention added to v2 backlog (MULTITERR-01..05) with explicit design-coupling note to VAR-01 (variation). Full supersession notice in `.planning/phases/02-native-layouts/02-DISCUSSION-LOG.md`. Coverage 50 → 56 requirements.
- 2026-04-26 (later): **User policy update — breaking changes always allowed.** Recorded as feedback memory + CLAUDE.md "Breaking Changes Policy (HARD RULE)" + PROJECT.md constraint update. Never write backwards-compat shims. Never defer features for compat reasons. CHANGELOG entries are the only acceptable compat work.
- 2026-04-26 (later): **Phase 2.1 collapsed back into Phase 2 — TETRA1 mode folded into the Tetra layout via auto-detect.** The unified `PentaTileLayoutPentaHorizontal`/`Vertical` classes now handle three modes (TETRA1 / TETRA4 / TETRA5) via auto-detection of the source atlas strip-axis tile count. `TileCountMode` enum (`AUTO` / `TETRA1` / `TETRA4` / `TETRA5`) provides explicit override. Single class per axis covers all modes; SINGLE-01..05 retired and PENTA-SYNTH-* expanded from 6 to 9 requirements. Phase 2.1 directory removed (was empty). Coverage 56 → 54. Total phases 7 → 6. Naming convention: enum members use `TETRA1`/`TETRA4`/`TETRA5` (UPPER_SNAKE_CASE per GDScript style); requirement IDs remain `PENTA-SYNTH-*`. Full algorithm + edge-case handling captured in Phase 2 DISCUSSION-LOG D-53..D-55.
- 2026-04-26 (later): **Phase 1.1 inserted after Phase 1: PentaTile Rename + Penta Codename Establishment (URGENT).** Project-wide rename `Tetra` → `Penta` / `penta` → `penta` (~2,398 occurrences across 86 files) before Phase 2 ships new files under the old name. Coins "Penta" as the project's tileset codename (Blob/Wang style) — a descriptive, unowned label propagated through a canonical "What is a Penta tileset?" README definition. Driver: v0.2 pivot adds a 5th archetype (OppositeCorners) and TileCountMode FIVE — the project's identity is shifting from "4-tile autotiler" to "5-archetype autotiler," so the name follows the identity. Scope (in): source code (classes, file/folder names, plugin.cfg), saved resources (.tscn/.tres/.uid + custom data layer keys `penta_role`/`penta_lock_rotation`), planning docs (.planning/**, CLAUDE.md, ROADMAP.md, README), coined-terms discipline appended to CLAUDE.md as a project invariant, **AND repo rename + git tracking** — GitHub repo rename (manual user action via UI), local origin URL update via `git remote set-url`, local directory rename `c:\Programming_Files\Shilocity\PentaTile\` → `...\PentaTile\`, paired with Claude memory directory migration `mv c--Programming-Files-Shilocity-PentaTile c--Programming-Files-Shilocity-PentaTile`. Per the no-compat policy, no deprecation aliases — clean rename, CHANGELOG the breakage. Native flexible-count layout class is `PentaTileLayoutPenta` (matches `PentaTileLayout<FormatName>` pattern). Roadmap convention: user-facing text unpadded (`Phase 1.1`, `Phase 3.5`); directory + filenames zero-padded (`01.1-...`, `01.1-CONTEXT.md`). Memory: see `project_pentatile_rename.md`. Full scope + 6-wave structure in `.planning/phases/01.1-pentatile-rename-penta-codename-establishment/01.1-CONTEXT.md`.
- 2026-04-26 (later): **Phase 1.1 (PentaTile Rename + Penta Codename Establishment) complete.** Project renamed end-to-end: GDScript classes (`PentaTile*`), addon folder (`addons/penta_tile/`), plugin.cfg, project.godot, all .tscn/.tres/.import resources, all .planning/** docs, requirement IDs (`PENTA-*` / `PENTA-SYNTH-*`), GitHub repo (`PentaTile`), local working directory, Claude memory directory. Coined "Penta" as the 5-archetype tileset codename via canonical README section ("What is a Penta tileset?") + CLAUDE.md "Coined-Term Discipline" project invariant. CHANGELOG.md created with v0.2 BREAKING entry. Phase 2 next.
- 2026-04-26 (Phase 2 execution): **All 7 Phase 2 waves shipped.** Wave 0: verification migration spec. Wave 1: AtlasSlot trim + bitmask_template rename + get_fallback_tile_set virtual stub. Wave 2: PentaTileSynthesis engine (Liang-Barsky polygon clipper, Gate 1 Path B OuterCorner, Gate 2 transform order, signature-based idempotence). Wave 3: PentaTileLayoutPenta merged class (axis × tile_count enums, AUTO_STRIP=-1 sentinel, H-1 + H-4 fixes). Wave 4: 4 native layouts (DualGrid16, Wang2Edge, Wang2Corner, Min3x3) committed atomically (91f69a2). Wave 5: bundled bitmask PNGs co-located + _generate_bitmasks.py rewritten + README retargeted. Wave 6: AUTO/AUTO_STRIP detection + configuration warnings + FOUR-mode demo binding. Wave 7: LOC checkpoint (1827 runtime LOC, 31% over ~1500 trigger; AT RISK noted for Phase 5 final audit) + determinism test PASS (BASELINE_HASH=2986698704). 30/30 Phase 2 requirements satisfied per programmatic verification.
- 2026-04-26 (post-execution review pass 1): **Initial code review.** Spawned `/gsd-code-review 2`; produced 02-REVIEW.md with 6 Warning findings (WR-01..WR-06) + 9 Info findings (IN-01..IN-09). Commit `eec027d`.
- 2026-04-26 (post-execution audit): **Independent third-party audit by codex-rescue subagent.** Surfaced WR-07 — latent BLOCKER in `PentaTileLayoutPenta._make_slot()`: VERTICAL axis returned `Vector2i(0, slot_index)` but synthesizer always builds horizontal strip with tiles at `(0..N, 0)` — every VERTICAL paint would have produced empty cells in production. Documented in 02-REVIEW.md as 7th Warning. Commit `8113ea1`.
- 2026-04-26 (code-review-fix): **All 7 WR fixes landed atomically across 7 commits.** WR-07 `ea0ba23` (axis-invariant `_make_slot`), WR-01 `ae5d787` (canonical Sutherland-Hodgman replacement), WR-02 `9ca342e` (mode-resolution before cache signature), WR-03 `d74df0e` (`strip_origin` sentinel param), WR-04 `2ca04e0` (typed `_bundled_png_path` accessor with mode assert), WR-05 `720f017` (`fill_rect` for SLOT_INNER_CORNER quadrant), WR-06 `79af1e3` (README refresh to match Phase 2 architecture). All 9 prior Info items left at their original dispositions per their Phase 3.5 / cosmetic / accepted-tradeoff classifications.
- 2026-04-26 (re-review): **Second code review pass after WR fixes.** Verified all 7 WR fixes correct; added IN-10 (WR-02 fix covers AUTO mode drift but not in-place TileSet pixel mutations under explicit modes — Phase 3.5 territory). Status: clean. Commit `49852b9`.
- 2026-04-26 (VERTICAL baseline addition): **WR-07 regression net.** User-authored test commit `673ace0` adds `addons/penta_tile/demo/penta_layout_four_vertical.tres` (axis=1, tile_count=4 mirror of horizontal demo layout), `--layout-path=<res_path>` CLI flag in `_capture_baseline.gd`, and Sub-test (c) in `determinism_test.gd` that asserts (1) painted cell count matches `BASELINE_CELLS=46` from HORIZONTAL, (2) every painted cell's atlas coord exists in synthesized atlas via `source.has_tile()`. Catches WR-07's two failure modes (cell-drop AND unrenderable-coord) without requiring a per-axis pixel-hash baseline (post-WR-07 both axes produce identical `tile_map_data` hashes). All 4 sub-tests pass.
- 2026-04-26 (third review pass): **Third code review pass after VERTICAL baseline.** Re-verified all 7 WR fixes once more; surfaced 3 new cosmetic Info items in test scaffolding: IN-11 (`--layout-path` parse loop never `break`s on duplicate flags), IN-12 (`LAYOUT_OVERRIDE` print silently emits `axis=0` for non-Penta layouts via `int(null)`), IN-13 (header doc-comment doesn't list sub-test (c)). All 3 fixed atomically in commit `c9a6aa9`. Third-pass review report committed at `aa07ac1`. Final REVIEW.md status: clean (0 Critical, 0 Warning, 13 Info — IN-01..IN-13).
- 2026-04-28: **Phase 6 added — Editor Line/Rect/Bucket Tool Preview During Drag (far-future, deferred).** Captures a known issue: when a `layout` is bound, the editor's line/rect/bucket tools show no preview during the drag because Godot 4.6 multiplies the preview-overlay alpha by `edited_layer.self_modulate`, and PentaTile zeroes `self_modulate.a` via `logic_layer_opacity = 0` to hide the parent's raw cells. Verified against Godot 4.6 source (`editor/scene/2d/tiles/tile_map_layer_editor.cpp` lines 875-990). TileMapDual works around this with a ghost shader material; PentaTile has two candidate paths: (a) ghost-material refactor (~30 LOC, raw preview, breaking change to `logic_layer_opacity`), or (b) custom `EditorPlugin` with `forward_canvas_draw_over_viewport` (full new phase, true dispatched preview). Decision deferred to plan phase — re-verify the open questions in `.planning/research/editor-line-rect-preview.md` before committing (Godot may add atlas-redirect to `_tile_data_runtime_update`, expose preview state to scripts, or add a per-layer preview hook). Defer until after v0.2.0 ships. Companion artifacts: `.planning/research/editor-line-rect-preview.md`, `.planning/todos/pending/2026-04-28-re-research-editor-line-rect-tool-preview-during-drag.md`.
- 2026-04-28 (UAT-driven bug-fix sweep): **7 bug classes resolved across 15 commits (6553380..205fb67) + planning artifacts updated.** Cycle started with edge-greybox plus-arms causing visible dark squares between cells in a painted Min3x3/Wang2Edge region (`7cffd73`). Iterated through corner-cuts (`ef46977`), solid 32×32 (`9183d07`), back to corner-cuts (`fce112f`), back to solid (after realizing Penta is actually a clean rectangle, not rounded-corners). Layer-level fix (`a9d9716`) made single-grid layouts only render logic-painted cells (background extension cells stay unrendered, painted region's pixel bbox = user_cells × tile_size). Wang2Corner gained its own solid 32×32 atlas (`022af2e`) — DualGrid16's partial-quadrant atlas was unsuitable for single-grid composition. Single-grid mask=0 dispatch added (`81813cd`) so isolated 1×1 cells and 1×N lines (especially Wang2Corner where straight lines have no diagonals) render. Penta + user's ground.tres exposed orange-line bleed into hollow-region holes (`205fb67`); root cause was artist drawing inner-corner outline at col 8 of slot 3's TR-cut quadrant — pixels rotation-mapped into adjacent painted cells via TRANSPOSE/FLIP_H/FLIP_V; fix is `PentaTileSynthesis._apply_canonical_silhouette()` enforcing per-archetype expected opaque region during authored-slot extraction (FOUR/FIVE modes). Test suite grew from 9 → 12: added `bitmask_bounds_test` (per-slot expected silhouette), `comprehensive_bitmask_test` (16 patterns × 5 layouts × bbox + solidity + cell-coverage), `penta_ground_hollow_test` (user-fixture hollow ring + hole emptiness). Fortified `all_layouts_swap_pixel_test` with edge-continuity + interior coverage + bbox + per-cell solidity assertions. Methodology lessons codified in `CLAUDE.md` § Test Methodology, three new Critical Pitfalls (#8 single-grid logic-painted gate, #9 single-grid mask=0 dispatch, #10 Penta canonical-silhouette enforcement), and full retrospective in `.planning/phases/02-native-layouts/02-UAT-LESSONS-LEARNED.md`. Cross-session memory: `feedback_visual_testing.md` + `feedback_root_cause_discipline.md`. All 12 tests green at commit `99687ca`.
- 2026-04-29: **Phase 3 closed.** Public-Convention Layouts shipped under D-86 option (b): Blob47Godot only (Tilesetter pair deferred to v0.3+) — 1 layout + 1 bundled PNG + 3 new tests (`blob_47_collapse_test`, `blob_47_hollow_test`, `single_grid_8_moore_propagation_test`) + 1 audit deliverable (`03-TBT-DEEP-AUDIT.md`) + 1 README footnote + 8-Moore single-grid propagation pipeline patch (D-87). REQUIREMENTS.md gains `TBT-01-DEFERRED` / `TBT-02-DEFERRED` / `TEMPLATE-02-DEFERRED` v2 backlog entries; Traceability table marks TBT-03 / TBT-04 / DOC-05 Complete; TEMPLATE-02 marked Partial (Blob47Godot half ships; Tilesetter half deferred). ROADMAP Phase 3 row flipped to `[x]` 2026-04-29 with completion summary. Cumulative runtime GDScript LOC measured directly: ~2455 (sum of `addons/penta_tile/**/*.gd` excluding `tests/` and `demo/`). Phase 2 close baseline reported 1827; the difference vs the +121 LOC actually added in Phase 3 is methodology drift — Phase 2's 1827 figure pre-dated several refinements + .uid-sidecar accounting. Identity guardrail: AT RISK carry-forward — final formal gate is Phase 5 audit vs TileMapDual. No ATTRIBUTION.md created (D-73 final guard verified). 47-blob layout sourced from BorisTheBrave (D-74). Tilesetter slot tables: D-86 = (b) defer. Test suite grew 12 (Phase 2 close) → 15 (Phase 3 close); matrix combos grew 5×16=80 → 6×18=108 in `comprehensive_bitmask_test`. Phase 4 (Fallback Routing) is the next planning step.
- 2026-04-27 (UAT-driven AUTO_STRIP completion): **AUTO_STRIP per-strip dispatch un-deferred and shipped retroactively** (commit `29cba37`). Discovered during user UAT that AUTO_STRIP rendered nothing — Wave 6 had explicitly deferred per-strip dispatch to Phase 5, but the deferral was buried in the summary and the verifier marked SC-7 ✓ on detector existence alone (`resolve_strip_modes()` was implemented but never called). Sweep also surfaced a same-file spec contradiction: Wave 2's `synthesize_strip` docstring described Interpretation B (cumulative offset along slot axis); Wave 6's `resolve_strip_modes` implemented Interpretation A (strips perpendicular to slot axis). A locked. Fix: layer's `_ensure_synthesized_tile_set` now branches on AUTO_STRIP, calls `resolve_strip_modes`, threads cumulative `strip_origin` per strip, builds 5×N synthesized atlas (single source, output coord = `Vector2i(slot, strip_index)`); `mask_to_atlas` + `_make_slot` gain `strip_index: int = 0` parameter; new virtual `resolve_display_strip` returns first-non-empty-neighbor's source-atlas-coord (TL→TR→BL→BR canonical order); Penta-only override (non-Penta layouts use base default = 0). Bonus bug found: `resolve_strip_modes` was treating trailing empties as gaps; now only flags "empty-then-populated" patterns. paint_test grew 4 new AUTO_STRIP cases (uniform [3,3] HORIZONTAL, mixed [3,5] HORIZONTAL, gap-with-warning-C, VERTICAL [4,2]) — ALL PASS. Determinism BASELINE_HASH=2986698704 still holds across 11 runs. Documented Gate 1 OuterCorner-via-rotation tradeoff stays as locked spec; user accepts; data-side fix path is artist-authored faded slot 0. Workflow-quality root cause logged: verifier checked existence not wiring; deferrals weren't loud at sign-off; demo bound only FOUR mode so non-FOUR coverage required manual `.tres` swap.

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- v0.2 pivot from "expand the contract" (variation + top tiles + non-rotating) to "layout library" (8 pluggable layout Resources)
- ~~Layout = typed `Resource` subclass (`PentaTileLayout`) hung off `PentaTileAtlasContract`, NOT a `RotationMode` enum on the contract~~ — **Superseded** by 2026-04-26 architectural simplification: `PentaTileAtlasContract` deleted; `layout: PentaTileLayout` lives directly on `PentaTileMapLayer`. See newer entry below.
- ~~Each layout exposes `template_image: Texture2D` + `fallback_tile_set: TileSet` + `description: String` for inspector preview and zero-config prototyping~~ — **Superseded**: `template_image` renamed `bitmask_template`; `fallback_tile_set` @export deleted (now virtual `get_fallback_tile_set()`); `description: String` retained.
- Tilesetter slot tables transcribed from TileBitTools (MIT, attributed) rather than empirically fingerprinted
- Tilesetter Wang is 15 tiles in 5×3, not 16 in 4×4 (per TBT verified slot table)
- Tilesetter Blob is 11×5 with sub-block gaps, not 7×8 (per TBT verified slot table)
- Variation, top tiles, "non-rotating" pushed to a future milestone — DualGrid16/Wang2Corner/Wang2Edge layouts cover the asymmetric-art case the user wanted
- Excalibur/jaconir/Stormcloak/OpenGameArt CR31 dropped from the layout library (no Godot adoption signal)
- Godot `MATCH_SIDES` skipped (engine semantics disputed in issue #79411)
- RPG Maker A2/A4 architecturally reserved (subtile compositor) but deferred to v0.3+
- PentaTile does NOT integrate with Godot's stock terrain peering bits (defeats v0.1's "no manual bitmask authoring" selling point)
- TileBitTools' `EditorInspectorPlugin` architecture explicitly not copied (3,800-LOC editor UI conflicts with PentaTile's "small runtime + no editor polish" identity)
- **Breaking changes always allowed and encouraged** (user policy 2026-04-26). Never write backwards-compat shims; never defer features because they would break v0.1. CHANGELOG entries are the only acceptable compat work. CLAUDE.md "Breaking Changes Policy (HARD RULE)" formalizes this; PROJECT.md constraint updated.
- **Overlay-layer removal + unified 5-archetype synthesis** (2026-04-26). All v0.2 layouts render via single-layer 5-archetype dispatch. Penta layouts auto-detect source tile counts (1/2/3/4/5) and synthesize the missing archetypes from slot 0 (IsolatedCell). `_overlay_layer`, `_paint_overlay_for_slot`, `AtlasSlot.diagonal_complement_atlas_coords`, and the planned `needs_diagonal_overlay()` virtual are all deleted. FOUR-mode regression baseline is a fresh capture (slot ordering changed; not v0.1 bit-equivalence). Phase 2 supersedes the previously-planned separate Penta5* layout classes. See `.planning/phases/02-native-layouts/02-DISCUSSION-LOG.md` SUPERSESSION rounds for D-47..D-71.
- **Multi-terrain in v2 backlog** (MULTITERR-01..05) with explicit design-coupling to VAR-01 (Y-axis variation) — both compete for atlas Y-axis interpretation; future brainstorm must resolve them together. Strip layouts (Penta, Single-Tile / Penta ONE) use Y-as-terrain; block layouts (DualGrid16, Wang*, PixelLab) need a different mechanism (likely multiple atlas sources).
- **Architectural simplification sweep** (2026-04-26 third pivot): `PentaTileAtlasContract` deleted entirely (had a speculative `version: int` no consumer read; per the no-forward-compat policy, deleted). `layout: PentaTileLayout` lives directly on `PentaTileMapLayer`. `PentaTileLayoutPentaHorizontal`+`Vertical` merged into `PentaTileLayoutPenta` with `axis: Axis` and `tile_count: TileCountMode` (`AUTO`/`ONE`/`FOUR`/`FIVE`) enums. `template_image` renamed `bitmask_template`; `fallback_tile_set` hidden from inspector (codegen via `get_fallback_tile_set()`); `decoder_image` deleted. Templates restructured to `templates/[layout_name]/{atlas.png, bitmask.png}` per layout. PIXLAB-03 variation-bank pick moved to v2 backlog as VAR-PIXEL-01. Phase 1 still listed Complete but its CONTRACT-* / PENTA-01..03 / PREVIEW-01 / LAYOUT-03/04 are all reworked in Phase 2 — Phase 1 is partially superseded. Coverage 54 → 53 reqs.
- **No-forward-compat policy** added 2026-04-26 alongside the existing no-backwards-compat rule. CLAUDE.md "Breaking Changes Policy (HARD RULE)" now covers BOTH directions: never write compat shims AND never speculate about forward versioning (`version: int` fields, schema markers, speculative extension points). Both rules captured in `feedback_breaking_changes.md` Claude memory.
- **Five-mode progressive Penta design — locked** (2026-04-26 fourth pivot). Penta now supports five `tile_count` modes (`ONE`/`TWO`/`THREE`/`FOUR`/`FIVE`) plus `AUTO` (dimension-only) and `AUTO_STRIP` (per-strip detection). New slot ordering: `0=IsolatedCell, 1=Fill, 2=Border, 3=InnerCorner, 4=OppositeCorners`. **OuterCorner is implicit** — synthesized from slot 0's corners across all modes; never has a dedicated slot. Border at slot 2 (before InnerCorner at slot 3) prioritizes visual frequency over fill-percentage ordering — Border is the most visible archetype after Fill. Rationale: each step from ONE to FIVE adds one more explicit archetype slot, sacrificing quality for less authoring time. Single PNG per layout serves as BOTH inspector preview AND fallback TileSet source (no atlas/bitmask split). Templates folder deleted; bundled PNGs co-locate next to layout `.gd` files. Penta has 10 PNGs in `penta_tile_layout_penta/` subfolder; single-variant layouts use flat siblings. Coverage 53 → 56 reqs (added PENTA-SYNTH-10/11/12). Full design + decision history in `.planning/phases/02-native-layouts/02-DISCUSSION-LOG.md` FOURTH SUPERSESSION block.
- template_image renamed to bitmask_template on PentaTileLayout base class (LAYOUT-03/PREVIEW-01); no @export_storage compat shim per CLAUDE.md HARD RULE
- get_fallback_tile_set() virtual stub returns null in Wave 1; Wave 2 fills body with TileSet construction from bitmask_template (LAYOUT-06)
- PentaTileSynthesis utility class ships as RefCounted (@tool); synthesis path uses needs_synthesis() virtual to avoid forward type reference to PentaTileLayoutPenta (Wave 3)
- Tasks 2.2 and 2.3 combined into one atomic commit (b6349fa) — synthesis wiring required touching penta_tile_layout.gd (needs_synthesis virtual) which was already in the atomic sweep
- _DEFAULT_LAYOUT singleton deleted atomically with _resolve_layout rewrite in same commit per CONTEXT.md D-68 constraint
- needs_synthesis() overrides base to return true in PentaTileLayoutPenta — resolves Wave 2 stub for synthesis branch in PentaTileMapLayer
- _SLOT_* consts use literal ints in PentaTileLayoutPenta — GDScript 2 class-level const cannot reference another class's const at parse time
- Phase 1 PentaTileLayoutPentaHorizontal + Vertical merged into single PentaTileLayoutPenta with axis + tile_count enums (Wave 3 complete)
- Minimal3x3 open-side rule: masks 5/10 and diagonal-only states collapse to center tile (1,1) — accepted visual loss of 9-tile minimum
- Wang2Corner is single-grid sampling diagonal neighbors (NE/SE/SW/NW) — NOT dual-grid 2x2 corner quadrants; same mask%4/mask/4 formula as DualGrid16 but different bit semantics
- All 4 Wave 4 layouts committed atomically (91f69a2) — no inter-file dependencies; get_fallback_tile_set() returns null until Wave 5 PNGs ship
- line-70 README retarget -> four_horizontal.png (4-tile-template feel of v0.1); lines 5 and 30 -> five_horizontal.png (matches all-5-archetypes alt-text)
- TILE=32px for Phase 2 generator (doubles Phase 1 TILE=16); draw_edge_mask center hint rescaled proportionally
- Task 5.3 human-verify checkpoint auto-approved; IsolatedCell slot 0 geometry verified programmatically (TEMPLATE-04 pass)
- ~~resolve_active_mode returns AUTO_STRIP unchanged — per-strip dispatch deferred to Phase 5~~ — **Superseded 2026-04-27**: AUTO_STRIP per-strip dispatch shipped in commit `29cba37` after UAT exposed the gap. Layer now branches on AUTO_STRIP, calls `resolve_strip_modes`, builds 5×N synthesized atlas. See 2026-04-27 entry in Roadmap Evolution.
- BASELINE_HASH=2986698704 captured via headless Godot 4.6 for FOUR-mode determinism test (PENTA-SYNTH-12 / PENTA-03)
- preload() const _PentaTileSynthesis added to map layer — fixes class_name symbol failure in headless/--script mode
- LOC hard gate fired at Wave 7 closeout (1961 total / 1827 runtime LOC, 31% above ~1500 trigger) — Phase 2 ROADMAP left unchecked pending user design review; determinism test PASS with BASELINE_HASH=2986698704
- Identity guardrail AT RISK — runtime LOC (1827) is 2-2.6x TileMapDual core (~700-900 LOC); hot-path complexity still simpler (no terrain-rule trie, no coordinate cache, no watcher system); note for Phase 5 final audit
- AP-1..AP-10 anti-pattern register crystallized in 03-TBT-DEEP-AUDIT.md — every REJECT verdict cites an explicit identity guardrail; future plan-phases can reject TBT-derived ideas by AP-N reference rather than re-auditing.
- Two backlog seeds locked with concrete un-defer triggers: layout tags vocabulary (≥12 layouts, v0.3+) and Project Settings verbosity key (≥2 verbosity surfaces, v0.3+). Both seeds rename TBT identifiers to PentaTile-namespace equivalents.
- Save-custom-layout dialog REJECTED outright with no backlog file — reopening requires fresh design work per CLAUDE.md no-forward-compat rule.
- D-72/D-73 ratified across canonical docs: Phase 3 retitled 'Public-Convention Layouts (Blob47 + Tilesetter)' in ROADMAP/REQUIREMENTS; TBT-04 + DOC-05 rewritten to README footnote pattern; addons/penta_tile/ATTRIBUTION.md formally banned via Out-of-Scope rows; directory slug intentionally NOT renamed (RESEARCH § 11 Q7)
- **2026-04-29 (Phase 3 D-86 gate resolution):** User selected option b) per `03-01-PLAN.md` Task 1 checkpoint. Tilesetter layouts deferred to v0.3+. Plan 03-05 is dropped from Phase 3. REQUIREMENTS.md TBT-01 + TBT-02 + the Tilesetter half of TEMPLATE-02 move to v2/v0.3+ backlog (Plan 06 closeout records `TBT-01-DEFERRED` / `TBT-02-DEFERRED` / `TEMPLATE-02-DEFERRED`). Phase 3 ships ONLY `PentaTileLayoutBlob47Godot` (Plan 04) plus the audit (Plan 02), doc rewrites (Plan 03), and 8-Moore patch (Plan 01).

TILESETTER_DECISION: b

- D-86 RESOLVED — option (b) defer Tilesetter layouts to v0.3+. Plan 03-05 SKIPPED. TilesetterWang15 + TilesetterBlob47 + Tilesetter half of TEMPLATE-02 deferred to v2 backlog. Phase 3 ships Blob47Godot + audit + 8-Moore patch + req rewrites only. TILESETTER_DECISION: b
- D-87 8-Moore single-grid propagation patch landed (penta_tile_map_layer._mark_affected_single_grid_cells extended from 4 cardinals to 8 Moore neighbors). 4-cardinal layouts unaffected — extra diagonal cells hit existing logic-painted-only short-circuit. Verify-the-regression cycle confirmed (CLAUDE.md Test Methodology #5).
- Phase 3 Plan 04: Blob47Godot layout shipped — algorithmic 256→47 collapse rule + 47-entry _MASK_TO_ATLAS dict + 7×7 BorisTheBrave-canonical packing. blob_47_collapse_test verify-the-regression cycle confirmed. blob_47_hollow_test catches layout-level dispatch correctness (mask=0 fallthrough, hole emptiness, bbox); does NOT catch 8-Moore propagation regression under batch paint (that's the propagation test's job — Plan 01). Auto-fixed: _primary_layer access via Object.get() (not get_node — Node name is _PentaTileVisual); Godot --import pass required for new bundled PNG to be load()-able at runtime. 15/15 tests green.
- **2026-04-29 (Plan 05 SKIPPED):** D-86 resolved to option (b). PentaTileLayoutTilesetterWang15 + PentaTileLayoutTilesetterBlob47 deferred to v0.3+ backlog. Plan 06 (closeout) handles the REQUIREMENTS.md / ROADMAP.md / Coverage table updates (records TBT-01-DEFERRED / TBT-02-DEFERRED / TEMPLATE-02-DEFERRED v2 backlog entries). No source files / .pngs / tests created in Plan 05 — single SUMMARY-only commit captured the skip. Phase 3 cumulative runtime LOC unchanged at ~1948 (well below the 2500 informational concern). Plan 05 SUMMARY at `.planning/phases/03-tilebittools-sourced-layouts/03-05-SUMMARY.md`.
- 2026-04-29 (Phase 3 closeout — Plan 06): comprehensive_bitmask_test extended with Blob47Godot + 2 new 8-Moore-revealing patterns (plus_with_diagonals, diag_chain); bitmask_bounds_test extended with explicit gap_cells: Array[Vector2i] whitelist parameter (W-3 fix — no Callable() universal skip). Matrix combos grew 80 → 108. Phase 3 closed at cumulative ~2455 runtime LOC (direct measurement) with methodology-drift note vs Phase 2's 1827 baseline. Identity guardrail AT RISK carry-forward to Phase 5 final audit.
- 2026-04-29 (Phase 3 closeout — Plan 06): TBT-01-DEFERRED + TBT-02-DEFERRED + TEMPLATE-02-DEFERRED added to REQUIREMENTS.md v2 Requirements section (B-2 coverage-invariant fix). Original TBT-01/02 IDs stay in Traceability with Status='Deferred to v0.3+'; TEMPLATE-02 marked Partial (Blob47Godot half ships; Tilesetter half deferred). ROADMAP Phase 3 row flipped to [x] with 2026-04-29 completion date. ATTRIBUTION.md verified absent (D-73 final guard).

### Pending Todos

- **Re-research editor line/rect/bucket tool preview during drag** (`general`, far-future) — preview invisible when `layout` is bound because Godot's editor draws the line/rect preview as a viewport overlay multiplied by `self_modulate.a`, which PentaTile zeroes via `logic_layer_opacity=0`. Two paths on revisit: (a) ghost-material refactor for raw preview parity with TileMapDual (~30 LOC, breaking change to `logic_layer_opacity`), or (b) custom `EditorPlugin` for true dispatched preview (full new phase). Defer until after v0.2.0 ships. See `.planning/research/editor-line-rect-preview.md` and `.planning/todos/pending/2026-04-28-re-research-editor-line-rect-tool-preview-during-drag.md`.

### Blockers/Concerns

### Active

- **Phase 3 TBT slot-table transcription:** the load-bearing data work for Phase 3. Each `.tres` from TBT needs to be read and translated into a mask-to-slot table; mistakes here corrupt rendering for that layout. Mitigated by visual regression on the demo for each shipped layout.
- **LOC overage carry-forward:** Phase 2 closed at 1827 runtime LOC vs the ~1500 informational trigger. Hard gate is end of Phase 4 (per CLAUDE.md). Watch additions in Phase 3/3.5/4 carefully — every shipped layout adds ~70-300 LOC.

### Resolved during Phase 2 execution

- **Demo scene rebinding in Wave 2** — done atomically with contract deletion in commit `b6349fa` (Wave 2 acceptance: "demo loads cleanly" satisfied).
- **Phase 1 verification suite migration** — done in Wave 1 (commit `595f0f8`); spec moved to `02-01-VERIFICATION-MIGRATION.md`; original `01-VERIFICATION.md` prepended with HISTORICAL banner.
- **ONE-mode sub-region anchoring (PENTA-SYNTH-05)** — geometric spec resolved inline at top of `02-02-PLAN.md` as HARD GATE D-69 (Path B sub-region anchoring); implemented in `PentaTileSynthesis.synthesize_strip` (commit `e8e114a`).
- **Collision-polygon transform math (PENTA-SYNTH-06)** — resolved inline as HARD GATE D-70 (TRANSPOSE→FLIP_H→FLIP_V order + Liang-Barsky rect clip, replaced in fix WR-01 with canonical Sutherland-Hodgman). Implemented in `PentaTileSynthesis.transform_vertex` + `clip_polygon_to_subrect`.
- **`_DEFAULT_LAYOUT` static singleton** — deleted in Wave 2 (commit `b6349fa`) atomically with `_resolve_layout` rewrite.
- **Phase 2 scope expansion concern** — phase shipped 7/7 plans; final LOC 1827 runtime (slightly above the predicted 1300-1500 estimate, but within the same order of magnitude).

## Deferred Items

Items acknowledged and carried forward as v2 requirements (see REQUIREMENTS.md v2 section):

| Category | Item | Status | Deferred At |
|----------|------|--------|-------------|
| Variation | Y-axis variation via `TileData.probability` (VAR-01) | future milestone | 2026-04-25 (v0.2 pivot) |
| Top Tiles | Designated top-edge visuals (TOP-01) | future milestone | 2026-04-25 (v0.2 pivot) |
| RPG Maker | Subtile compositor for A2/A4 (RPGM-01/02) | v0.3+ | 2026-04-25 |
| External Editors | Tiled `.tsx` / LDtk `.ldtk` rule importers (IMPORT-01/02) | v0.3+ | 2026-04-25 |
| Tooling | PentaBake / Wang→PentaTile converter (TOOL-01/02) | v2 | 2026-04-25 |
| Multi-terrain | Outer transition tiles (TERRAIN-01) | v2 | 2026-04-25 |
| Performance | Shader fallback / large-map benchmarks (PERF-01/02) | v2 | 2026-04-25 |
| Distribution | Asset Library / GUT test suite (DIST-01/02) | v2 | 2026-04-25 |

## Session Continuity

Last session: 2026-04-29T08:08:59.756Z
Stopped at: Phase 3 closed (Plan 06 complete; D-86 = b reduced scope; Tilesetter deferred to v0.3+); Phase 4 (Fallback Routing) is next planning step
Resume file: None

**Completed Phase:** 01 (Contract Skeleton + Penta Layouts) — 5/5 plans, 14/14 requirements, 26/26 automated tests PASS — 2026-04-26
**Completed Phase:** 01.1 (PentaTile Rename + Penta Codename Establishment) — 3/3 plans, 0 formal REQ-IDs (rename phase), demo loads cleanly under new name, git remote tracks PentaTile origin — 2026-04-26
**In-progress Phase:** 02 (Native Layouts + Architectural Simplification) — 7/7 plans executed + retroactive AUTO_STRIP dispatch wave (29cba37), 30/30 requirements satisfied programmatically, 3 code review passes clean (status: clean; 0 Critical / 0 Warning / 13 Info), 4 determinism sub-tests pass (BASELINE_HASH=2986698704, BASELINE_CELLS=46), VERTICAL regression net active, paint_test ALL PASS across 6 single-strip modes + 4 AUTO_STRIP cases + abstract guard. **Outstanding gates:** (1) human visual UAT — 2 items still pending in `02-HUMAN-UAT.md` (DualGrid16/Wang2*/Min3x3 visual correctness, Min3x3 collapse) + 1 partial (Penta multi-mode visual seam-check; programmatic dispatch ✓), (2) LOC overage decision — 1827 runtime LOC vs ~1500 trigger (informational at Phase 2; formal gate is Phase 5 final audit). AUTO/AUTO_STRIP detection UAT (test 4) now ✓ pass programmatically. ROADMAP Phase 2 entry intentionally `[ ]` until both gates resolved.
**Next Phase:** 03 (TileBitTools-Sourced Layouts) — Blob47Godot, TilesetterWang15, TilesetterBlob47 + ATTRIBUTION.md (chains automatically once Phase 2 approved in --auto mode)

**Planned Phase:** 03 (Public-Convention Layouts (Blob47 + Tilesetter)) — 6 plans — 2026-04-29T06:50:38.901Z
