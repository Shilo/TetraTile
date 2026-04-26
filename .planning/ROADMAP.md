# Roadmap: TetraTile v0.2.0

**Milestone:** v0.2.0 — "Layout Library + Preview Fallback"
**Created:** 2026-04-25 (re-spun after pivot from "expand the contract")
**Granularity:** standard (5 phases)

## Overview

TetraTile v0.1.0 ships a single hardcoded atlas convention — 4 tiles in the "tetra" order (Fill / Inner Corner / Border / Outer Corner). Atlases authored anywhere else (Tilesetter, OpenGameArt's 47-blob, Godot's stock terrain templates, the broader pixel-art ecosystem) don't drop in.

v0.2.0 ships a **library of pluggable layout Resources**. Every popular Godot autotiling atlas convention becomes a `TetraTileLayout` subclass. Drop a fresh `TetraTileMapLayer` into a scene, attach a layout Resource, and either bring your own atlas or use the layout's bundled fallback TileSet for instant prototyping. No bitmask authoring per tile, no peering bits.

The five-phase plan lands the contract + base layout class first (gates everything), then ships the three TetraTile-native layouts (DualGrid16, Wang2Edge, Wang2Corner), then transcribes TileBitTools' MIT-licensed slot tables for the three Blob/Wang layouts (Blob47Godot, TilesetterWang15, TilesetterBlob47), then wires the fallback-TileSet routing for prototyping UX, then closes with a demo refresh and the GitHub release.

The original v0.2 feature pillars (Y-axis variation, top tiles, non-rotating tilesets) are now in v2 backlog. "Non-rotating" is largely *delivered* by the new layouts since DualGrid16 / Wang2Corner / Wang2Edge are explicitly per-direction-authored. Variation and top tiles need their own design discussion against the new layout shape.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3, 4, 5): Planned milestone work
- Decimal phases (e.g. 3.5): Reserved for inserts that extend an adjacent integer phase without renumbering. Currently in use: 3.5 (PixelLab layouts, extends Phase 3). Phase 2.1 was inserted 2026-04-26 then **collapsed into Phase 2** on 2026-04-26 when the Tetra layout absorbed Single-Tile mode via auto-detect.

- [x] **Phase 1: Contract Skeleton + Tetra Layouts** — Introduce `TetraTileAtlasContract` + `TetraTileLayout` base + `AtlasSlot`. Ship Tetra Horizontal + Tetra Vertical as the first two layout subclasses. v0.1 visuals continue unchanged via the bundled default contract OR the null-fallback path.
- [ ] **Phase 2: Native Layouts + Tetra Synthesis (1/4/5 auto-detect)** — Ship DualGrid16, Wang2Edge, Wang2Corner, Min3x3 subclasses. Plus the architectural pivot: existing `TetraTileLayoutTetraHorizontal`/`Vertical` gain load-time synthesis with auto-detect of three modes per strip — TETRA1 (1 source tile → 5 archetypes synthesized), TETRA4 (4 sources → 5th synthesized), TETRA5 (5 authored, no synthesis). Runtime overlay layer DELETED entirely (single-layer dispatch only). `TileCountMode` enum on the layout for explicit override. Companion artifact: `.planning/research/layouts/RPG_MAKER.md` documents the deferred RPG Maker family for v0.3+.
- [ ] **Phase 3: TileBitTools-Decoded Layouts** — Transcribe slot tables from TBT's MIT-licensed `tilesetter_blob.tres`, `tilesetter_wang.tres`, and the matching Godot blob template `.tres`. Ship Blob47Godot, TilesetterWang15, TilesetterBlob47. Generate the 3 missing template PNGs from the slot tables. Add `ATTRIBUTION.md`.
- [ ] **Phase 3.5: PixelLab Layouts + Variation-Seed Wiring** — Ship `TetraTileLayoutPixelLabTopDown` and `TetraTileLayoutPixelLabSideScroller` (8×8 atlas, single-grid, 4-bit corner mask, variation-bank). Wire `variation_seed` deterministic-hash bucket-pick. Add `TetraTileLayoutMinimal3x3` if not already shipped in Phase 2.
- [ ] **Phase 4: Fallback Routing** — Wire `TetraTileMapLayer` to use `layout.fallback_tile_set` when `tile_set == null`. Verify all 8 layouts paint correctly with their bundled fallback. Visual regression on the demo scene.
- [ ] **Phase 5: Demo Refresh + Documentation + Release** — One updated demo scene showcasing all 8 layouts, README sections (Layouts / Upgrading / Authoring a Custom Layout), CHANGELOG, plugin.cfg bump, GitHub Release zip with `v0.2.0` tag.

