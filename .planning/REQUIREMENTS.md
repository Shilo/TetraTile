# Requirements: TetraTile v0.2.0

**Defined:** 2026-04-25 (re-spun after v0.2 pivot to layout library)
**Core Value:** Painting tiles with the native `TileMapLayer` API produces correct dual-grid autotiled visuals — without the user maintaining caches, terrain metadata, or 16-tile blob sets.

> **What changed from the original v0.2 plan.** The original v0.2 milestone targeted three feature pillars (Y-axis variation, top tiles, non-rotating tilesets) on top of a redesigned atlas contract. After research surfaced the layout-zoo problem — Godot, Tilesetter, OpenGameArt, etc. all use different atlas conventions and TetraTile only supports its own 4-tile "tetra" layout — the user redirected the milestone toward a **layout library**: every popular autotiling convention shipped as a pluggable Resource. The three original pillars push to a future milestone needing their own discussion.

## v1 Requirements

Requirements for v0.2.0. Each maps to roadmap phases via the Traceability section.

### Atlas Contract (CONTRACT)

The runtime contract that the new layout system plugs into.

- [x] **CONTRACT-01**: `TetraTileMapLayer` exposes `@export var atlas_contract: TetraTileAtlasContract` accepting a typed `Resource` subclass.
- [x] **CONTRACT-02**: `TetraTileAtlasContract` Resource declares: `version: int = 1`, `layout: TetraTileLayout`, `variation_seed: int = 0` (reserved for future variation milestone; placeholder).
- [x] **CONTRACT-03**: `_resolve_slot(mask)` reads from `contract.layout` via `layout.compute_mask` and `layout.mask_to_atlas`. The 16-state hardcoded `match` from v0.1 relocates into `TetraTileLayoutTetraHorizontal.mask_to_atlas`.
- [x] **CONTRACT-04**: When `atlas_contract == null`, `_resolve_slot()` falls back to v0.1 hardcoded behavior so existing scenes that haven't migrated continue to render unchanged.
- [x] **CONTRACT-05**: The `atlas_contract` setter uses an idempotence guard (`if value == _atlas_contract: return`) and disconnects-before-reconnects on `Resource.changed` to prevent signal storms.

### TetraTileLayout Base Class (LAYOUT)

The Resource hierarchy that lets every supported atlas convention plug into the same `_update_cells()` pipeline.

- [x] **LAYOUT-01**: `TetraTileLayout` base Resource defines virtual `compute_mask(coord: Vector2i, sample_fn: Callable) -> int` returning the layout's mask integer for a logic coord.
- [x] **LAYOUT-02**: `TetraTileLayout` base Resource defines virtual `mask_to_atlas(mask: int) -> AtlasSlot` returning the slot to paint at that mask.
- [x] **LAYOUT-03**: `TetraTileLayout` declares `template_image: Texture2D`, `fallback_tile_set: TileSet`, `description: String` (multiline), and a class-level `##` doc-comment for inspector hinting.
- [x] **LAYOUT-04**: `AtlasSlot` Resource declares `atlas_coords: Vector2i`, `transform_flags: int = 0`, `alternative_tile: int = 0`, optional `diagonal_complement_atlas_coords: Vector2i` for tetra's overlay-layer composition.
- [x] **LAYOUT-05**: `_pack_alternative(alt_id: int, transform_flags: int) -> int` helper combines alt-ID and `TRANSFORM_FLIP_*` flags via bitwise OR with `assert(alt_id < 4096)` to guard the bit-collision pitfall.

### Tetra Layouts (TETRA)

The v0.1 inheritance — ship as the addon's two defaults so existing users see no behavior change.

