# Requirements: PentaTile v0.2.0

**Defined:** 2026-04-25 (re-spun after v0.2 pivot to layout library)
**Core Value:** Painting tiles with the native `TileMapLayer` API produces correct dual-grid autotiled visuals — without the user maintaining caches, terrain metadata, or 16-tile blob sets.

> **What changed from the original v0.2 plan.** The original v0.2 milestone targeted three feature pillars (Y-axis variation, top tiles, non-rotating tilesets) on top of a redesigned atlas contract. After research surfaced the layout-zoo problem — Godot, Tilesetter, OpenGameArt, etc. all use different atlas conventions and PentaTile only supports its own 4-tile "penta" layout — the user redirected the milestone toward a **layout library**: every popular autotiling convention shipped as a pluggable Resource. The three original pillars push to a future milestone needing their own discussion.

## v1 Requirements

Requirements for v0.2.0. Each maps to roadmap phases via the Traceability section.

### Layer (LAYER)

Phase 2 architectural simplification (2026-04-26): the `PentaTileAtlasContract` wrapper class is removed entirely; `PentaTileMapLayer` exposes `layout: PentaTileLayout` directly. The contract was overengineered for the actual scope (its `version: int` field had no consumer, and `variation_seed` is now in v2 backlog with the rest of variation work). Per the no-forward-compat policy in [CLAUDE.md](../../CLAUDE.md), speculative versioning machinery is deleted rather than carried forward.

- [x] **LAYER-01
**: `PentaTileMapLayer` exposes `@export var layout: PentaTileLayout` directly (no contract wrapper). Replaces the deleted `atlas_contract: PentaTileAtlasContract` property. Setter has idempotence guard + disconnect-before-reconnect on `layout.changed` per PITFALLS.md §5.
- [x] **LAYER-02
**: `_resolve_slot(mask)` reads `self.layout` directly (one fewer hop than the prior contract chain). When `layout == null`, the layer renders nothing (no v0.1 hardcoded fallback — Phase 1's complete refactor + breaking-changes policy means there's no v0.1 path to preserve). The static `_DEFAULT_LAYOUT` singleton at `penta_tile_map_layer.gd:193-198` is also deleted as part of this requirement (it allocated a class that no longer exists).
- [x] **LAYER-03
**: `PentaTileAtlasContract` class file (`addons/penta_tile/penta_tile_atlas_contract.gd`) deleted. Bundled `.tres` files in `addons/penta_tile/contracts/` (`default_horizontal.tres`, `default_vertical.tres`, `penta_horizontal_default.tres`, `penta_vertical_default.tres`) deleted with the folder. The original v0.1 reference `addons/penta_tile/penta_tile_template.png` deleted. The `addons/penta_tile/templates/` folder is also deleted entirely (per LAYOUT-07: bundled bitmask PNGs co-locate next to layout `.gd` files under `addons/penta_tile/layouts/`).
- [x] **LAYER-04
**: Demo scene `addons/penta_tile/demo/penta_tile_demo.tscn` updated atomically with the contract deletion: remove the `[ext_resource ... contracts/default_horizontal.tres]` reference and replace `atlas_contract = ExtResource(...)` with `layout = ExtResource(...)` pointing at a bundled `PentaTileLayoutPenta` `.tres` (or `null` if no fallback `.tres` ships). Demo must load cleanly in the Godot editor after Wave 2 lands; this is a non-skippable Wave 2 acceptance criterion.
- [x] **LAYER-05
**: Phase 1's verification suite (`.planning/phases/01-contract-skeleton-penta-layouts/01-VERIFICATION.md`, 26/26 tests passing as of Phase 1 close) references `atlas_contract`, `PentaTileLayoutPentaHorizontal`, `PentaTileLayoutPentaVertical`, and the old property names. Phase 2 Wave 1 migrates these tests to the new API (`layout: PentaTileLayout`, `PentaTileLayoutPenta(axis=…)`, `bitmask_template`, etc.). Test count may grow as new modes (TWO/THREE) gain coverage. Migrated tests live alongside Phase 2's new tests; Phase 1's 01-VERIFICATION.md is marked as historical record.

### PentaTileLayout Base Class (LAYOUT)

The Resource hierarchy that lets every supported atlas convention plug into the same `_update_cells()` pipeline.

- [x] **LAYOUT-01**: `PentaTileLayout` base Resource defines virtual `compute_mask(coord: Vector2i, sample_fn: Callable) -> int` returning the layout's mask integer for a logic coord.
- [x] **LAYOUT-02**: `PentaTileLayout` base Resource defines virtual `mask_to_atlas(mask: int) -> AtlasSlot` returning the slot to paint at that mask.
- [x] **LAYOUT-03
**: `PentaTileLayout` declares ONE user-facing image export: `bitmask_template: Texture2D` — the visual reference that defines the bitmask layout AND serves as the prototyping fallback's source pixels. Also declares `description: String` (multiline) and a class-level `##` doc-comment. **Renames** Phase 1's `template_image` → `bitmask_template`. **Removes** Phase 1's `fallback_tile_set: TileSet` @export (now hidden, generated internally via `get_fallback_tile_set()` method). **Removes** Phase 1's `decoder_image: Texture2D` (was speculative; nothing read it; deleted per no-forward-compat policy).
- [x] **LAYOUT-04
**: `AtlasSlot` Resource declares `atlas_coords: Vector2i`, `transform_flags: int = 0`, `alternative_tile: int = 0`. **Removes** Phase 1's `diagonal_complement_atlas_coords: Vector2i` field (was overlay-layer support; overlay layer deleted in Phase 2 per PENTA-SYNTH-07).
- [x] **LAYOUT-05**: `_pack_alternative(alt_id: int, transform_flags: int) -> int` helper combines alt-ID and `TRANSFORM_FLIP_*` flags via bitwise OR with `assert(alt_id < 4096)` to guard the bit-collision pitfall.
- [x] **LAYOUT-06
**: `PentaTileLayout` defines virtual `get_fallback_tile_set() -> TileSet` method. Default implementation builds a TileSet at first call from the layout's `bitmask_template` (the SAME image that's the inspector preview — single PNG per layout serves both roles). Layouts can override to inject custom logic. Consumer (`PentaTileMapLayer`) calls this method when `tile_set == null` to get prototyping-mode rendering (PREVIEW-03 wiring lands in Phase 4).
- [x] **LAYOUT-07
**: Bundled bitmask templates co-locate next to their layout `.gd` file (the `templates/` folder is deleted entirely):
  - **Single-PNG layouts** (DualGrid16, Wang2Edge, Wang2Corner, Min3x3, future PixelLab + TBT): flat sibling — `addons/penta_tile/layouts/penta_tile_layout_<slug>.gd` + `addons/penta_tile/layouts/penta_tile_layout_<slug>.png`
  - **Multi-variant layouts** (Penta has 5 modes × 2 axes = 10 variants): per-layout subfolder — `addons/penta_tile/layouts/penta_tile_layout_penta/<mode>_<axis>.png` (e.g. `one_horizontal.png`, `four_vertical.png`)
  - Each PNG is BOTH the inspector bitmask reference AND the prototyping fallback's source pixels (no separate atlas/bitmask split)