## Phase Details

### Phase 1: Contract Skeleton + Tetra Layouts

**Goal**: A typed `TetraTileAtlasContract` Resource owning a `TetraTileLayout` reference is the source of truth for atlas shape; v0.1 scenes that don't migrate continue to render unchanged via either the bundled default contract OR the null-fallback path.

**Depends on**: Nothing (first phase).

**Requirements**: CONTRACT-01, CONTRACT-02, CONTRACT-03, CONTRACT-04, CONTRACT-05, LAYOUT-01, LAYOUT-02, LAYOUT-03, LAYOUT-04, LAYOUT-05, TETRA-01, TETRA-02, TETRA-03, PREVIEW-01 (the `template_image` Texture2D field renders inline; the consumer-side fallback routing lands in Phase 4)

**Success Criteria** (what must be TRUE):
1. Setting `atlas_contract` to the bundled default (Tetra Horizontal layout) on the demo scene produces visuals bit-identical to v0.1 (visual regression: side-by-side screenshot of the same painted layout matches pixel-for-pixel for all 16 mask states).
2. Leaving `atlas_contract = null` on a v0.1-style scene produces visuals bit-identical to v0.1 (the hardcoded fallback path renders the canonical 4-tile atlas correctly).
3. Reassigning `atlas_contract` to the same Resource value triggers zero rebuilds (idempotence guard verified by counting `_queue_rebuild` calls in a debug build).
4. Editing a property on a connected `TetraTileAtlasContract` triggers exactly one rebuild per edit (no signal storm — `Resource.changed` is connected once, disconnected before reassignment).
5. The TetraTileLayout base class can be subclassed; instances of `TetraTileLayoutTetraHorizontal` / `Vertical` appear correctly in the inspector picker for the contract's `layout` slot.
6. End-of-Phase-1 LOC checkpoint: `addons/tetra_tile/` total stays well under TileMapDual's surface area; logged in the phase summary.

**Plans**: 5 plans
Plans:
- [x] 01-01-PLAN.md — Wave 0: capture v0.1 baselines + LOC snapshot + _rebuild_count instrumentation + ROADMAP/REQUIREMENTS expansion (D-27)
- [x] 01-02-PLAN.md — Wave 1: Resource skeleton (TetraTileAtlasSlot + TetraTileLayout base + TetraTileAtlasContract with locked D-08 setter)
- [x] 01-03-PLAN.md — Wave 2: Concrete layout subclasses (TetraTileLayoutTetraHorizontal with relocated 16-state match + TetraTileLayoutTetraVertical axis-swap subclass)
- [x] 01-04-PLAN.md — Wave 3: Layer dispatcher rewrite (hard-remove enum + atlas_layout export, add atlas_contract setter, _resolve_layout lazy singleton, dual+single grid pipeline branch)
- [x] 01-05-PLAN.md — Wave 4: Bundled .tres files + demo wiring + visual regression + idempotence/storm test + LOC checkpoint

### Phase 2: Native Layouts + Tetra Synthesis (1/4/5 auto-detect)

**Goal**: Four TetraTile-native layout subclasses (DualGrid16, Wang2Edge, Wang2Corner, Min3x3) ship with hand-authored slot tables and bundled fallback TileSets. **Plus the architectural pivot**: existing `TetraTileLayoutTetraHorizontal`/`TetraTileLayoutTetraVertical` gain load-time synthesis with auto-detection of three modes per strip:
- **TETRA1** — 1 source tile per strip; 5 archetypes synthesized via sub-region slicing (the prototyping mode, formerly the planned separate `TetraTileLayoutSingleTile`)
- **TETRA4** — 4 source tiles per strip; 5th archetype (OppositeCorners) synthesized from a transformed-OuterCorner pair (the v0.1 mode, now overlay-free)
- **TETRA5** — 5 source tiles per strip; no synthesis (fully artist-authored OppositeCorners)

