# Changelog

All notable changes to **PentaTile** (formerly TetraTile) are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased] — v0.2 in progress

### BREAKING — Project rename: TetraTile → PentaTile

The entire project has been renamed from **TetraTile** to **PentaTile**.
This is a breaking change with no backwards-compatibility shims, per the project's no-backwards-compat policy.

Renamed surface:

- Addon folder: `addons/tetra_tile/` → `addons/penta_tile/`
- Plugin id: `tetra_tile` → `penta_tile`
- Core class: `TetraTileMapLayer` → `PentaTileMapLayer`
- Contract class: `TetraTileAtlasContract` → `PentaTileAtlasContract`
- Layout base: `TetraTileLayout` → `PentaTileLayout`
- Layout subclasses: `PentaTileLayoutPentaHorizontal`, `PentaTileLayoutPentaVertical`
- All GDScript files: `tetra_tile_*.gd` → `penta_tile_*.gd`
- All `.tres` / `.tscn` assets: `tetra_*` → `penta_*`
- Custom data layer keys: `tetra_role` → `penta_role`, `tetra_lock_rotation` → `penta_lock_rotation`
- Requirement IDs: `TETRA-01..03` → `PENTA-01..03`, `TETRA-SYNTH-01..12` → `PENTA-SYNTH-01..12`
- `project.godot` config name: `"TetraTile"` → `"PentaTile"`

### Added — Penta codename anchors

- `README.md` § **What is a Penta tileset?** — canonical labeled-diagram section defining the 5 archetypes (IsolatedCell, Fill, Border, InnerCorner, OppositeCorners) and "Penta" as a coined term alongside Wang and Blob.
- `CLAUDE.md` § **Coined-Term Discipline** — project invariant reserving "Penta" exclusively for the 5-archetype format; prohibits `PentaCache`, `PentaDecoder`, or any unrelated "Penta" prefix.

### BREAKING — Phase 2: Architectural Simplification + Native Layout Library

**`PentaTileAtlasContract` deleted.** `layout: PentaTileLayout` lives directly on `PentaTileMapLayer` — no contract wrapper, no `version: int` speculative field. Per the no-forward-compat policy.

**Phase 1's `PentaTileLayoutPentaHorizontal` + `PentaTileLayoutPentaVertical` merged into a single `PentaTileLayoutPenta` class** with two enums:
- `axis: Axis { HORIZONTAL, VERTICAL }`
- `tile_count: TileCountMode { AUTO, AUTO_STRIP, ONE, TWO, THREE, FOUR, FIVE }` — five progressive synthesis modes per strip plus AUTO (dimension-only detection) and AUTO_STRIP (per-strip detection).

**New slot ordering** for the 5 Penta archetypes: `0=IsolatedCell, 1=Fill, 2=Border, 3=InnerCorner, 4=OppositeCorners`. **OuterCorner is implicit** — synthesized from slot 0 with rotation across all modes; never has a dedicated slot (Path B).

**Runtime overlay layer DELETED entirely.** All v0.2 layouts render via single-layer 5-archetype dispatch. Removed: `PentaTileMapLayer._overlay_layer`, `_OVERLAY_LAYER_NAME`, `_paint_overlay_for_slot()`, `AtlasSlot.diagonal_complement_atlas_coords`. `PentaTileMapLayer` now has exactly ONE child visual layer.

**`template_image` renamed to `bitmask_template`** on `PentaTileLayout` base class. Single image serves as inspector preview AND fallback `TileSet` source — no atlas/bitmask split. **`fallback_tile_set` `@export` removed**; replaced by `get_fallback_tile_set()` virtual method that builds a `TileSet` from `bitmask_template` at runtime. **`decoder_image` deleted** (was speculative).

**Bundled bitmask PNGs co-located** next to layout `.gd` files. The old `templates/` folder is deleted entirely. Penta has 10 PNGs in `addons/penta_tile/layouts/penta_tile_layout_penta/{one,two,three,four,five}_{horizontal,vertical}.png`. Single-variant layouts use flat siblings: `penta_tile_layout_dual_grid_16.png`, `penta_tile_layout_wang_2_edge.png`, `penta_tile_layout_wang_2_corner.png`, `penta_tile_layout_minimal_3x3.png`. Original v0.1 `penta_tile_template.png` deleted.