### Penta Layout (PENTA)

The Penta layout is the addon's signature 5-archetype convention. Per the Phase 2 architectural pivot (2026-04-26): one merged class with `axis: Axis` enum and `tile_count: TileCountMode` enum (auto-detect of 1/2/3/4/5 source-tile-per-strip modes). The Phase 1 separate `PentaTileLayoutPentaHorizontal`/`PentaTileLayoutPentaVertical` classes are deleted in favor of unified `PentaTileLayoutPenta`.

- [x] **PENTA-01
**: Single `PentaTileLayoutPenta` subclass with `axis: Axis = HORIZONTAL` enum (members: `HORIZONTAL`, `VERTICAL`). Slot 0 is always `IsolatedCell`; subsequent slots (1-4) progressively add `Fill`, `Border`, `InnerCorner`, `OppositeCorners` based on `tile_count` mode. **OuterCorner is implicit** — synthesized from slot 0's corners across all modes; never has its own slot. Strip axis is X for HORIZONTAL, Y for VERTICAL.
- [x] **PENTA-02
**: `tile_count: TileCountMode` enum (members: `AUTO = 0`, `AUTO_STRIP`, `ONE = 1`, `TWO = 2`, `THREE = 3`, `FOUR = 4`, `FIVE = 5`) on the same class. `AUTO` does dimension-only detection (cheapest, all strips share mode). `AUTO_STRIP` does per-strip detection (each strip independently 1-5). Explicit numeric values skip detection.
- [x] **PENTA-03
**: When the demo scene uses the default Penta layout (axis=HORIZONTAL, tile_count=AUTO) on a Penta-mode atlas, rendered output is visually regression-tested against a captured baseline (synthesis output is the authoritative reference; the slot ordering changed from v0.1 so v0.1 atlases are NOT bit-compat).

### Native Layouts (NATIVE)

Layouts PentaTile ships natively because they're popular community conventions and the slot tables can be authored from public references.

- [x] **NATIVE-01
**: `PentaTileLayoutDualGrid16` subclass — 4×4 atlas, 16 unique tiles, 4-bit corner mask (TL=1/TR=2/BL=4/BR=8), no rotation reuse.
- [x] **NATIVE-02
**: `PentaTileLayoutWang2Edge` subclass — 4×4 atlas, 16 unique tiles, 4-bit edge mask (CR31 N=1/E=2/S=4/W=8).
- [x] **NATIVE-03
**: `PentaTileLayoutWang2Corner` subclass — 4×4 atlas, 16 unique tiles, 4-bit corner mask in CR31 cardinal naming (NE=1/SE=2/SW=4/NW=8). Visually compatible with DualGrid16 — different bit naming, same silhouettes.

### Minimal 3×3 Layout (MIN3x3)

Per D-24 — added during Phase 1 discuss session. Covers PixelLab Tileset 3×3 export + RPG Maker A2 + legacy Godot 3.x atlases.

- [x] **MIN3x3-01
**: `PentaTileLayoutMinimal3x3` subclass — 3×3 atlas, 9 unique tiles, single-grid, 4-bit edge mask (T=1/E=2/B=4/W=8). Lands in Phase 2 alongside Wang2Edge.

### Penta Synthesis & Overlay-Layer Removal (PENTA-SYNTH)

Phase 2 architectural pivot (2026-04-26, locked after fourth iteration): single merged `PentaTileLayoutPenta` class with `axis: Axis` and `tile_count: TileCountMode` enums. **Five progressive modes (ONE → FIVE)**, each adding one explicit archetype slot. Slot 0 is always `IsolatedCell` (the synthesis source for OuterCorner across all modes); each subsequent slot adds explicit artist control over the next-most-impactful archetype.

| Slot | Archetype | Auto-added at mode | Notes |
|---|---|---|---|
| 0 | IsolatedCell | ONE (always present) | A self-contained autotile cell with all edges + corners + center fill visible. Synthesizes OuterCorner directly (one quadrant), and synthesizes other archetypes when those slots are unfilled. |
| 1 | Fill | TWO | Solid interior for fully-surrounded cells (mask 15). Center of slot 0 can contain anything (synthesis ignores it when slot 1 is present). |
| 2 | Border | THREE | Half-fill silhouette (~50% filled). Most visually frequent archetype after Fill — every edge cell. |
| 3 | InnerCorner | FOUR | 75%-fill silhouette with concave corner. Common at junctions and intersections. |
| 4 | OppositeCorners | FIVE | Diagonal 50%-fill (masks 6/9). Rarest archetype, full hand-authored control. |

**OuterCorner is implicit** — drawn into slot 0's corners, never has its own slot. Acceptable per the user-confirmed design: an isolated cell visually IS four outer corners + edges + fill, so OuterCorner art is naturally expressed via slot 0.