Auto-detection reads `TileSetAtlasSource.get_atlas_grid_size()` along the strip axis; per-strip refinement handles mixed authoring (some strips TETRA4, some TETRA5 within a single 5-wide atlas). A `tile_count_mode` enum (`AUTO` / `TETRA1` / `TETRA4` / `TETRA5`) lets users override detection and forces explicit error messages on mismatch. **The runtime overlay layer is deleted entirely** (`_overlay_layer`, `diagonal_complement_atlas_coords`, `_paint_overlay_for_slot`). After Phase 2, every v0.2 layout renders via single-layer dispatch with no per-paint composition.

This phase supersedes BOTH the earlier "append Tetra5 as separate layout class" plan in `.planning/phases/02-native-layouts/02-CONTEXT.md` (D-28..D-46) AND the Phase 2.1 SingleTile-as-separate-class plan (Phase 2.1 collapsed back into Phase 2 on 2026-04-26). Single Tetra class per axis handles all three modes; SINGLE-01..05 retired.

**Depends on**: Phase 1 (the layout dispatch must exist before layout subclasses can plug in).

**Requirements**: NATIVE-01, NATIVE-02, NATIVE-03, MIN3x3-01, TETRA-SYNTH-01..09, PREVIEW-02 (bundled `fallback_tile_set` `.tres` files for the native layouts + 1-tile + 5-tile Tetra templates), TEMPLATE-04 (visual regression for the native layouts; templates 01/03 already shipped in commit e86036f).

**Success Criteria** (what must be TRUE):
1. DualGrid16 layout, with a 16-tile authored atlas, paints all 16 mask states correctly across the demo (each `r*4 + c` slot renders the expected silhouette per the corner-mask convention TL=1/TR=2/BL=4/BR=8).
2. Wang2Edge layout, with a 16-tile authored atlas, paints all 16 edge-mask states correctly (CR31 N=1/E=2/S=4/W=8). Visible difference from DualGrid16: the edge connections form lines/paths rather than filled regions.
3. Wang2Corner layout produces visuals identical to DualGrid16 on the same atlas data — different bit naming, same silhouettes (per the COMPARISON.md disambiguation).
4. Min3x3 layout, with a 9-tile authored atlas, paints all 16 edge-mask states correctly (single-grid pipeline, T=1/E=2/B=4/W=8 mask).
5. Each native layout's bundled fallback TileSet, when used with `tile_set == fallback_tile_set` (manually assigned), renders the greybox template correctly across all 16 slots.
6. **Tetra auto-detect** (TETRA-SYNTH-02): assigning a 1-wide source atlas → TETRA1 mode (5 archetypes synthesized from 1 source per strip); 4-wide → TETRA4 mode (5th synthesized); 5-wide → TETRA5 mode per-strip-refined (TETRA4 for strips with col 4 empty). Other widths trigger `update_configuration_warnings()`. NO pixel-content inspection used — dimension-based only.
7. **TETRA1 prototyping mode**: `TetraTileLayoutTetraHorizontal` with a 1-wide atlas containing one isolated-cell-with-all-edges-and-corners tile renders all 16 mask states correctly without broken seams. Visible regions tested: isolated cell, horizontal strip, L-shape, filled rectangle.
8. **`tile_count_mode` enum override** (TETRA-SYNTH-01): explicit `TETRA1` / `TETRA4` / `TETRA5` declaration skips detection and validates atlas content, with explicit warnings on mismatch.
9. **Tetra synthesis pixel-identity** (TETRA-SYNTH-06): with a v0.1 4-tile Tetra atlas attached (TETRA4 mode), the synthesized OppositeCorners produces pixel-hash-identical output to v0.1's overlay-layer composition for masks 6 and 9. Verified via deterministic hash comparison test (regression blocks merge).
10. **Overlay layer removed** (TETRA-SYNTH-05): `TetraTileMapLayer._overlay_layer` field, `_OVERLAY_LAYER_NAME` constant, `_paint_overlay_for_slot()`, and `AtlasSlot.diagonal_complement_atlas_coords` are all deleted. After Phase 2, `TetraTileMapLayer` has exactly ONE child visual layer (`_primary_layer`).
11. **Synthesis collision support** (TETRA-SYNTH-04): source tile collision/occlusion/navigation polygons are copied to synthesized tiles with appropriate transforms. Animation/custom-data/probability/y-sort explicitly NOT supported on synthesized tiles (use a different layout if needed; documented in DOC-03).
12. Bundled greybox templates ship for all three Tetra modes (TETRA-SYNTH-08): existing `tetra_horizontal.png`/`tetra_vertical.png` (TETRA4) + new `tetra_1_horizontal.png`/`tetra_1_vertical.png` (TETRA1) + new `tetra_5_horizontal.png`/`tetra_5_vertical.png` (TETRA5).