### Added — Phase 2: Native Layout Subclasses

Four hand-authored layouts ship in this milestone:

- **`PentaTileLayoutDualGrid16`** — 4×4 atlas with 16 explicit tiles for every dual-grid corner mask (TL=1/TR=2/BL=4/BR=8). No rotation reuse; every state maps to a unique authored tile. Uses `mask % 4 = col, mask / 4 = row`.
- **`PentaTileLayoutWang2Edge`** — single-grid 4×4 atlas, edge mask N=1/E=2/S=4/W=8 (also known as Marching Squares / Cellular Automata 2-Edge). Edges form lines and paths.
- **`PentaTileLayoutWang2Corner`** — single-grid 4×4 atlas, corner mask sampling diagonal neighbors NE=1/SE=2/SW=4/NW=8. Same `mask%4 / mask/4` formula as DualGrid16 but semantically different bit-to-neighbor mapping.
- **`PentaTileLayoutMinimal3x3`** — single-grid 3×3 9-tile atlas with open-side collapse rule (col/row = 0 if that side is exclusively open, 2 if exclusively closed on opposite, 1 (center) otherwise). Masks 5 (T+B) and 10 (E+W) and all isolated-diagonal states collapse to the center tile (accepted visual loss for the 9-tile minimum).

### Added — Phase 2: Synthesis Engine

- **`PentaTileSynthesis`** (`addons/penta_tile/penta_tile_synthesis.gd`) — load-time synthesis engine that generates missing archetypes for ONE/TWO/THREE/FOUR modes from the explicit slots present in the source atlas. Includes:
  - **`synthesize_strip()`** — main entry point; dispatches per `TileCountMode`.
  - **`clip_polygon_to_subrect()`** — Sutherland-Hodgman polygon clipper for collision/occlusion/navigation polygon transfer to synthesized sub-region tiles.
  - **`transform_vertex()`** — locked Gate 2 transform order: `TRANSPOSE → FLIP_H → FLIP_V`.
  - **`build_tile_set_from_synthesis()`** — wires synthesized slots to a `TileSetAtlasSource` for the layer to consume.
  - **Signature-based idempotence** — synthesis re-runs only when `(instance_id, axis, tile_count, source_id, resolved_mode)` changes; `rebuild()` is safe to call repeatedly.
  - **Polygon transfer** — collision/occlusion/navigation polygons are copied with appropriate transforms. Animation/custom-data/probability/y-sort are NOT copied (documented as a layout-choice tradeoff).

### Added — Phase 2: Auto-Detection + Configuration Warnings

- **AUTO mode** — `PentaTileLayoutPenta.resolve_active_mode()` reads atlas axis dimension (1/2/3/4/5 → ONE/TWO/THREE/FOUR/FIVE). Atlas axis size 0 or 6+ disables rendering and emits a configuration warning.
- **AUTO_STRIP mode** — `PentaTileLayoutPenta.resolve_strip_modes()` independently detects each strip's tile count via `TileSetAtlasSource.has_tile()` checks. Different strips can use different modes within a single atlas. **Per-strip dispatch wired in commit 29cba37** (post-Wave 6, retroactive): the layer's `_ensure_synthesized_tile_set` branches on `AUTO_STRIP`, calls `resolve_strip_modes`, threads `strip_origin` per strip, builds a 5×N synthesized atlas (one row per strip; gap strips render empty + emit warning C). `mask_to_atlas` and `_make_slot` accept `strip_index: int = 0`; new virtual `PentaTileLayout.resolve_display_strip(coord, sample_atlas_fn)` returns the strip index for a painted display cell — Penta override picks the first non-empty TL→TR→BL→BR neighbor's source-atlas-coord (HORIZONTAL → `coords.y`, VERTICAL → `coords.x`); non-Penta layouts inherit base default = 0. Spec correction landed alongside: Wave 2's `synthesize_strip` docstring described Interpretation B (cumulative offset along slot axis) but Wave 6's `resolve_strip_modes` implemented Interpretation A (perpendicular strips); **Interpretation A locked**, default `strip_origin` sentinel formula corrected to `Vector2i(0, strip_index)` HORIZONTAL / `Vector2i(strip_index, 0)` VERTICAL. Mixed-strip painting documented as v0.2 best-effort (first-non-empty-neighbor wins); proper terrain transitions remain MULTITERR-* in v2 backlog.
- **`get_configuration_warnings_for(layer)`** virtual on `PentaTileLayoutPenta` — duck-typed delegation from `PentaTileMapLayer._get_configuration_warnings()` surfaces atlas-size / mode-mismatch warnings in the Godot inspector.