Auto-detection reads `TileSetAtlasSource.get_atlas_grid_size()` along the strip axis (X for HORIZONTAL, Y for VERTICAL). Other axis sizes (0, 6+) trigger `update_configuration_warnings()`. **The runtime overlay layer is removed entirely.** Every v0.2 layout renders via single-layer dispatch. RPG Maker family deferred to v0.3+ (see `.planning/research/layouts/RPG_MAKER.md`).

- [x] **PENTA-SYNTH-01
**: `PentaTileLayoutPenta` exposes `tile_count: TileCountMode` enum with values `AUTO = 0`, `AUTO_STRIP`, `ONE = 1`, `TWO = 2`, `THREE = 3`, `FOUR = 4`, `FIVE = 5`. Explicit numeric values match the actual tile count per strip (so `int(mode)` returns the count for ONE/TWO/THREE/FOUR/FIVE). AUTO and AUTO_STRIP trigger detection; explicit values skip detection and validate atlas content (warn on mismatch via `update_configuration_warnings()`).
- [x] **PENTA-SYNTH-02
**: AUTO-mode detection (uniform across all strips):
  1. Read atlas axis size: `get_atlas_grid_size().x` (HORIZONTAL) or `.y` (VERTICAL)
  2. Map axis size → mode: `1 → ONE`, `2 → TWO`, `3 → THREE`, `4 → FOUR`, `5 → FIVE`
  3. All strips in the atlas use the same mode (no per-strip refinement)
  4. **Gappy-strip behavior in AUTO mode**: a strip with cells missing in the populated range (e.g., axis size 5 + slot 0/1/2/4 populated, slot 3 empty) is treated as MALFORMED for that strip. Synthesis falls back to slot 0 for the missing archetype, and `update_configuration_warnings()` fires per PENTA-SYNTH-08. Painting still proceeds (graceful degradation); the warning surfaces the issue to the artist.
  5. Other axis sizes (0, 6+) → render disabled + warning
  6. O(1) cost — single integer compare
- [x] **PENTA-SYNTH-03
**: AUTO_STRIP-mode detection (per-strip):
  1. Read atlas axis size as in AUTO
  2. For each strip, count populated cells via `has_tile()` at each axis position 0..N-1
  3. Each strip's mode = its populated count (1/2/3/4/5); strips can differ within a single atlas
  4. Strips with anomalous counts (gaps, 0, 6+) → render that strip empty + warning
  5. O(strips × max_axis) cost — bounded, microseconds for typical atlas sizes
- [x] **PENTA-SYNTH-04
**: Detection is **dimension-based only** — no pixel-content inspection. Atlas axis size and `has_tile()` are the only inputs. No false-positive risk; reproducible across runs.
- [x] **PENTA-SYNTH-05
**: Synthesis machinery shared across all modes (single `_synthesize_strip(strip_index, mode)` helper). Per-strip outputs:
  - ONE: synthesize Fill + Border + InnerCorner + OuterCorner + OppositeCorners from sub-regions of slot 0
  - TWO: use slot 1 as Fill; synthesize Border + InnerCorner + OuterCorner + OppositeCorners from slot 0
  - THREE: use slot 1 (Fill) + slot 2 (Border) as authored; synthesize InnerCorner + OuterCorner + OppositeCorners from slot 0
  - FOUR: use slots 1-3 as authored; synthesize OuterCorner + OppositeCorners from slot 0
  - FIVE: use slots 1-4 as authored; synthesize OuterCorner from slot 0 (the only synthesis)
  - **Sub-region anchoring spec is a known unknown** — the geometric question "where in slot 0 do the corners / edges / fill live, and how are sub-rects extracted?" is NOT yet answered. Spikes 001-003 covered decoder feasibility, NOT synthesis-from-a-single-source-tile. **Recommend Spike 004** before plan execution to lock the anchoring math; alternatively, the planner pins this down during plan-phase as a load-bearing decision (with justification for the chosen anchoring convention).
- [x] **PENTA-SYNTH-06
**: Synthesized atlas lives in an internal `TileSet` owned by `PentaTileMapLayer._primary_layer`; user's source `tile_set` is never mutated. Synthesis re-runs only when `layout`, `axis`, `tile_count`, or the source `tile_set` changes (deterministic). Source tile collision/occlusion/navigation polygons are copied to synthesized tiles with appropriate transforms — **plan-phase must spec the polygon-transform math** (each polygon is a `Vector2[]`; rotations and flips applied via `Transform2D` or per-vertex math; sub-region clipping for ONE/TWO/THREE modes where the synthesized tile uses only part of slot 0's polygon area). Worth a sketch before the executor hits it. Animation frames, custom data layers, probability weights, and Y-sort origin on synthesized tiles are explicitly NOT supported in v0.2 (use a non-Penta layout if needed).
- [x] **PENTA-SYNTH-07
**: `PentaTileMapLayer` removes `_overlay_layer`, `_OVERLAY_LAYER_NAME`, `_paint_overlay_for_slot()`, and `AtlasSlot.diagonal_complement_atlas_coords` field. After Phase 2, `PentaTileMapLayer` has exactly ONE child visual layer (`_primary_layer`).
- [x] **PENTA-SYNTH-08
**: `update_configuration_warnings()` warns on (per Phase 1 D-15 pattern):
  - Atlas axis is 0 or 6+ in AUTO/AUTO_STRIP mode
  - `tile_count` is an explicit value (ONE..FIVE) and the atlas axis size disagrees
  - Strip has gaps in AUTO_STRIP mode (e.g., slot 1 populated but slot 0 empty)
- [x] **PENTA-SYNTH-09
**: `PentaTileLayoutPenta` hides the inherited `bitmask_template: Texture2D` from the inspector via `_validate_property` (auto-resolved per axis × mode from class-level constant lookup). Bundled bitmask templates ship under `addons/penta_tile/layouts/penta_tile_layout_penta/` (sibling to the `.gd` file) for all 5 modes × 2 axes:
  - `one_horizontal.png`, `one_vertical.png`
  - `two_horizontal.png`, `two_vertical.png`
  - `three_horizontal.png`, `three_vertical.png`
  - `four_horizontal.png`, `four_vertical.png`
  - `five_horizontal.png`, `five_vertical.png`