**Plans**: TBD

### Phase 3: TileBitTools-Decoded Layouts

**Goal**: Three layouts whose slot tables are transcribed from TileBitTools' MIT-licensed `.tres` files (Tilesetter Wang 15, Tilesetter Blob 47, Godot Blob 47) ship with attribution. Greyboxed template PNGs are generated for these three layouts from the slot tables.

**Depends on**: Phase 1 (layout dispatch). Independent of Phase 2 in principle, but sequenced after to keep the dependency chain linear.

**Requirements**: TBT-01, TBT-02, TBT-03, TBT-04, TEMPLATE-02, DOC-05.

**Success Criteria** (what must be TRUE):
1. `TetraTileLayoutTilesetterWang15`'s slot table matches TBT's `tilesetter_wang.tres` row-for-row (15 entries plus the stray-fill handling); a hand-painted Tilesetter Wang atlas attached to this layout paints correctly across all 15 mask states.
2. `TetraTileLayoutTilesetterBlob47`'s slot table matches TBT's `tilesetter_blob.tres` row-for-row (47 entries in the 11×5 atlas with sub-block gaps); a hand-painted Tilesetter Blob atlas paints correctly across all 47 mask states.
3. `TetraTileLayoutBlob47Godot`'s slot table matches TBT's Godot template row-for-row; a 47-tile atlas authored to TBT's Godot convention paints correctly across all 47 mask states.
4. `addons/tetra_tile/ATTRIBUTION.md` exists, credits TileBitTools by name with a link to https://github.com/dandeliondino/tile_bit_tools, copies the MIT license terms or links the upstream `LICENSE`, and identifies which TBT files were transcribed.
5. The 3 missing template PNGs (`tilesetter_wang_15.png`, `tilesetter_blob_47.png`, `blob_47_godot.png`) are produced by `_generate_greybox_templates.py` (deterministic, regenerable) and committed alongside the layout Resources.

**Plans**: TBD

### Phase 3.5: PixelLab Layouts + Variation-Seed Wiring

**Goal**: Ship `TetraTileLayoutPixelLabTopDown` and `TetraTileLayoutPixelLabSideScroller` subclasses. Both consume PixelLab Aseprite plugin native 8×8 atlas output with variation banks. Both share the locked role-to-mask bijection `[4, 10, 13, 12, 9, 14, 15, 7, 2, 3, 11, 5, 0, 8, 6, 1]` (corner mask). Wire `variation_seed` deterministic-hash bucket-pick: `mask → cells[]; pick = cells[hash(coord, variation_seed) % cells.size()]`.

**Depends on**: Phase 1 (architecture), Phase 2 or Phase 3 (single-grid pipeline first consumed by Wang2Corner in Phase 2).

**Requirements**: PIXLAB-01, PIXLAB-02, PIXLAB-03, PIXLAB-04, VAR-PIXEL-01.