- [x] **TETRA-01**: `TetraTileLayoutTetraHorizontal` subclass — 4 archetypes (Fill/Inner Corner/Border/Outer Corner) with rotation reuse, 4×1 atlas. Output bit-identical to v0.1 horizontal mode.
- [x] **TETRA-02**: `TetraTileLayoutTetraVertical` subclass — same archetypes, 1×4 atlas. Output bit-identical to v0.1 vertical mode.
- [x] **TETRA-03**: When the demo scene uses the bundled default `TetraTileAtlasContract` (Tetra Horizontal layout), the rendered output is bit-identical to v0.1 (visual regression).

### Native Layouts (NATIVE)

Layouts TetraTile ships natively because they're popular community conventions and the slot tables can be authored from public references.

- [ ] **NATIVE-01**: `TetraTileLayoutDualGrid16` subclass — 4×4 atlas, 16 unique tiles, 4-bit corner mask (TL=1/TR=2/BL=4/BR=8), no rotation reuse.
- [ ] **NATIVE-02**: `TetraTileLayoutWang2Edge` subclass — 4×4 atlas, 16 unique tiles, 4-bit edge mask (CR31 N=1/E=2/S=4/W=8).
- [ ] **NATIVE-03**: `TetraTileLayoutWang2Corner` subclass — 4×4 atlas, 16 unique tiles, 4-bit corner mask in CR31 cardinal naming (NE=1/SE=2/SW=4/NW=8). Visually compatible with DualGrid16 — different bit naming, same silhouettes.

### Minimal 3×3 Layout (MIN3x3)

Per D-24 — added during Phase 1 discuss session. Covers PixelLab Tileset 3×3 export + RPG Maker A2 + legacy Godot 3.x atlases.

- [ ] **MIN3x3-01**: `TetraTileLayoutMinimal3x3` subclass — 3×3 atlas, 9 unique tiles, single-grid, 4-bit edge mask (T=1/E=2/B=4/W=8). Lands in Phase 2 alongside Wang2Edge.

### Tetra Synthesis & Overlay-Layer Removal (TETRA-SYNTH)

Phase 2 architectural pivot decided 2026-04-26 (supersedes BOTH the earlier Tetra5-as-separate-class plan in `02-CONTEXT.md` D-28..D-46 AND the Phase 2.1 SingleTile-as-separate-class plan). The existing `TetraTileLayoutTetraHorizontal` / `TetraTileLayoutTetraVertical` classes (Phase 1) gain **load-time synthesis** that handles three modes via auto-detection:

- **TETRA1 mode** — 1 source tile per strip; 5 archetypes synthesized via sub-region slicing. The prototyping mode (formerly the planned `TetraTileLayoutSingleTile`). User draws an isolated-cell-with-all-corners-and-edges (reference: https://user-images.githubusercontent.com/47016402/87044533-f5e89f00-c1f6-11ea-9178-67b2e357ee8a.png coord (0,3)).
- **TETRA4 mode** — 4 source tiles per strip; 5th archetype (OppositeCorners) synthesized from a transformed-OuterCorner pair. The classic v0.1 mode, now overlay-free.
- **TETRA5 mode** — 5 source tiles per strip; no synthesis. Fully artist-authored OppositeCorners.

Auto-detection reads `TileSetAtlasSource.get_atlas_grid_size()` along the strip axis (X for horizontal, Y for vertical). Axis size 1/4/5 → corresponding mode; per-strip refinement for 5-wide atlases via `has_tile()` at the strip's max axis position (a strip with col 4 empty becomes TETRA4 even within a 5-wide atlas, supporting mixed-mode authoring). **The runtime overlay layer is removed entirely** (`_overlay_layer`, `diagonal_complement_atlas_coords`, `_paint_overlay_for_slot` all deleted). Every v0.2 layout renders via single-layer 5-archetype dispatch. RPG Maker family deferred to v0.3+ (see `.planning/research/layouts/RPG_MAKER.md`).

- [ ] **TETRA-SYNTH-01**: `TetraTileLayoutTetraHorizontal` and `TetraTileLayoutTetraVertical` expose `tile_count_mode: TileCountMode` enum with members `AUTO` (default), `TETRA1`, `TETRA4`, `TETRA5`. AUTO triggers detection; explicit values skip detection and validate atlas content against the declared mode (warn on mismatch via `update_configuration_warnings()`).
- [ ] **TETRA-SYNTH-02**: AUTO-mode detection algorithm at `atlas_contract` setter time:
  1. Read atlas axis size: `get_atlas_grid_size().x` (horizontal) or `.y` (vertical)
  2. Map axis size → mode: `1 → TETRA1`, `4 → TETRA4`, `5 → TETRA5` (provisional)
  3. For TETRA5 axis size, refine per-strip: each strip checks `has_tile()` at axis-position 4; populated → strip stays TETRA5; empty → strip downgrades to TETRA4 (synthesize for that strip)
  4. Other axis sizes (0, 2, 3, 6+) → render disabled + `update_configuration_warnings()` fires with guidance to set `tile_count_mode` manually
  5. NO pixel-content inspection (dimension-based only — flawless detection, no false positives)
- [ ] **TETRA-SYNTH-03**: Synthesis machinery shared across modes (single `_synthesize_strip()` helper):
  - TETRA1: 5 archetypes synthesized from 1 source tile per strip (sub-region slicing of the isolated-cell art into Fill, InnerCorner, Border, OuterCorner, OppositeCorners)
  - TETRA4: 5th archetype (OppositeCorners) synthesized from a 90°-transformed pair of the OuterCorner tile per strip
  - TETRA5: no synthesis (use 5 authored tiles per strip directly)
- [ ] **TETRA-SYNTH-04**: Synthesized atlas lives in an internal `TileSet` owned by `TetraTileMapLayer._primary_layer`; user's source `tile_set` is never mutated. Synthesis re-runs only when `atlas_contract`, `tile_count_mode`, or the source `tile_set` changes (deterministic — same inputs → same outputs, no shimmering across `rebuild()` calls). Source tile collision/occlusion/navigation polygons are copied to synthesized tiles with appropriate transforms. Animation frames, custom data layers, probability weights, and Y-sort origin on synthesized tiles are explicitly NOT supported in v0.2 (use a non-Tetra layout if needed).
- [ ] **TETRA-SYNTH-05**: `TetraTileMapLayer` removes `_overlay_layer`, `_OVERLAY_LAYER_NAME`, `_paint_overlay_for_slot()`, and `AtlasSlot.diagonal_complement_atlas_coords`. The previously-planned `TetraTileLayout.needs_diagonal_overlay() -> bool` virtual is also removed (no layout uses overlay). After Phase 2, `TetraTileMapLayer` has exactly ONE child visual layer (`_primary_layer`).
- [ ] **TETRA-SYNTH-06**: TETRA4 mode synthesis output is **bit-identical** to v0.1's overlay-layer composition for masks 6 and 9. Verified by deterministic pixel-hash test in Phase 2 plans — `Image.get_data().hash()` of a TETRA4-synthesized OppositeCorners cell equals the hash of v0.1's overlay-rendered mask-6/mask-9 cell. A regression here blocks merge.
- [ ] **TETRA-SYNTH-07**: `update_configuration_warnings()` warns on (per Phase 1 D-15 pattern):
  - Atlas axis is 0, 2, 3, or 6+ in AUTO mode (no inferred mode possible)
  - `tile_count_mode != AUTO` and atlas axis disagrees with declared mode (e.g., declared TETRA5 but atlas is 4-wide)
  - Strip has missing tiles in declared mode (e.g., col 2 empty within a TETRA4 strip — malformed)
  - TETRA4 strip detected within a 5-wide atlas where ALL strips are TETRA4 (likely artist meant 4-wide atlas — informational, not blocking)
- [ ] **TETRA-SYNTH-08**: Bundled greybox templates ship for all three Tetra modes:
  - `tetra_1_horizontal.png`, `tetra_1_vertical.png` (TETRA1, 1-wide strip greybox cell with all-edges-and-corners-and-fill drawn — the prototyping reference)
  - `tetra_horizontal.png`, `tetra_vertical.png` (TETRA4, 4-tile, **already shipped** in commit e86036f — replaces TEMPLATE-01's count for these two)
  - `tetra_5_horizontal.png`, `tetra_5_vertical.png` (TETRA5, 5-tile, NEW — adds the OppositeCorners slot 4)
- [ ] **TETRA-SYNTH-09**: Demo scene (or sub-scenes) demonstrates all three modes — TETRA1 prototyping ("draw with one tile, get coherent autotiling"), TETRA4 classic 4-tile painting (synthesis-driven), TETRA5 hand-authored 5-tile painting. Runtime drag-paint (`demo_runtime_painter.gd`) works across all three modes without script changes.

### TileBitTools-Decoded Layouts (TBT)

Layouts whose slot tables are transcribed from TileBitTools' MIT-licensed `.tres` files (with attribution).

- [ ] **TBT-01**: `TetraTileLayoutTilesetterWang15` subclass — 5×3 atlas, 15 unique tiles plus a stray fill tile. Slot-to-mask table transcribed from `tile_bit_tools/tilesetter_wang.tres`.
- [ ] **TBT-02**: `TetraTileLayoutTilesetterBlob47` subclass — 11×5 atlas with discrete sub-block gaps, 47 unique tiles. Slot-to-mask table transcribed from `tile_bit_tools/tilesetter_blob.tres`.
- [ ] **TBT-03**: `TetraTileLayoutBlob47Godot` subclass — TileBitTools' Godot blob template convention, 47 unique tiles. Slot-to-mask table transcribed from the matching TBT template `.tres`.
- [ ] **TBT-04**: `addons/tetra_tile/ATTRIBUTION.md` credits TileBitTools (MIT, https://github.com/dandeliondino/tile_bit_tools) for the transcribed slot tables and links the upstream license file.

### PixelLab Layouts (PIXLAB)

Per D-25 — added during Phase 1 discuss session. Aseprite plugin native 8×8 atlas with variation banks; locked role-to-mask bijection from spike 003.

- [ ] **PIXLAB-01**: `TetraTileLayoutPixelLabTopDown` subclass — 8×8 atlas, single-grid, 4-bit corner mask. Cell-to-role layout from `tileset_transform.lua` `tileset_output`. Role-to-mask = `[4, 10, 13, 12, 9, 14, 15, 7, 2, 3, 11, 5, 0, 8, 6, 1]`.
- [ ] **PIXLAB-02**: `TetraTileLayoutPixelLabSideScroller` subclass — 8×8 atlas, single-grid, 4-bit corner mask. Cell-to-role layout from `tileset_transform.lua` `tileset_output_side`. Same role-to-mask bijection as PIXLAB-01.
- [ ] **PIXLAB-03**: Both PixelLab layouts handle variation banks: when multiple cells map to the same mask, `mask_to_atlas` deterministically picks one keyed on `(coord, variation_seed)`. Differentiator from PixelLab's official exporter (which discards duplicates).
- [ ] **PIXLAB-04**: Visual regression on a PixelLab Aseprite sample (8×8 PNG output) matches the Aseprite plugin's own canvas output for both top-down and side-scroller variants.

### Variation-Seed Wiring (VAR-PIXEL)

Per D-26 — added during Phase 1 discuss session. Phase 3.5 prerequisite; Phase 1 declares `variation_seed: int = 0` on `TetraTileAtlasContract` (CONTRACT-02) and `alternative_tile: int = 0` on `AtlasSlot` (LAYOUT-04) so this can wire up cleanly.

- [ ] **VAR-PIXEL-01**: `mask_to_atlas` (or a sibling helper) accepts variation context (per the Phase 1 back-reference from layout to contract; locked planner decision for variation-pick threading) and returns a deterministic cell from `mask → cells[]` keyed on `(coord, variation_seed)`. Hash function is `hash(Vector4i(coord.x, coord.y, atlas_coords.x, atlas_coords.y) + variation_seed)` per PITFALLS.md §2 (variation determinism).

### Preview & Fallback (PREVIEW)

The drop-in prototyping UX. Each layout has an inspector-visible thumbnail and a fallback TileSet so a `TetraTileMapLayer` paints out of the box.

- [x] **PREVIEW-01**: `template_image: Texture2D` on each layout Resource renders inline in the Godot inspector (free via Godot's stock `Texture2D` preview).
- [ ] **PREVIEW-02**: Each shipped layout has a bundled `fallback_tile_set: TileSet` `.tres` pointing at the layout's template image with slot positions configured.
- [ ] **PREVIEW-03**: When `TetraTileMapLayer.tile_set == null` AND `atlas_contract.layout != null`, the layer routes rendering through `layout.fallback_tile_set` for prototyping.
- [ ] **PREVIEW-04**: When the user assigns `tile_set` directly, it overrides the fallback (no warnings, no errors — uses what the user provided).

### Templates (TEMPLATE)

Greyboxed silhouette PNGs the artist paints over.

- [ ] **TEMPLATE-01**: Greyboxed templates ship for the 5 native layouts (`tetra_horizontal.png`, `tetra_vertical.png`, `dual_grid_16.png`, `wang_2corner.png`, `wang_2edge.png`). **Already shipped** in commit e86036f.
- [ ] **TEMPLATE-02**: Greyboxed templates ship for the 3 TBT-decoded layouts (`blob_47_godot.png`, `tilesetter_wang_15.png`, `tilesetter_blob_47.png`). Generated after TBT slot tables are transcribed.
- [ ] **TEMPLATE-03**: All 8 templates are produced by `_generate_greybox_templates.py` (committed alongside the PNGs); regenerable from source.
- [ ] **TEMPLATE-04**: Each template's slot positions match its layout Resource's `mask_to_atlas` table (verified by visual regression: paint the layout's bundled fallback TileSet and confirm visible tile shapes match the template silhouettes).

### Demo (DEMO)

- [ ] **DEMO-01**: One updated demo scene (`tetra_tile_demo.tscn`) showcases all 8 built-in layouts — runtime layout switching OR side-by-side `TetraTileMapLayer` instances.
- [ ] **DEMO-02**: Demo references the bundled fallback `TileSet`s so it works out of the box without authored tilesets (proves the prototyping UX).
- [ ] **DEMO-03**: Runtime drag-paint continues to work across all layouts (the existing `demo_runtime_painter.gd` doesn't break).

### Documentation (DOC)

- [ ] **DOC-01**: README has a "Layouts" section listing all 8 built-in layouts with names, descriptions, atlas grids, and tile counts.
- [ ] **DOC-02**: README has an "Upgrading from 0.1.x" section documenting the bundled-default contract as the primary migration path.
- [ ] **DOC-03**: README has an "Authoring a Custom Layout" section showing how to subclass `TetraTileLayout` (marked experimental).
- [ ] **DOC-04**: `CHANGELOG.md` entry documents all breaking changes — `atlas_contract` introduction, deprecated `atlas_layout` enum, any property renames.
- [ ] **DOC-05**: `addons/tetra_tile/ATTRIBUTION.md` exists and credits TileBitTools (covered by TBT-04 but called out here as a doc deliverable).

### Release (REL)

- [ ] **REL-01**: `plugin.cfg` `version` field bumped from `0.1.0` to `0.2.0`.
- [ ] **REL-02**: Git tag `v0.2.0` cut on the release commit (no `-pre`/`-alpha`/`-dev` suffixes).
- [ ] **REL-03**: GitHub Release artifact `tetra_tile-v0.2.0.zip` with `addons/tetra_tile/` at the archive root, including templates and ATTRIBUTION.md.

## v2 Requirements

Deferred to a future milestone but acknowledged. The original v0.2 feature pillars live here now since they pushed past this milestone.

### Variation, Top Tiles, Non-Rotating Spillover

- **VAR-01**: Y-axis variation via deterministic per-cell hash + `TileData.probability` weights (was original v0.2; pushed because layout library landed first). **DESIGN-COUPLED with MULTITERR-01 below** — Y-axis-as-variation and Y-axis-as-terrain compete for the same axis; future brainstorm must resolve both together (alternatives include packing variation into `alternative_tile`, multiple atlas sources per terrain, or explicit per-layout declaration of which Y-axis interpretation applies).
- **TOP-01**: Top-tile support — designated top-edge visuals for platformer caps (was original v0.2; pushed; needs design discussion against the new layout shape).
- **NONROT-01**: Any "non-rotating" features not covered by DualGrid16 / Wang2Corner / Wang2Edge layouts (most non-rotating cases are now solved).

### Multi-Terrain in One Tileset (MULTITERR)

Backlog item added 2026-04-26 from Phase 2.1 brainstorm. Goal: support multiple terrain types in a single atlas where each terrain auto-tiles independently and synthesized "extra" tiles (e.g. OppositeCorners for Tetra) are appended per-terrain without collision. Distinct from TERRAIN-01 (multi-terrain *transitions* — grass-to-dirt blending); MULTITERR is "each terrain abuts the others as if they were `empty`, no transitions."

- **MULTITERR-01**: Strip layouts (Single-Tile, Tetra) interpret atlas Y-axis as terrain. Source `4 × N` (Tetra4) or `1 × N` (Single-Tile) → synthesized output `5 × N`. Each row is one terrain. `compute_mask` parameterized by `terrain_id`; samples neighbors with the rule "is neighbor's terrain == terrain_id?" → independent per-terrain masks. **Design-coupled with VAR-01 above** — Y-axis interpretation conflict must be resolved together.
- **MULTITERR-02**: Block layouts (DualGrid16, Wang2Edge, Wang2Corner, Blob47*, PixelLab) need a different multi-terrain mechanism since each terrain occupies a 2D sub-block. Likely: multiple atlas sources, with `AtlasSlot` gaining a `source_id` field. Distinct architectural fork from MULTITERR-01.
- **MULTITERR-03**: Painting API documented for multi-terrain — user picks the terrain row when calling `set_cell` (atlas_coords.y = terrain_id). Demo runtime painter gains a hotkey to switch terrains.
- **MULTITERR-04**: `update_configuration_warnings()` flags out-of-range `terrain_y` values painted in the scene if the source atlas has fewer rows than referenced.
- **MULTITERR-05**: Boundary semantics: where terrain A meets terrain B, both render their own edge facing the other (each terrain treats the other as `empty`). No transition tiles. Hard boundary. Visually limited but architecturally clean. Transition tile support is TERRAIN-01.

### Atlas Tooling

- **TOOL-01**: TetraBake — edit-time utility to procedurally compose a fifth edge/diagonal connector tile.
- **TOOL-02**: Tileset converter — Wang/blob/single-tile inputs → TetraTile-compatible atlas.

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
| TetraBake / Tileset converter | Authoring tooling deferred |
| Multi-terrain transitions | Distinct R&D track |
| Shader fallback for diagonal compositing | Demo-scale doesn't need it |
| Collision authoring / auto-collision generation | TileSet-physics path is sufficient |
| MkDocs documentation site | GitHub README is enough for the private audience |
| Godot Asset Library distribution | GitHub-only this milestone |
| Formal automated test suite (GUT) | "Works in my game" quality bar |
| Large-map performance benchmarking | Demo-scale only |
| Backwards compatibility for v0.1.0 atlases | Pre-1.0; breaking changes accepted |
| `EditorInspectorPlugin` polish for layout authoring | Custom layouts work via subclassing but are documented as experimental — no editor UX |
| Persistent coordinate cache | TileMapDual territory; demo-scale doesn't need it |
| Watcher / signal-fanout systems | TileMapDual territory; lifecycle bug surface |
| Custom drawing API parallel to `set_cell()` | Defeats the v0.1 native-API win |

## Traceability

Which phases cover which requirements. Empty initially — populated by `gsd-roadmapper`.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CONTRACT-01 | 1 | Complete |
| CONTRACT-02 | 1 | Complete |
| CONTRACT-03 | 1 | Complete |
| CONTRACT-04 | 1 | Complete |
| CONTRACT-05 | 1 | Complete |
| LAYOUT-01 | 1 | Complete |
| LAYOUT-02 | 1 | Complete |
| LAYOUT-03 | 1 | Complete |
| LAYOUT-04 | 1 | Complete |
| LAYOUT-05 | 1 | Complete |
| TETRA-01 | 1 | Complete |
| TETRA-02 | 1 | Complete |
| TETRA-03 | 1 | Complete |
| NATIVE-01 | 2 | Pending |
| NATIVE-02 | 2 | Pending |
| NATIVE-03 | 2 | Pending |
| MIN3x3-01 | 2 | Pending |
| TETRA-SYNTH-01 | 2 | Pending |
| TETRA-SYNTH-02 | 2 | Pending |
| TETRA-SYNTH-03 | 2 | Pending |
| TETRA-SYNTH-04 | 2 | Pending |
| TETRA-SYNTH-05 | 2 | Pending |
| TETRA-SYNTH-06 | 2 | Pending |
| TETRA-SYNTH-07 | 2 | Pending |
| TETRA-SYNTH-08 | 2 | Pending |
| TETRA-SYNTH-09 | 2 | Pending |
| TBT-01 | 3 | Pending |
| TBT-02 | 3 | Pending |
| TBT-03 | 3 | Pending |
| TBT-04 | 3 | Pending |
| PIXLAB-01 | 3.5 | Pending |
| PIXLAB-02 | 3.5 | Pending |
| PIXLAB-03 | 3.5 | Pending |
| PIXLAB-04 | 3.5 | Pending |
| VAR-PIXEL-01 | 3.5 | Pending |
| PREVIEW-01 | 1 | Complete |
| PREVIEW-02 | 2 | Pending |
| PREVIEW-03 | 4 | Pending |
| PREVIEW-04 | 4 | Pending |
| TEMPLATE-01 | Pre-shipped | Pending (already shipped: 5/8 PNGs in commit e86036f) |
| TEMPLATE-02 | 3 | Pending |
| TEMPLATE-03 | Pre-shipped | Pending |
| TEMPLATE-04 | 2 | Pending |
| DEMO-01 | 5 | Pending |
| DEMO-02 | 5 | Pending |
| DEMO-03 | 5 | Pending |
| DOC-01 | 5 | Pending |
| DOC-02 | 5 | Pending |
| DOC-03 | 5 | Pending |
| DOC-04 | 5 | Pending |
| DOC-05 | 3 | Pending |
| REL-01 | 5 | Pending |
| REL-02 | 5 | Pending |
| REL-03 | 5 | Pending |

**Coverage:**
- v1 requirements: 54 total (39 original + 6 added per Phase 1 discuss session + 9 TETRA-SYNTH-* covering all three Tetra modes — TETRA1 prototyping, TETRA4 classic, TETRA5 hand-authored)
- Mapped to phases: 54 (after this update)
- Unmapped: 0
- Phase 2.1 (Single-Tile separate class) DROPPED 2026-04-26 — folded into Phase 2's TETRA-SYNTH-* via auto-detect of strip-axis tile count. Single class handles 1/4/5 modes; SINGLE-01..05 retired.

---
*Requirements re-spun: 2026-04-25 after v0.2 pivot to layout library*