### Added — Phase 2: Determinism Test Harness

- **`addons/penta_tile/tests/determinism_test.gd`** — headless Godot regression script with 4 sub-tests:
  - Sub-test (a): `transform_vertex` worked example (all 8 flag combinations against locked Gate 2 truth table).
  - Sub-test (b): `clip_polygon_to_subrect` hash determinism (10 invocations).
  - Main test: 11 `rebuild()` runs; asserts all hashes identical AND match `BASELINE_HASH=2986698704`.
  - Sub-test (c): VERTICAL-axis structural coverage (WR-07 regression net) — asserts cell count matches `BASELINE_CELLS=46` from HORIZONTAL AND every painted atlas coord resolves in the synthesized atlas via `source.has_tile()`.
- **`addons/penta_tile/tests/_capture_baseline.gd`** — baseline capture utility with optional `--layout-path=<res_path>` CLI flag for capturing baselines against alternative layouts (e.g., `penta_layout_four_vertical.tres`).

Run via:
```
Godot_v4.6.2-stable_win64_console.exe --headless --path . --script addons/penta_tile/tests/determinism_test.gd
```

### Phase 2 UAT bug-fix sweep (2026-04-28)

Closed 7 bug classes surfaced by user UAT against the demo scene with custom artist tile_set artwork. Commits `6553380` through `205fb67`.

**Bugs fixed:**