**Success Criteria** (what must be TRUE):
1. `TetraTileLayoutPixelLabTopDown.compute_mask` and `mask_to_atlas` consume the locked role-to-mask mapping; visual regression on a PixelLab 8×8 sample matches the Aseprite plugin output.
2. `TetraTileLayoutPixelLabSideScroller` shares the role-to-mask mapping; cell-to-role differs (the side-scroller variant). Visual regression on a side-scroller PixelLab 8×8 sample passes.
3. Variation-bank: when a mask has multiple cells (PixelLab variations), `mask_to_atlas` returns a deterministic pick keyed on `(coord, variation_seed)`. Same `(coord, seed)` always returns the same cell across `rebuild()` invocations (no shimmering).
4. Setting `variation_seed = N` produces a different deterministic pick than `variation_seed = N+1`, verified visually on a uniform painted region.

**Plans**: TBD

### Phase 4: Fallback Routing

**Goal**: When `TetraTileMapLayer.tile_set == null` and `atlas_contract.layout != null`, the layer routes rendering through `layout.fallback_tile_set`. This is the prototyping UX win — drop a fresh layer into a scene with just a layout attached and start painting.

**Depends on**: Phase 1 (layer integration), Phase 2 (native fallback `.tres` files), Phase 3 (TBT fallback `.tres` files). Wires the consumer side once all 8 layouts have their fallback TileSets bundled.

**Requirements**: PREVIEW-03, PREVIEW-04. Final visual-regression sweep across all 8 layouts.

**Success Criteria** (what must be TRUE):
1. Creating a new `TetraTileMapLayer` node with `tile_set = null` and `atlas_contract` attached (with any of the 8 layouts) makes drag-paint produce visible greybox tiles immediately — no TileSet authored.
2. Assigning `tile_set` directly overrides the fallback (no warnings, no errors). Removing `tile_set` again (back to null) re-routes to the fallback.
3. All 8 layouts have a working fallback path: paint a small scene using each layout's fallback, confirm visible output matches the layout's template silhouettes.
4. The fallback routing path doesn't change behavior when `tile_set` is provided (regression check: existing v0.1-style scenes with `tile_set` set don't suddenly use fallback art).

**Plans**: TBD

### Phase 5: Demo Refresh + Documentation + Release

**Goal**: One updated demo scene showcasing all 8 built-in layouts, README sections documenting the library, CHANGELOG, and a tagged GitHub release.

**Depends on**: Phase 1, Phase 2, Phase 3, Phase 4 (consuming phase — uses every output of the prior phases).

**Requirements**: DEMO-01, DEMO-02, DEMO-03, DOC-01, DOC-02, DOC-03, DOC-04, REL-01, REL-02, REL-03.

**Success Criteria** (what must be TRUE):
1. The updated `tetra_tile_demo.tscn` showcases all 8 layouts — either via runtime layout switching (UI to swap `atlas_contract.layout`) or side-by-side `TetraTileMapLayer` instances arranged spatially. A casual playtester can see each layout in action.
2. The demo references the bundled fallback TileSets so it works out of the box without any authored tilesets (proves the prototyping UX).
3. Runtime drag-paint (existing `demo_runtime_painter.gd`) continues to work across all layouts in the updated demo without script changes beyond layout-switching glue.
4. README has a "Layouts" section listing all 8 built-in layouts with names, descriptions, atlas grids, tile counts, and which conventions they target. Plus "Upgrading from 0.1.x" and "Authoring a Custom Layout" (experimental).
5. `plugin.cfg` `version` field reads `0.2.0` exactly (no `-pre` / `-alpha` / `-dev` suffix). `CHANGELOG.md` has a v0.2.0 entry naming all breaking changes (`atlas_contract` introduction, deprecated `atlas_layout` enum, any property renames).
6. Downloading the v0.2.0 GitHub Release zip and extracting to a fresh Godot 4.6 project produces a working demo with no errors on first run; ATTRIBUTION.md is present at the addon root.
7. Final LOC audit confirms `addons/tetra_tile/` total surface area stays under TileMapDual's equivalent — the result included in the release notes.

**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 3.5 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Contract Skeleton + Tetra Layouts | 5/5 | Complete | 2026-04-26 |
| 2. Native Layouts + Tetra Synthesis (1/4/5 auto-detect) | 0/TBD | Not started | - |
| 3. TileBitTools-Decoded Layouts | 0/TBD | Not started | - |
| 3.5. PixelLab Layouts + Variation-Seed Wiring | 0/TBD | Not started | - |
| 4. Fallback Routing | 0/TBD | Not started | - |
| 5. Demo Refresh + Documentation + Release | 0/TBD | Not started | - |