- [x] **PENTA-SYNTH-10
**: Single PNG per layout serves as BOTH the bitmask reference (visible in inspector) AND the prototyping fallback art. No separate `atlas.png` / `bitmask.png` split. The `get_fallback_tile_set()` method builds a runtime TileSet directly from this single PNG with axis-grid configuration matching the mode.
- [x] **PENTA-SYNTH-11
**: Demo scene (or sub-scenes) demonstrates ONE/FOUR/FIVE modes at minimum (TWO/THREE optional in demo). Runtime drag-paint (`demo_runtime_painter.gd`) works across all modes without script changes.
- [x] **PENTA-SYNTH-12
**: FOUR mode visual regression. Captured baseline (NOT v0.1 bit-identity since slot ordering changed — slot 3 is now InnerCorner, was OuterCorner in v0.1). Baseline-capture protocol:
  1. **What's captured**: render output of a fixed test scene (a 5×5 painted region with each mask state 0..15 represented at known coords) using a checked-in `PentaTileLayoutPenta(axis=HORIZONTAL, tile_count=FOUR)` Resource pointing at a fixed test atlas.
  2. **How it's captured**: `Viewport.get_texture().get_image().get_data().hash()` (single int per render) OR `Image.save_png()` to a baseline file (visual eyeball + structural diff). Planner picks one — int hash is cheaper and stricter.
  3. **Where the baseline lives**: `addons/penta_tile/tests/baselines/four_mode_5x5.<hash|png>` (path TBD by planner).
  4. **When it's captured**: once, at the end of Phase 2 Wave 7, after synthesis is verified visually correct. Subsequent runs assert hash-equality against this baseline.
  5. **What "regression blocks merge" means**: if a future commit changes the hash, the test fails and CI (or manual check) blocks the merge until either (a) the regression is fixed, or (b) the baseline is intentionally updated with a justification commit.
  6. Planner is free to refine the protocol but must answer all 5 points before implementation.

### TileBitTools-Sourced Layouts (TBT)

Layouts whose slot tables are sourced from each format's PRIMARY REFERENCE — `PentaTileLayoutBlob47Godot` from BorisTheBrave's published 47-blob reference (D-74), `PentaTileLayoutTilesetterWang15` and `PentaTileLayoutTilesetterBlob47` from Tilesetter's manual + the user-provided export sample (D-75, D-86 outcome). Phase title was historically "Decoded Layouts" then "TileBitTools-Sourced Layouts"; user pivot 2026-04-28 (D-72) renamed to "Public-Convention Layouts." Requirement ID prefix `TBT` is unchanged for traceability. Per D-73 no code or data is lifted from TBT — the audit deliverable `03-TBT-DEEP-AUDIT.md` reads TBT source but produces only ideas/recommendations.