- **Bundled bitmask greyboxes** (`addons/penta_tile/_generate_bitmasks.py`) iterated through 4 silhouette designs before settling on the right shape per layout. **Single-grid edge-mask layouts (Wang2Edge, Min3x3) now ship solid 32×32 atlases** — partial-quadrant fills don't compose without dual-grid's half-tile offset, so single-grid uses solid silhouettes (artist's per-tile artwork carries the visual variation). **Wang2Corner gained its own solid 32×32 atlas** instead of reusing DualGrid16's partial-quadrant atlas (Wang2Corner is single-grid; DualGrid16's atlas is for dual-grid composition). **Penta dual-grid layouts keep per-archetype shapes** for slots 0–4 (slot 0 = BL quadrant only, slot 1 = full, slot 2 = bottom half, slot 3 = L-shape, slot 4 = TL+BR diagonal).

- **`PentaTileMapLayer._paint_via_layout` — single-grid logic-painted gate.** Previously, marking cardinal neighbors as affected caused them to also paint their own visual tile, extending the painted region by a full cell. Single-grid layouts now skip painting non-logic-painted cells (cardinal neighbors still trigger re-renders of their painted neighbors when the mask changes, but they don't render their own tile). Dual-grid layouts unchanged — they still paint all affected display cells (perimeter cells fill INNER quadrants that fall inside the painted logic pixel bounds).

- **`mask=0` short-circuit gated on `is_dual_grid()`.** Previously, the universal `mask == 0 → return` short-circuit dropped logic-painted single-grid cells whenever their mask sampler found no neighbors — isolated 1×1 paints, 1×N lines in Wang2Corner where straight lines have no diagonals. Now only dual-grid uses this short-circuit. All 3 single-grid layouts (Wang2Edge, Wang2Corner, Min3x3) drop their `mask == 0 → null` returns from `mask_to_atlas`; isolated cells dispatch to atlas (0, 0) for the Wangs and atlas (1, 1) for Min3x3 (per the open-side rule).

- **`PentaTileSynthesis._apply_canonical_silhouette()` (NEW)** enforces per-archetype expected opaque region during authored-slot extraction (FOUR/FIVE modes). Penta dispatches with rotation flags (TRANSPOSE | FLIP_H | FLIP_V) at render time. Stray opaque pixels in an artist's "cut" quadrant (e.g., orange inner-corner outline drawn at col 8 of slot 3's TR cut) get rotation-mapped INTO adjacent painted cells, producing visible bleed. The new method zeros the alpha of any pixel outside each archetype's canonical opaque region during synthesis, so artist art straying outside the expected silhouette can't bleed via rotation.

**Test coverage:**

The test suite grew from 9 → 12 tests, with 4 new/fortified tests catching this entire class of bug:

- `addons/penta_tile/tests/bitmask_bounds_test.gd` (NEW) — pixel-by-pixel verification of every bundled bitmask greybox PNG against expected per-slot silhouette. Catches generator drift.
- `addons/penta_tile/tests/comprehensive_bitmask_test.gd` (NEW) — paints 16 patterns (1×1, 1×2_h, 1×2_v, 2×1, 2×2, 3×3, 4×4, 5×5, line_h_5, line_v_5, L_shape, T_shape, plus_shape, diag_pair, diag_anti, 3_isolated) across all 5 layouts and asserts: (a) every painted cell renders, (b) single-grid cells dispatch to 100%-opaque tiles, (c) dual-grid cells dispatch to non-zero-opacity tiles, (d) no out-of-bounds visual cells, (e) opaque pixel bbox matches user_cells × tile_size.
- `addons/penta_tile/tests/penta_ground_hollow_test.gd` (NEW) — uses the demo's actual `penta_tile_ground.tres` source atlas (real artist artwork), paints a hollow ring (8×8 outer, 4×4 hole), asserts opaque-pixel bbox stays within painted bounds AND zero opaque pixels render inside the hole. Catches rotation-bleed bugs that don't appear with bundled greyboxes.
- `addons/penta_tile/tests/all_layouts_swap_pixel_test.gd` (FORTIFIED) — added per-edge continuity (≥80% opacity at painted-neighbor edges), interior coverage (mask=15 ≥ 80%), bbox bounds, per-cell solidity (single-grid 100% opaque) assertions.

Each fix was verified by stashing the patch, rerunning, confirming failure, applying the fix, confirming pass — the gold-standard regression-net protocol.

**Methodology:**

The 6-commit cycle exposed gaps in the original test methodology. Lessons codified in `CLAUDE.md` § Test Methodology, three new Critical Pitfalls (#8 single-grid logic-painted gate, #9 single-grid mask=0 dispatch, #10 Penta canonical-silhouette enforcement), and a full retrospective in `.planning/phases/02-native-layouts/02-UAT-LESSONS-LEARNED.md`. Cross-session memories `feedback_visual_testing.md` + `feedback_root_cause_discipline.md` capture the rules ("compose canvas pixel-by-pixel, not just dispatch tables", "trace full pipeline before patching symptoms").

### Migration notes for v0.1.x consumers

1. Replace all references to `TetraTileMapLayer` with `PentaTileMapLayer` in your scenes and scripts.
2. Move your `addons/tetra_tile/` folder to `addons/penta_tile/` and re-enable the plugin in Project Settings → Plugins.
3. If you stored the addon path in any tool scripts or CI configs (`res://addons/tetra_tile/`), update those to `res://addons/penta_tile/`.
4. Replace `atlas_contract = ...` on your `PentaTileMapLayer` instances with `layout = PentaTileLayoutPenta(axis=..., tile_count=...)` (or any other layout subclass). The `PentaTileAtlasContract` class is deleted.
5. If you authored against `PentaTileLayoutPentaHorizontal` / `PentaTileLayoutPentaVertical`, swap to `PentaTileLayoutPenta` with the appropriate `axis: Axis` enum value. Your atlas tile counts (1/2/3/4/5 along the strip axis) auto-detect under `tile_count = AUTO`.
6. If you reference `template_image` anywhere, rename to `bitmask_template`.
7. If you bind `fallback_tile_set` directly on a layout, remove it — `get_fallback_tile_set()` builds one from `bitmask_template` automatically.

### Added — Phase 3: Public-Convention Layout (Blob 47 Godot)

- **`PentaTileLayoutBlob47Godot`** — 7×7 atlas with 47 unique tiles plus discrete sub-block gaps. Single-grid 8-bit Moore-neighbor mask collapsed to 47 cell-states via the canonical [BorisTheBrave 47-blob reference](https://www.boristhebrave.com/2021/11/14/classification-of-tilesets/) algorithmic rule (256 → 47 collapse). Slot-to-mask dispatch via 47-entry `_MASK_TO_ATLAS` dict.
- **8-Moore single-grid propagation patch** — `PentaTileMapLayer._mark_affected_single_grid_cells` extended from 4 cardinals to 8 Moore neighbors so 47-blob layouts pick up diagonal neighbors during batch paint. 4-cardinal layouts unaffected (extra diagonal cells hit the existing logic-painted-only short-circuit).
- **TileBitTools acknowledgment** — README "External Resources" section gains a 1-line footnote citing TileBitTools as design inspiration. Per D-72/D-73, NO `addons/penta_tile/ATTRIBUTION.md` ships — every layout is sourced from each format's own primary reference (BorisTheBrave for 47-blob, etc.).
- **3 new tests:** `blob_47_collapse_test`, `blob_47_hollow_test`, `single_grid_8_moore_propagation_test`.

Tilesetter Wang 15 + Blob 47 layouts (`TBT-01`, `TBT-02`) deferred to v0.3+ — Tilesetter primary-source slot tables not located during plan-phase research; tracked as `TBT-01-DEFERRED` / `TBT-02-DEFERRED` / `TEMPLATE-02-DEFERRED` in REQUIREMENTS.md v2 backlog.

### Added — Phase 3.5: PixelLab Layouts

- **`PentaTileLayoutPixelLabTopDown`** — 8×8 atlas, single-grid, 4-bit corner mask. Cell-to-role table verbatim from PixelLab Aseprite plugin's `tileset_transform.lua:17-26` `tileset_output`. Role-to-mask bijection `[4, 10, 13, 12, 9, 14, 15, 7, 2, 3, 11, 5, 0, 8, 6, 1]` shared with the side-scroller variant.
- **`PentaTileLayoutPixelLabSideScroller`** — 8×8 atlas, single-grid; same dispatch shape as Top-Down with the `tileset_output_side` cell-to-role table from `tileset_transform.lua:28-36`.
- **First-cell row-major dispatch** — when multiple cells map to the same mask (PixelLab variation banks), `mask_to_atlas` deterministically returns the row-major-first cell. Per-cell deterministic-hash variation-bank pick (`VAR-PIXEL-01`) is deferred to v2 backlog (design-coupled with `VAR-01` and `MULTITERR-01`).
- **2 new tests:** `pixellab_first_cell_test` (D-89 cache contract), `pixellab_visual_regression_test` (composed-canvas vs checked-in spike-003 PixelLab samples).
- Matrix coverage in `comprehensive_bitmask_test` grew 6×18=108 → 8×18=144 combos.

### Added — Phase 4: Fallback Routing + Doc-Comment Sweep + Cross-AI Review

- **Fallback routing** — `PentaTileMapLayer` auto-fills `tile_set` from `layout.get_fallback_tile_set()` when `tile_set == null` and `layout != null`. Direct-assigned `tile_set` overrides the fallback (the `_tile_set_is_fallback` flag on the layer is the source of truth). Verified across all 8 actually-shipped layouts via composed-canvas test `fallback_routing_test.gd` (PREVIEW-03 + PREVIEW-04 contract).
- **Doc-comment sweep** — class-level `##` blocks + per-public-method `##` blocks + per-`@export` `##` blocks added to all 12 addon scripts, per [Godot's official documentation comment format](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html). `@experimental` annotation on `PentaTileLayout` (the abstract base — custom-layout subclassing is experimental in v0.2). Annotation-only sweep — zero logic changes.
- **Cross-AI review pass** — Gemini headless review against the v0.2 codebase + planning docs returned `status: clean` (0 findings). Codex pass DEFERRED at closeout due to a hard external CLI quota wall; preserved prompt at `.planning/phases/04-fallback-routing/04-CODEX-PROMPT.md` for re-use when quota resets. Phase 4 ships with single-pass cross-AI coverage.
- **1 new test:** `fallback_routing_test`. Suite total: 18 tests.

### BREAKING — Phase 5: Demo Refresh

The `addons/penta_tile/demo/penta_tile_demo.tscn` scene is rewritten end-to-end. The following demo files are RETIRED (clean delete; no compat shims):

- `demo_player.gd` + `demo_player.gd.uid` (CharacterBody2D platformer player)
- `penta_tile_ground.png` + `penta_tile_ground.png.import` + `penta_tile_ground.tres` (authored demo TileSet)
- `_regen_demo_ground.py` (Python regen utility for the deleted ground.tres)
- `penta_tile_dual_grid_16.tres`, `penta_tile_minimal_3x3.tres`, `penta_tile_wang_2_corner.tres`, `penta_tile_wang_2_edge.tres` (4 unused single-variant layout `.tres` orphans from earlier scene iterations)

Replaced by:

- **8-instance spatial-grid showcase** in `penta_tile_demo.tscn` — one `PentaTileMapLayer` per actually-shipped layout (Penta FOUR, DualGrid16, Wang2Edge, Wang2Corner, Min3x3, Blob47Godot, PixelLab Top-Down, PixelLab Side-Scroller), each with a sibling `Label` node naming the layout
- Every instance uses `tile_set = null` and binds a layout Resource — `get_fallback_tile_set()` provides the pixels (proves the prototyping UX end-to-end)
- **`demo_runtime_painter.gd` rewritten** with hover-target detection — left-click paints into whichever layer the cursor is over, right-click erases. The single-target `@export var map_path: NodePath` was deleted (no compat shim); the painter walks scene-tree children dynamically per event.

### Added — Phase 5: Documentation extensions

- **README "Layouts" section** — 8-row table listing each layout's class, atlas grid, tile count, mask, and convention source (DOC-01).
- **README "Upgrading from 0.1.x" section** — table of v0.1 → v0.2 surface migrations (DOC-02).
- **README "Authoring a Custom Layout" section** — minimal `@experimental`-marked subclass example showing the three virtuals (`compute_mask`, `mask_to_atlas`, `get_fallback_tile_set`) (DOC-03).
- **README "Identity & Footprint" section** — 3-axis identity audit summary against TileMapDual v5.0.2 (LOC + public surface + hot-path depth + anti-pattern register check). Full audit report at `.planning/phases/05-demo-refresh-documentation-release/05-LOC-AUDIT.md`. Per [D-05-11], LOC is reported as signal, not a fail criterion.

### Added — Phase 5: Release automation

- **`.github/workflows/release.yml`** — single `workflow_dispatch`-triggered GitHub Actions workflow handles the entire release: auto-version-increment from `plugin.cfg` (D-05-16: minor +1, rolls to major when minor ≥ 9, no patch bumps), CI checks (headless project import + 18-test suite + headless demo open via stderr-grep failure detector — Pitfall #1 mitigated), commit / tag / push, `git archive` zip build, CHANGELOG slice extraction via `awk`, GitHub Release publish via `softprops/action-gh-release@v3`.
- **`addons/penta_tile/tests/run_tests.sh`** — Linux mirror of `run_tests.ps1` (the existing PowerShell runner stays for Windows local dev). Identical 18-test inventory.
- Workflow is the SOLE release path — no sibling `build_release.sh` script at repo root, no `workflow_dispatch.inputs` for explicit version override (per D-05-15 hard rule "if it cannot be automatic, remove it").

### Migration notes for v0.1.x consumers (additional)

8. The bundled demo no longer ships a `CharacterBody2D` player or an authored `penta_tile_ground.tres`. If you forked the demo, its dependencies (`demo_player.gd`, `penta_tile_ground.{png,tres}`, `_regen_demo_ground.py`) are GONE. Either restore them locally from a v0.1 snapshot or migrate to the new bundled-fallback showcase pattern.
9. The `demo_runtime_painter.gd` script no longer takes a `map_path: NodePath` @export — it walks scene-tree children for `PentaTileMapLayer` instances dynamically per mouse event. If you embedded the painter in your own scene, drop the `map_path` reference.
10. After downloading a v0.2.x GitHub Release zip and extracting to a fresh Godot 4.6 project, run `godot --import` once to populate `.godot/` (standard Godot project bootstrap; not addon-specific).

---

## [0.1.0] — 2025-04-26

Initial release as **TetraTile**.

- Dual-grid autotiling via `TileMapLayer` subclass.
- 4-tile binary atlas: Fill, Inner Corner, Border, Outer Corner.
- 16-state marching-squares mask with transform-based rotations.
- Overlay layer composition for disconnected-diagonal masks (6 and 9).
- Horizontal and Vertical atlas layout support.
- Demo scene with platformer player and runtime painter.
