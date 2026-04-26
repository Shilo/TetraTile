# Requirements: TetraTile v0.2.0

**Defined:** 2026-04-25 (re-spun after v0.2 pivot to layout library)
**Core Value:** Painting tiles with the native `TileMapLayer` API produces correct dual-grid autotiled visuals — without the user maintaining caches, terrain metadata, or 16-tile blob sets.

> **What changed from the original v0.2 plan.** The original v0.2 milestone targeted three feature pillars (Y-axis variation, top tiles, non-rotating tilesets) on top of a redesigned atlas contract. After research surfaced the layout-zoo problem — Godot, Tilesetter, OpenGameArt, etc. all use different atlas conventions and TetraTile only supports its own 4-tile "tetra" layout — the user redirected the milestone toward a **layout library**: every popular autotiling convention shipped as a pluggable Resource. The three original pillars push to a future milestone needing their own discussion.

## v1 Requirements

Requirements for v0.2.0. Each maps to roadmap phases via the Traceability section.

### Atlas Contract (CONTRACT)

The runtime contract that the new layout system plugs into.

- [ ] **CONTRACT-01**: `TetraTileMapLayer` exposes `@export var atlas_contract: TetraTileAtlasContract` accepting a typed `Resource` subclass.
- [ ] **CONTRACT-02**: `TetraTileAtlasContract` Resource declares: `version: int = 1`, `layout: TetraTileLayout`, `variation_seed: int = 0` (reserved for future variation milestone; placeholder).
- [ ] **CONTRACT-03**: `_resolve_slot(mask)` reads from `contract.layout` via `layout.compute_mask` and `layout.mask_to_atlas`. The 16-state hardcoded `match` from v0.1 relocates into `TetraTileLayoutTetraHorizontal.mask_to_atlas`.
- [ ] **CONTRACT-04**: When `atlas_contract == null`, `_resolve_slot()` falls back to v0.1 hardcoded behavior so existing scenes that haven't migrated continue to render unchanged.
- [ ] **CONTRACT-05**: The `atlas_contract` setter uses an idempotence guard (`if value == _atlas_contract: return`) and disconnects-before-reconnects on `Resource.changed` to prevent signal storms.

### TetraTileLayout Base Class (LAYOUT)

The Resource hierarchy that lets every supported atlas convention plug into the same `_update_cells()` pipeline.

- [ ] **LAYOUT-01**: `TetraTileLayout` base Resource defines virtual `compute_mask(coord: Vector2i, sample_fn: Callable) -> int` returning the layout's mask integer for a logic coord.
- [ ] **LAYOUT-02**: `TetraTileLayout` base Resource defines virtual `mask_to_atlas(mask: int) -> AtlasSlot` returning the slot to paint at that mask.
- [ ] **LAYOUT-03**: `TetraTileLayout` declares `template_image: Texture2D`, `fallback_tile_set: TileSet`, `description: String` (multiline), and a class-level `##` doc-comment for inspector hinting.
- [ ] **LAYOUT-04**: `AtlasSlot` Resource declares `atlas_coords: Vector2i`, `transform_flags: int = 0`, `alternative_tile: int = 0`, optional `diagonal_complement_atlas_coords: Vector2i` for tetra's overlay-layer composition.
- [ ] **LAYOUT-05**: `_pack_alternative(alt_id: int, transform_flags: int) -> int` helper combines alt-ID and `TRANSFORM_FLIP_*` flags via bitwise OR with `assert(alt_id < 4096)` to guard the bit-collision pitfall.

### Tetra Layouts (TETRA)

The v0.1 inheritance — ship as the addon's two defaults so existing users see no behavior change.

- [ ] **TETRA-01**: `TetraTileLayoutTetraHorizontal` subclass — 4 archetypes (Fill/Inner Corner/Border/Outer Corner) with rotation reuse, 4×1 atlas. Output bit-identical to v0.1 horizontal mode.
- [ ] **TETRA-02**: `TetraTileLayoutTetraVertical` subclass — same archetypes, 1×4 atlas. Output bit-identical to v0.1 vertical mode.
- [ ] **TETRA-03**: When the demo scene uses the bundled default `TetraTileAtlasContract` (Tetra Horizontal layout), the rendered output is bit-identical to v0.1 (visual regression).

### Native Layouts (NATIVE)

Layouts TetraTile ships natively because they're popular community conventions and the slot tables can be authored from public references.