- [ ] **TBT-01**: `PentaTileLayoutTilesetterWang15` subclass — 5×3 atlas, 15 unique tiles plus a stray fill tile. Slot-to-mask table transcribed from `tile_bit_tools/tilesetter_wang.tres`.
- [ ] **TBT-02**: `PentaTileLayoutTilesetterBlob47` subclass — 11×5 atlas with discrete sub-block gaps, 47 unique tiles. Slot-to-mask table transcribed from `tile_bit_tools/tilesetter_blob.tres`.
- [x] **TBT-03
**: `PentaTileLayoutBlob47Godot` subclass — TileBitTools' Godot blob template convention, 47 unique tiles. Slot-to-mask table transcribed from the matching TBT template `.tres`.
- [x] **TBT-04
**: `README.md` "External Resources" section contains a 1-line footnote acknowledging TileBitTools (https://github.com/dandeliondino/tile_bit_tools) as design inspiration. Per D-72 + D-73, NO `addons/penta_tile/ATTRIBUTION.md` is created — nothing is lifted from TBT, so nothing requires legal attribution. The Phase 3 audit deliverable `.planning/phases/03-tilebittools-sourced-layouts/03-TBT-DEEP-AUDIT.md` reads TBT source as design reference only.

### PixelLab Layouts (PIXLAB)

Per D-25 — added during Phase 1 discuss session. Aseprite plugin native 8×8 atlas with variation banks; locked role-to-mask bijection from spike 003.

- [x] **PIXLAB-01
**: `PentaTileLayoutPixelLabTopDown` subclass — 8×8 atlas, single-grid, 4-bit corner mask. Cell-to-role layout from `tileset_transform.lua` `tileset_output`. Role-to-mask = `[4, 10, 13, 12, 9, 14, 15, 7, 2, 3, 11, 5, 0, 8, 6, 1]`.
- [x] **PIXLAB-02**: `PentaTileLayoutPixelLabSideScroller` subclass — 8×8 atlas, single-grid, 4-bit corner mask. Cell-to-role layout from `tileset_transform.lua` `tileset_output_side`. Same role-to-mask bijection as PIXLAB-01
.
- [x] **PIXLAB-03
**: Both PixelLab layouts handle variation banks: when multiple cells map to the same mask, `mask_to_atlas` deterministically picks the FIRST cell. Variation-bank pick (deterministic hash across the bank for visual variety) is **deferred to v2 backlog** alongside VAR-01 and MULTITERR-01 (all coupled — see v2 Requirements). Phase 3.5 ships the layouts with first-cell pick only.
- [x] **PIXLAB-04
**: Visual regression on a PixelLab Aseprite sample (8×8 PNG output) matches the Aseprite plugin's own canvas output for both top-down and side-scroller variants.

### Preview & Fallback (PREVIEW)

The drop-in prototyping UX. Each layout has an inspector-visible thumbnail (the bitmask reference) and an internally-generated fallback TileSet so a `PentaTileMapLayer` paints out of the box.

- [x] **PREVIEW-01**: `bitmask_template: Texture2D` on each layout Resource renders inline in the Godot inspector (free via Godot's stock `Texture2D` preview). Replaces Phase 1's `template_image` property name (rename per LAYOUT-03
).
- [x] **PREVIEW-02
**: Each shipped layout's `get_fallback_tile_set()` returns a TileSet built from the layout's `bitmask_template` PNG (the SAME image that's shown in the inspector preview — single PNG serves both roles) with slot positions configured per the layout's `mask_to_atlas` table. Generated at first call, cached on the layout instance. No `.tres` files — the TileSet is constructed in code.
- [ ] **PREVIEW-03**: When `PentaTileMapLayer.tile_set == null` AND `layout != null`, the layer routes rendering through `layout.get_fallback_tile_set()` for prototyping.
- [ ] **PREVIEW-04**: When the user assigns `tile_set` directly, it overrides the fallback (no warnings, no errors — uses what the user provided).

### Templates (TEMPLATE)

Greyboxed silhouette PNGs the artist paints over.

- [x] **TEMPLATE-01
**: Single bundled bitmask template PNG ships per layout (no atlas/bitmask split — one image serves both inspector preview and fallback TileSet source). Co-located next to each layout `.gd` file:
  - **Penta (multi-variant)**: `addons/penta_tile/layouts/penta_tile_layout_penta/{one,two,three,four,five}_{horizontal,vertical}.png` — 10 PNGs in a subfolder
  - **Single-variant layouts**: `addons/penta_tile/layouts/penta_tile_layout_<slug>.png` — flat sibling to the `.gd` file (DualGrid16, Wang2Edge, Wang2Corner, Min3x3)
  - The existing flat PNGs in `templates/` are migrated to the new locations and the `templates/` folder is deleted
- [x] **TEMPLATE-02
**: Same convention for TBT-decoded layouts (Phase 3): `penta_tile_layout_blob_47_godot.png`, `penta_tile_layout_tilesetter_wang_15.png`, `penta_tile_layout_tilesetter_blob_47.png` — each as a flat sibling to its `.gd` file.
- [x] **TEMPLATE-03
**: A bitmask-template generator script (renamed/relocated from `_generate_greybox_templates.py`) produces all bundled PNGs from data definitions — regenerable from source. New location TBD by Phase 2 plan (probably `addons/penta_tile/_generate_bitmasks.py` or repo root).
- [x] **TEMPLATE-04
**: Each layout's bundled bitmask PNG slot positions match its `mask_to_atlas` table (verified by visual regression: paint the layout's `get_fallback_tile_set()` output and confirm visible tile shapes match).

### Demo (DEMO)

- [ ] **DEMO-01**: One updated demo scene (`penta_tile_demo.tscn`) showcases all 10 built-in layouts — runtime layout switching OR side-by-side `PentaTileMapLayer` instances.
- [ ] **DEMO-02**: Demo references the bundled fallback `TileSet`s so it works out of the box without authored tilesets (proves the prototyping UX).
- [ ] **DEMO-03**: Runtime drag-paint continues to work across all layouts (the existing `demo_runtime_painter.gd` doesn't break).

### Documentation (DOC)

- [ ] **DOC-01**: README has a "Layouts" section listing all 10 built-in layouts with names, descriptions, atlas grids, and tile counts.
- [ ] **DOC-02**: README has an "Upgrading from 0.1.x" section documenting the bundled-default contract as the primary migration path.
- [ ] **DOC-03**: README has an "Authoring a Custom Layout" section showing how to subclass `PentaTileLayout` (marked experimental).
- [ ] **DOC-04**: `CHANGELOG.md` entry documents all breaking changes for v0.2.0 — `PentaTileAtlasContract` deletion (replaced by direct `layout: PentaTileLayout` on the layer), `template_image` → `bitmask_template` rename, `fallback_tile_set` no longer @export'd, `decoder_image` deletion, `PentaTileLayoutPentaHorizontal`/`Vertical` merged into `PentaTileLayoutPenta`, new slot ordering (`0=IsolatedCell, 1=Fill, 2=Border, 3=InnerCorner, 4=OppositeCorners`; OuterCorner now implicit), 5-mode `tile_count` enum (ONE/TWO/THREE/FOUR/FIVE), AUTO_STRIP detection, overlay layer removal, all template PNG path changes (templates folder deleted; PNGs co-located in `layouts/`).
- [x] **DOC-05**: `README.md` "External Resources" section's TileBitTools design-inspiration footnote exists (covered by TBT-04
 but called out here as a doc deliverable). Per D-72 + D-73, NO `addons/penta_tile/ATTRIBUTION.md` is created.

### Release (REL)

- [ ] **REL-01**: `plugin.cfg` `version` field bumped from `0.1.0` to `0.2.0`.
- [ ] **REL-02**: Git tag `v0.2.0` cut on the release commit (no `-pre`/`-alpha`/`-dev` suffixes).
- [ ] **REL-03**: GitHub Release artifact `penta_tile-v0.2.0.zip` with `addons/penta_tile/` at the archive root, including templates and ATTRIBUTION.md.

## v2 Requirements

Deferred to a future milestone but acknowledged. The original v0.2 feature pillars live here now since they pushed past this milestone.

### Variation, Top Tiles, Non-Rotating Spillover

- **VAR-01**: Y-axis variation via deterministic per-cell hash + `TileData.probability` weights (was original v0.2; pushed because layout library landed first). **DESIGN-COUPLED with MULTITERR-01 and VAR-PIXEL-01 below** — Y-axis-as-variation and Y-axis-as-terrain compete for the same axis; future brainstorm must resolve all three together (alternatives include packing variation into `alternative_tile`, multiple atlas sources per terrain, or explicit per-layout declaration of which Y-axis interpretation applies).
- **VAR-PIXEL-01**: Variation-bank deterministic pick for PixelLab layouts — when a PixelLab atlas has multiple cells mapped to the same mask, pick one keyed on `(coord, variation_seed)` per PITFALLS.md §2 hash recipe. Moved here 2026-04-26 from Phase 3.5 active scope when `variation_seed` was deleted from `PentaTileAtlasContract` (which itself was deleted; see LAYER-01..03). Phase 3.5's PIXLAB-03 ships first-cell pick only; bank pick lands when variation work is reopened.
- **TOP-01**: Top-tile support — designated top-edge visuals for platformer caps (was original v0.2; pushed; needs design discussion against the new layout shape).
- **NONROT-01**: Any "non-rotating" features not covered by DualGrid16 / Wang2Corner / Wang2Edge layouts (most non-rotating cases are now solved).

### Multi-Terrain in One Tileset (MULTITERR)

Backlog item added 2026-04-26 from Phase 2.1 brainstorm. Goal: support multiple terrain types in a single atlas where each terrain auto-tiles independently and synthesized "extra" tiles (e.g. OppositeCorners for Penta) are appended per-terrain without collision. Distinct from TERRAIN-01 (multi-terrain *transitions* — grass-to-dirt blending); MULTITERR is "each terrain abuts the others as if they were `empty`, no transitions."

- **MULTITERR-01**: Strip layouts (Single-Tile, Penta) interpret atlas Y-axis as terrain. Source `4 × N` (Penta FOUR) or `1 × N` (Single-Tile / Penta ONE) → synthesized output `5 × N`. Each row is one terrain. `compute_mask` parameterized by `terrain_id`; samples neighbors with the rule "is neighbor's terrain == terrain_id?" → independent per-terrain masks. **Design-coupled with VAR-01 above** — Y-axis interpretation conflict must be resolved together.
- **MULTITERR-02**: Block layouts (DualGrid16, Wang2Edge, Wang2Corner, Blob47*, PixelLab) need a different multi-terrain mechanism since each terrain occupies a 2D sub-block. Likely: multiple atlas sources, with `AtlasSlot` gaining a `source_id` field. Distinct architectural fork from MULTITERR-01.
- **MULTITERR-03**: Painting API documented for multi-terrain — user picks the terrain row when calling `set_cell` (atlas_coords.y = terrain_id). Demo runtime painter gains a hotkey to switch terrains.
- **MULTITERR-04**: `update_configuration_warnings()` flags out-of-range `terrain_y` values painted in the scene if the source atlas has fewer rows than referenced.
- **MULTITERR-05**: Boundary semantics: where terrain A meets terrain B, both render their own edge facing the other (each terrain treats the other as `empty`). No transition tiles. Hard boundary. Visually limited but architecturally clean. Transition tile support is TERRAIN-01.

### Atlas Tooling

- **TOOL-01**: PentaBake — edit-time utility to procedurally compose a fifth edge/diagonal connector tile.
- **TOOL-02**: Tileset converter — Wang/blob/single-tile inputs → PentaTile-compatible atlas.

### RPG Maker Family

- **RPGM-01**: Subtile compositor for RPG Maker A2 (ground autotile).
- **RPGM-02**: Subtile compositor for RPG Maker A4 (wall autotile).
- **RPGM-03**: Sub-Blob 20 / Micro-Blob 13 quarter-tile layouts.

### External Editor Importers

- **IMPORT-01**: Tiled `.tsx` Wang Set rule importer.
- **IMPORT-02**: LDtk `.ldtk` rule importer.

### Multi-Terrain

- **TERRAIN-01**: Outer transition tile support — terrain-to-terrain transitions (grass→dirt etc.).

### Performance

- **PERF-01**: Shader fallback — single-pass shader option for diagonal compositing.
- **PERF-02**: Large-map perf benchmarks (>10k cells) with documented limits.

### Tooling & Distribution

- **TOOL-03**: Collision authoring tools / auto-collision generation.
- **TOOL-04**: MkDocs documentation site.
- **DIST-01**: Godot Asset Library submission.
- **DIST-02**: Formal automated test suite (GUT or similar).

### TBT (Phase 3 deferred — Tilesetter only)

Backlog entries added 2026-04-29 by Phase 3 Plan 06 closeout when D-86 resolved to option (b) — Tilesetter primary source not located in plan-phase research; user opted to defer rather than empirically fingerprint. Phase 3 shipped only `PentaTileLayoutBlob47Godot` (TBT-03 satisfied + TEMPLATE-02 partial); the Tilesetter pair carries forward.

- **TBT-01-DEFERRED**: `PentaTileLayoutTilesetterWang15` (5×3 atlas + stray-fill slot) — primary source not located in 2026-04-28 plan-phase research (RESEARCH § 3); user opted to defer per D-86 option (b). Re-trigger when user has a sample Tilesetter export OR when v0.3+ planning revisits.
- **TBT-02-DEFERRED**: `PentaTileLayoutTilesetterBlob47` (11×5 atlas with sub-block gaps) — same reason as TBT-01-DEFERRED.
- **TEMPLATE-02-DEFERRED**: TilesetterWang15 + TilesetterBlob47 bundled bitmask PNGs (`penta_tile_layout_tilesetter_wang_15.png`, `penta_tile_layout_tilesetter_blob_47.png`) — deferred from Phase 3 to v0.3+ alongside TBT-01-DEFERRED + TBT-02-DEFERRED. Activates when D-86 Tilesetter primary source becomes available. The Blob47Godot half of TEMPLATE-02 shipped in Plan 04.

## Out of Scope

Explicitly excluded for v0.2.0. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Y-axis variation | Pushed to future milestone; was original v0.2 but layout library re-prioritized first |
| Top tiles | Pushed to future milestone; needs design discussion |
| RPG Maker A2/A4 subtile composition | Quarter-tile compositor is a v0.3+ refactor; doesn't fit unified `_update_cells` dispatch |
| Tiled `.tsx` importer | Tiled stores rules in project file, not atlas; rule-importer infra is out of scope |
| LDtk `.ldtk` importer | Same — rules in project file |
| Excalibur / jaconir Blob 47 | Web-game indie convention; no Godot adoption |
| Stormcloak / OpenGameArt CR31 community blob | Insufficient adoption signal |
| Godot `MATCH_SIDES` mask layout | Engine semantics disputed (Godot issue #79411) |
| PentaBake / Tileset converter | Authoring tooling deferred |
| Multi-terrain transitions | Distinct R&D track |
| Shader fallback for diagonal compositing | Demo-scale doesn't need it |
| Collision authoring / auto-collision generation | TileSet-physics path is sufficient |
| MkDocs documentation site | GitHub README is enough for the private audience |
| Godot Asset Library distribution | GitHub-only this milestone |
| Formal automated test suite (GUT) | "Works in my game" quality bar |
| Large-map performance benchmarking | Demo-scale only |
| Backwards compatibility for v0.1.0 atlases | Pre-1.0; breaking changes accepted (CLAUDE.md "Breaking Changes Policy") |
| Forward-compat versioning machinery (`version: int` fields, schema markers, speculative extension points) | No-forward-compat policy added 2026-04-26; YAGNI applies hardest to versioning machinery |
| `EditorInspectorPlugin` polish for layout authoring | Custom layouts work via subclassing but are documented as experimental — no editor UX |
| Persistent coordinate cache | TileMapDual territory; demo-scale doesn't need it |
| Watcher / signal-fanout systems | TileMapDual territory; lifecycle bug surface |
| Custom drawing API parallel to `set_cell()` | Defeats the v0.1 native-API win |
| `addons/penta_tile/ATTRIBUTION.md` | D-72 / D-73: nothing is lifted from TBT, so nothing requires attribution. Replaced by a 1-line README footnote acknowledging TBT as design inspiration only. |
| Code or data lift from TileBitTools | D-73: TBT is design-inspiration only. Layouts implemented from each format's primary reference. The audit `03-TBT-DEEP-AUDIT.md` reads TBT source for ideas, NOT for code/data extraction. |

## Traceability

Which phases cover which requirements. Empty initially — populated by `gsd-roadmapper`.

| Requirement | Phase | Status |
|-------------|-------|--------|
| LAYER-01 | 2 | Complete (replaces deleted CONTRACT-01; `layout: PentaTileLayout` directly on `PentaTileMapLayer`) |
| LAYER-02 | 2 | Complete (replaces deleted CONTRACT-03/04; `_DEFAULT_LAYOUT` deleted in Wave 2) |
| LAYER-03 | 2 | Complete (PentaTileAtlasContract + contracts/ + penta_tile_template.png all deleted in Wave 2) |
| LAYER-04 | 2 | Complete (demo scene atomically rebound to `layout` ExtResource in Wave 2 / `b6349fa`) |
| LAYER-05 | 2 | Complete (Phase 1 verification suite migrated to `02-01-VERIFICATION-MIGRATION.md` in Wave 1 / `595f0f8`) |
| LAYOUT-01 | 1 | Complete |
| LAYOUT-02 | 1 | Complete |
| LAYOUT-03 | 2 | Complete (`template_image` → `bitmask_template` in Wave 1 / `cb6d253`) |
| LAYOUT-04 | 2 | Complete (`fallback_tile_set` @export + `decoder_image` deleted in Wave 1) |
| LAYOUT-05 | 1 | Complete |
| LAYOUT-06 | 2 | Complete (`get_fallback_tile_set()` virtual on base; codegen body added in Wave 2) |
| LAYOUT-07 | 2 | Complete (PNGs co-located under `addons/penta_tile/layouts/...` in Wave 5) |
| PENTA-01 | 2 | Complete (`PentaTileLayoutPenta` merged class replaces Phase 1 H/V pair in Wave 3) |
| PENTA-02 | 2 | Complete (`axis: Axis` + `tile_count: TileCountMode` enums on merged class) |
| PENTA-03 | 2 | Complete (FOUR-mode determinism baseline `BASELINE_HASH=2986698704` captured Wave 6 + VERTICAL structural baseline `673ace0`) |
| NATIVE-01 | 2 | Complete (DualGrid16 in Wave 4 / `91f69a2`) |
| NATIVE-02 | 2 | Complete (Wang2Edge in Wave 4) |
| NATIVE-03 | 2 | Complete (Wang2Corner in Wave 4) |
| MIN3x3-01 | 2 | Complete (Min3x3 in Wave 4) |
| PENTA-SYNTH-01 | 2 | Complete (`PentaTileSynthesis.synthesize_strip()` in Wave 2 / `e8e114a`) |
| PENTA-SYNTH-02 | 2 | Complete (AUTO mode dimension-only detection in Wave 6) |
| PENTA-SYNTH-03 | 2 | Complete (AUTO_STRIP per-strip detection in Wave 6) |
| PENTA-SYNTH-04 | 2 | Complete (Gate 1 Path B: OuterCorner = slot 0 + rotation) |
| PENTA-SYNTH-05 | 2 | Complete (Gate 2 transform_vertex: TRANSPOSE→FLIP_H→FLIP_V; sub-test (a) PASS) |
| PENTA-SYNTH-06 | 2 | Complete (signature-based synthesis cache; main determinism test PASS over 11 runs) |
| PENTA-SYNTH-07 | 2 | Complete (Sutherland-Hodgman polygon clip per WR-01 fix `ae5d787`) |
| PENTA-SYNTH-08 | 2 | Complete (`build_tile_set_from_synthesis()` wires synthesized slots to TileSet) |
| PENTA-SYNTH-09 | 2 | Complete (`_ensure_synthesized_tile_set` wires `_synthesized_tile_set` to `_primary_layer`) |
| PENTA-SYNTH-10 | 2 | Complete (single PNG per layout serves both inspector preview and fallback source) |
| PENTA-SYNTH-11 | 2 | Complete (demo bound to FOUR mode; ONE/FIVE `.tres` resources shipped) |
| PENTA-SYNTH-12 | 2 | Complete (FOUR-mode determinism `BASELINE_HASH=2986698704`; 11/11 runs match) |
| TBT-01 | 3 → v0.3+ | Deferred to v0.3+ per D-86 option (b) — Plan 05 SKIPPED 2026-04-29 (Tilesetter primary source not located in Phase 3 research). Tracked as `TBT-01-DEFERRED` in v2 Requirements. |
| TBT-02 | 3 → v0.3+ | Deferred to v0.3+ per D-86 option (b) — Plan 05 SKIPPED 2026-04-29 (same reason as TBT-01). Tracked as `TBT-02-DEFERRED` in v2 Requirements. |
| TBT-03 | 3 | Complete (Plan 04 / commits `63c3aa0` `fad4054` `c69f0d9`: PentaTileLayoutBlob47Godot ships with 7×7 atlas + algorithmic 256→47 collapse rule + 47-entry _MASK_TO_ATLAS dict + collapse test green; matrix integration in Plan 06 / `9d8aa3e`) |
| TBT-04 | 3 | Complete (Plan 03 / commit `fcfb9e4`: README "External Resources" section's TileBitTools design-inspiration footnote ships; ATTRIBUTION.md NOT created per D-73) |
| PIXLAB-01 | 3.5 | Pending |
| PIXLAB-02 | 3.5 | Pending |
| PIXLAB-03 | 3.5 | Pending |
| PIXLAB-04 | 3.5 | Pending |
| PREVIEW-01 | 2 | Complete (`template_image` renamed `bitmask_template` in Wave 1) |
| PREVIEW-02 | 2 | Complete (dual-role `bitmask_template` serves preview AND fallback codegen) |
| PREVIEW-03 | 4 | Pending |
| PREVIEW-04 | 4 | Pending |
| TEMPLATE-01 | 2 | Complete (14 bundled PNGs at co-located paths; `templates/` folder deleted in Wave 5) |
| TEMPLATE-02 | 3 + 3 → v0.3+ | Partial — Blob47Godot PNG ships (Plan 04 / commit `fad4054`); Tilesetter pair (TilesetterWang15 + TilesetterBlob47 PNGs) deferred to v0.3+ per D-86 option (b). Tracked as `TEMPLATE-02-DEFERRED` in v2 Requirements. |
| TEMPLATE-03 | Pre-shipped | Complete (template image format established v0.1; carried forward) |
| TEMPLATE-04 | 2 | Complete (slot 0 IsolatedCell PNG has transparent gaps; verified Wave 5 / `e17512e`) |
| DEMO-01 | 5 | Pending |
| DEMO-02 | 5 | Pending |
| DEMO-03 | 5 | Pending |
| DOC-01 | 5 | Pending |
| DOC-02 | 5 | Pending |
| DOC-03 | 5 | Pending |
| DOC-04 | 5 | Pending |
| DOC-05 | 3 | Complete (Plan 03 / commit `fcfb9e4`: same as TBT-04 — README footnote ships; ATTRIBUTION.md banned per D-73) |
| REL-01 | 5 | Pending |
| REL-02 | 5 | Pending |
| REL-03 | 5 | Pending |

**Coverage:**
- v1 requirements: 58 total (39 original − 5 CONTRACT (deleted) + 6 added Phase 1 discuss + 12 PENTA-SYNTH-* (5 progressive modes ONE→FIVE + AUTO/AUTO_STRIP detection + per-layout PNG conventions) + 5 LAYER-* (replace contract; LAYER-04 demo rebind, LAYER-05 Phase 1 test migration added during cleanup audit 2026-04-26) + 2 LAYOUT-06/07 (`get_fallback_tile_set()` virtual + co-located bundled PNGs) − 1 VAR-PIXEL-01 (moved to v2 backlog with VAR-01))
- Mapped to phases: 58 (after this update)
- Unmapped: 0
- 2026-04-29 D-86 outcome (Plan 05 SKIPPED): TBT-01, TBT-02, and the Tilesetter half of TEMPLATE-02 were originally mapped to Phase 3. Per the user's option-(b) decision, all three deferred to v0.3+ (tracked as TBT-01-DEFERRED / TBT-02-DEFERRED / TEMPLATE-02-DEFERRED in v2 Requirements). Phase 3 still owns these IDs in the Traceability table but their Status reads "Deferred" / "Partial" rather than "Complete." Phase 3 effective coverage: TBT-03 + TBT-04 + DOC-05 + Blob47Godot half of TEMPLATE-02 (4 of 6 originally-planned Phase 3 IDs).
- 2026-04-26 architectural pivots (locked after fourth iteration):
  - **Slot ordering**: `0=IsolatedCell, 1=Fill, 2=Border, 3=InnerCorner, 4=OppositeCorners`. OuterCorner is implicit (synthesized from slot 0's corners across all modes).
  - **Five progressive modes**: ONE → TWO → THREE → FOUR → FIVE, each adding one explicit slot. AUTO detects from atlas axis size (uniform across strips); AUTO_STRIP detects per-strip (strips can differ).
  - `PentaTileAtlasContract` DELETED — `layout: PentaTileLayout` directly on `PentaTileMapLayer`. `version: int` deleted; `variation_seed: int` → v2 backlog with VAR-01.
  - `PentaTileLayoutPentaHorizontal`/`Vertical` MERGED into `PentaTileLayoutPenta` with `axis: Axis` enum.
  - `template_image` → `bitmask_template`; `fallback_tile_set` HIDDEN; `decoder_image` DELETED.
  - **Single PNG per layout** serves both inspector preview AND fallback TileSet source (no atlas/bitmask split).
  - **Templates folder DELETED**; bundled PNGs co-locate next to layout `.gd` files. Penta has 10 PNGs in `penta_tile_layout_penta/` subfolder; single-variant layouts use flat siblings.
  - Phase 2.1 (SingleTile separate class) DROPPED — PENTA1 mode handles via auto-detect.

---
*Requirements re-spun: 2026-04-25 after v0.2 pivot to layout library*
