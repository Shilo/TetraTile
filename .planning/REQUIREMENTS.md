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

### Single-Tile Layout (SINGLE)

Inserted as Phase 2.1 on 2026-04-26 after user-requested ideation. Refined 2026-04-26 to slice into **5** archetypes (matching the unified Tetra synthesis architecture — see TETRA-SYNTH-* below). Ships a layout where the user provides ONE source image depicting an isolated cell with all 4 corners + 4 edges + center fill drawn in (reference: https://user-images.githubusercontent.com/47016402/87044533-f5e89f00-c1f6-11ea-9178-67b2e357ee8a.png coord (0,3)). The layout slices the source tile into sub-regions to synthesize the **5 Tetra archetypes (Fill, InnerCorner, Border, OuterCorner, OppositeCorners)** at contract-load time, then renders through the unified 5-tile dual-grid pipeline. Prototyping UX: one tile in, coherent autotiled output, zero broken seams, no overlay layer. RPG Maker family deferred to v0.3+ (see `.planning/research/layouts/RPG_MAKER.md`).

- [ ] **SINGLE-01**: `TetraTileLayoutSingleTile` subclass extends `TetraTileLayout`. Exposes `source_atlas_coords: Vector2i = Vector2i(0, 0)` pointing at the single user-authored tile within the atlas.
- [ ] **SINGLE-02**: At contract-load time, the layout synthesizes the **5 Tetra archetype slots** (Fill, InnerCorner, Border, OuterCorner, OppositeCorners) from sub-regions of the source cell. Result is cached on the layout instance and regenerated only when `source_atlas_coords` or the underlying atlas changes. Same input → same output (deterministic, no shimmering across `rebuild()` calls).
- [ ] **SINGLE-03**: All 16 mask states render correctly through the unified 5-tile dual-grid pipeline using the synthesized archetypes — including masks 6 and 9 via the synthesized OppositeCorners archetype (no overlay layer). Visual regression: an isolated cell, a horizontal strip, an L-shape, and a filled rectangle all render with no broken seams using the same single source tile.
- [ ] **SINGLE-04**: Bundled fallback `addons/tetra_tile/templates/single_tile.png` ships — one greyboxed cell with all-edges-and-corners-and-fill drawn so the layout has a working preview out of the box (consistent with the v0.2 fallback-tileset pattern).
- [ ] **SINGLE-05**: The demo scene (or a sub-scene) demonstrates "draw with one tile, get coherent autotiling" — proves the prototyping UX win at runtime.

### Tetra Synthesis & Overlay-Layer Removal (TETRA-SYNTH)

Phase 2 architectural pivot decided 2026-04-26 (supersedes earlier Tetra5-as-separate-class plan in `02-CONTEXT.md` D-28..D-46). The existing `TetraTileLayoutTetraHorizontal` / `TetraTileLayoutTetraVertical` (Phase 1) gain **load-time synthesis** of a 5th `OppositeCorners` archetype from the existing OuterCorner tile. Layouts auto-detect whether the source atlas has 4 or 5 tiles in the strip — 4-tile sources synthesize the 5th; 5-tile sources use the artist-authored 5th directly. **The runtime overlay layer is removed entirely** (`_overlay_layer`, `diagonal_complement_atlas_coords`, `_paint_overlay_for_slot` all deleted). Every v0.2 layout renders via single-layer 5-tile dispatch.

- [ ] **TETRA-SYNTH-01**: `TetraTileLayoutTetraHorizontal` (and `TetraTileLayoutTetraVertical` via inheritance) auto-detects source atlas tile count. 4-tile source → synthesize the 5th OppositeCorners archetype at contract-load time. 5-tile source → use the artist-authored 5th tile at slot 4 (horizontal: `(4, 0)`; vertical: `(0, 4)`). The class detects via `TileSetAtlasSource.get_atlas_grid_size()` against the layout's strip axis.
- [ ] **TETRA-SYNTH-02**: Synthesis composes the OppositeCorners tile from two transformed copies of the OuterCorner tile (one rotated 90° from the other) blitted onto a transparent canvas matching the source `tile_size`. Output is bit-identical to v0.1's overlay-layer composition for masks 6 and 9 (verified via pixel-hash test in Phase 2 plans).
- [ ] **TETRA-SYNTH-03**: Synthesized atlas lives in an internal `TileSet` owned by `TetraTileMapLayer._primary_layer`; the user's source `tile_set` is never mutated. Source tile collision/occlusion/navigation polygons are copied to the synthesized OppositeCorners tile (one copy per source archetype, translated to the diagonal positions). Animation frames, custom data layers, probability weights, and Y-sort origin on synthesized tiles are explicitly NOT supported in v0.2 (use a different layout if you need them).
- [ ] **TETRA-SYNTH-04**: `TetraTileMapLayer` removes `_overlay_layer` and all overlay-related code (`_paint_overlay_for_slot`, `diagonal_complement_atlas_coords` field on `AtlasSlot`, `_OVERLAY_LAYER_NAME` constant). After Phase 2, `TetraTileMapLayer` has exactly ONE child visual layer (`_primary_layer`).
- [ ] **TETRA-SYNTH-05**: `TetraTileLayout` base class virtual `needs_diagonal_overlay() -> bool` is removed (no longer needed — no layout uses an overlay). If a future milestone reintroduces multi-layer composition (e.g., top tiles), it gets a fresh hook then.
- [ ] **TETRA-SYNTH-06**: Bundled `tetra_5_horizontal.png` and `tetra_5_vertical.png` 5-tile templates ship in `addons/tetra_tile/templates/` so artists who want a hand-authored 5th tile have a starting reference. The existing 4-tile `tetra_horizontal.png` / `tetra_vertical.png` templates remain valid (synthesis fills in the 5th).

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
| SINGLE-01 | 2.1 | Pending |
| SINGLE-02 | 2.1 | Pending |
| SINGLE-03 | 2.1 | Pending |
| SINGLE-04 | 2.1 | Pending |
| SINGLE-05 | 2.1 | Pending |
| TETRA-SYNTH-01 | 2 | Pending |
| TETRA-SYNTH-02 | 2 | Pending |
| TETRA-SYNTH-03 | 2 | Pending |
| TETRA-SYNTH-04 | 2 | Pending |
| TETRA-SYNTH-05 | 2 | Pending |
| TETRA-SYNTH-06 | 2 | Pending |
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
- v1 requirements: 56 total (39 original + 6 added per Phase 1 discuss session + 5 added 2026-04-26 for Phase 2.1 single-tile insert + 6 added 2026-04-26 for TETRA-SYNTH overlay-removal pivot)
- Mapped to phases: 56 (after this update)
- Unmapped: 0

---
*Requirements re-spun: 2026-04-25 after v0.2 pivot to layout library*