## Coverage

All 54 v1 requirements (39 original + 6 added per Phase 1 discuss session, D-24..D-27 + 9 TETRA-SYNTH-* covering all three Tetra modes — TETRA1 prototyping, TETRA4 classic, TETRA5 hand-authored) mapped to exactly one phase. No orphans, no duplicates.

| Phase | Requirements (count) |
|-------|----------------------|
| 1. Contract Skeleton + Tetra Layouts | CONTRACT-01..05, LAYOUT-01..05, TETRA-01..03, PREVIEW-01 (14) |
| 2. Native Layouts + Tetra Synthesis (1/4/5) | NATIVE-01..03, MIN3x3-01, TETRA-SYNTH-01..09, PREVIEW-02 (partial), TEMPLATE-04 (partial) (15) |
| 3. TileBitTools-Decoded Layouts | TBT-01..04, TEMPLATE-02, DOC-05 (6) |
| 3.5. PixelLab Layouts + Variation-Bank Wiring | PIXLAB-01..04, VAR-PIXEL-01 (5) |
| 4. Fallback Routing | PREVIEW-03, PREVIEW-04 (2) |
| 5. Demo Refresh + Documentation + Release | DEMO-01..03, DOC-01..04, REL-01..03 (10) |
| **Pre-shipped (out-of-band, commit e86036f)** | TEMPLATE-01, TEMPLATE-03 (2) |
| **Total** | **39 + 6 + 9 = 54 / 54** |

> Phase 2.1 (Single-Tile separate class) was inserted 2026-04-26 then collapsed back into Phase 2 the same day. SINGLE-01..05 retired; intent rolled into TETRA-SYNTH-* via the TETRA1 mode of the unified Tetra layout.

> TEMPLATE-01 and TEMPLATE-03 already shipped in commit e86036f (5 of 8 greybox templates + the generator script). Counted as covered; the remaining 3 templates ship in Phase 3 as part of TEMPLATE-02.

## Identity Guardrails

The PROJECT.md identity constraint — "TetraTile must remain visibly smaller and simpler than TileMapDual" — is checked at four points across the roadmap:

- **End of Phase 1:** LOC checkpoint after the contract surface lands. The base class + AtlasSlot + TetraHorizontal/Vertical + integration in TetraTileMapLayer is the largest schema addition; if Phase 1 already pushes the budget, downstream phases have less room.
- **End of Phase 3:** LOC checkpoint after the standard 8 blob/wang/tetra layouts ship. Each layout is roughly 40–80 LOC; the cumulative footprint should still stay well under TileMapDual.
- **End of Phase 3.5:** LOC contribution from the two PixelLab layouts plus the `variation_seed` deterministic-hash wiring (~80–120 LOC total for both layouts + variation pick). Re-check the cumulative footprint after the 11-layout milestone closes.
- **End of Phase 4:** Compare the runtime hot path (`_update_cells` → `layout.compute_mask` → `layout.mask_to_atlas` → `set_cell`) against v0.1's straight-line `match` to confirm no significant perf regression at demo scale.
- **Phase 5 final audit:** Total `addons/tetra_tile/` LOC compared against TileMapDual's equivalent surface; result included in the release notes.

Per PROJECT.md, the quality bar is "works in my game" — visual regression on the demo is the primary verification mechanism, not a formal test suite. Demo-scale (~100–1k cells) is the only perf target; success criteria deliberately do NOT gate on perf.

Architectural anti-patterns explicitly NOT introduced (per `.planning/research/layouts/MASK_UNIFICATION.md` and the TileBitTools audit): no `EditorInspectorPlugin` polish, no Godot terrain peering-bit integration, no parallel painting API, no persistent coordinate cache, no watcher / signal-fanout systems, no multi-terrain transitions, no quarter-tile compositor.

---
*Roadmap re-spun: 2026-04-25 after v0.2 pivot to layout library*