- [ ] **NATIVE-01**: `TetraTileLayoutDualGrid16` subclass — 4×4 atlas, 16 unique tiles, 4-bit corner mask (TL=1/TR=2/BL=4/BR=8), no rotation reuse.
- [ ] **NATIVE-02**: `TetraTileLayoutWang2Edge` subclass — 4×4 atlas, 16 unique tiles, 4-bit edge mask (CR31 N=1/E=2/S=4/W=8).
- [ ] **NATIVE-03**: `TetraTileLayoutWang2Corner` subclass — 4×4 atlas, 16 unique tiles, 4-bit corner mask in CR31 cardinal naming (NE=1/SE=2/SW=4/NW=8). Visually compatible with DualGrid16 — different bit naming, same silhouettes.

### TileBitTools-Decoded Layouts (TBT)

Layouts whose slot tables are transcribed from TileBitTools' MIT-licensed `.tres` files (with attribution).

- [ ] **TBT-01**: `TetraTileLayoutTilesetterWang15` subclass — 5×3 atlas, 15 unique tiles plus a stray fill tile. Slot-to-mask table transcribed from `tile_bit_tools/tilesetter_wang.tres`.
- [ ] **TBT-02**: `TetraTileLayoutTilesetterBlob47` subclass — 11×5 atlas with discrete sub-block gaps, 47 unique tiles. Slot-to-mask table transcribed from `tile_bit_tools/tilesetter_blob.tres`.
- [ ] **TBT-03**: `TetraTileLayoutBlob47Godot` subclass — TileBitTools' Godot blob template convention, 47 unique tiles. Slot-to-mask table transcribed from the matching TBT template `.tres`.
- [ ] **TBT-04**: `addons/tetra_tile/ATTRIBUTION.md` credits TileBitTools (MIT, https://github.com/dandeliondino/tile_bit_tools) for the transcribed slot tables and links the upstream license file.

### Preview & Fallback (PREVIEW)

The drop-in prototyping UX. Each layout has an inspector-visible thumbnail and a fallback TileSet so a `TetraTileMapLayer` paints out of the box.

- [ ] **PREVIEW-01**: `template_image: Texture2D` on each layout Resource renders inline in the Godot inspector (free via Godot's stock `Texture2D` preview).
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

- **VAR-01**: Y-axis variation via deterministic per-cell hash + `TileData.probability` weights (was original v0.2; pushed because layout library landed first).
- **TOP-01**: Top-tile support — designated top-edge visuals for platformer caps (was original v0.2; pushed; needs design discussion against the new layout shape).
- **NONROT-01**: Any "non-rotating" features not covered by DualGrid16 / Wang2Corner / Wang2Edge layouts (most non-rotating cases are now solved).

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
| CONTRACT-01 | TBD | Pending |
| CONTRACT-02 | TBD | Pending |
| CONTRACT-03 | TBD | Pending |
| CONTRACT-04 | TBD | Pending |
| CONTRACT-05 | TBD | Pending |
| LAYOUT-01 | TBD | Pending |
| LAYOUT-02 | TBD | Pending |
| LAYOUT-03 | TBD | Pending |
| LAYOUT-04 | TBD | Pending |
| LAYOUT-05 | TBD | Pending |
| TETRA-01 | TBD | Pending |
| TETRA-02 | TBD | Pending |
| TETRA-03 | TBD | Pending |
| NATIVE-01 | TBD | Pending |
| NATIVE-02 | TBD | Pending |
| NATIVE-03 | TBD | Pending |
| TBT-01 | TBD | Pending |
| TBT-02 | TBD | Pending |
| TBT-03 | TBD | Pending |
| TBT-04 | TBD | Pending |
| PREVIEW-01 | TBD | Pending |
| PREVIEW-02 | TBD | Pending |
| PREVIEW-03 | TBD | Pending |
| PREVIEW-04 | TBD | Pending |
| TEMPLATE-01 | TBD | Pending (already shipped: 5/8 PNGs in commit e86036f) |
| TEMPLATE-02 | TBD | Pending |
| TEMPLATE-03 | TBD | Pending |
| TEMPLATE-04 | TBD | Pending |
| DEMO-01 | TBD | Pending |
| DEMO-02 | TBD | Pending |
| DEMO-03 | TBD | Pending |
| DOC-01 | TBD | Pending |
| DOC-02 | TBD | Pending |
| DOC-03 | TBD | Pending |
| DOC-04 | TBD | Pending |
| DOC-05 | TBD | Pending |
| REL-01 | TBD | Pending |
| REL-02 | TBD | Pending |
| REL-03 | TBD | Pending |

**Coverage:**
- v1 requirements: 39 total
- Mapped to phases: 0 (pending roadmap)
- Unmapped: 39 ⚠️ — populated by gsd-roadmapper

---
*Requirements re-spun: 2026-04-25 after v0.2 pivot to layout library*
