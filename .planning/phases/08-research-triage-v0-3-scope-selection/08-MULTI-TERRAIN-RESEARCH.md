# Multi-Terrain Support Research

**Date:** 2026-04-29
**Request:** Research proper terrain support for PentaTile, preferably multiple terrains and multiple atlases in one `TileSet` and one public `PentaTileMapLayer`, using Godot built-in terrain authoring where possible.
**Method:** Subagent research plus direct verification against Godot 4.6 docs, TileMapDual source/README, Better Terrain README/source, TileBitTools README, and the live PentaTile dispatcher.

## Executive Decision

PentaTile should not call Godot's terrain solver for generated output. It should use Godot terrain metadata as the authoring/indexing language, then keep PentaTile's own `_update_cells()` dispatcher as the runtime solver.

That means:

- Users still paint with normal `set_cell()` / editor tools on one public `PentaTileMapLayer`.
- A painted logic cell's `TileData.terrain_set`, `TileData.terrain`, and directional terrain peering bits become the terrain signature.
- PentaTile scans one `TileSet`, including multiple atlas sources and alternatives, into a transient candidate index.
- Generated visuals are still written with `TileMapLayer.set_cell(source_id, atlas_coords, alternative_tile)`.
- Godot's `set_cells_terrain_connect()` / `set_cells_terrain_path()` are not used for PentaTile output because they are a separate solver with native terrain-layout assumptions.

This changes the previous Phase 8 triage stance. "No terrain peering-bit integration" was too broad. The corrected firewall is: **read Godot terrain metadata; do not delegate solving/rendering to Godot's terrain painter and do not copy Better Terrain's full rule system unless the project identity is deliberately expanded.**

## Current PentaTile Limitation

The current v0.2.0 dispatcher is binary:

- `_has_logic_cell(logic_cell)` returns only occupied vs empty.
- `PentaTileLayout.compute_mask(coord, sample_fn)` receives a boolean sampler.
- `mask_to_atlas(mask, strip_index)` returns a `PentaTileAtlasSlot` containing `atlas_coords`, `transform_flags`, and `alternative_tile`, but no `source_id`.
- `_resolve_source_id()` picks one global atlas source (`atlas_source_id` or first source).
- `_paint_with_slot()` writes every generated cell using the same source ID.
- Penta `AUTO_STRIP` samples logic `atlas_coords` for strip selection, which is a useful precursor but not a complete terrain model.

So multi-atlas and multi-terrain support are blocked by two structural assumptions: boolean masks and one source ID per layer.

## Source Findings

### Godot Built-In Terrains

Godot `TileMapLayer.set_cell()` stores exactly three identifiers per cell: `source_id`, `atlas_coords`, and `alternative_tile`. This is good news for PentaTile because one public layer can paint from multiple atlas sources inside one `TileSet`.

Godot terrain sets are metadata on atlas tiles. The official TileSet guide says terrains are assigned to atlas tiles and used by a dedicated TileMap painting mode; terrain sets can match corners/sides, corners, or sides. It also notes that terrains can support terrain-to-terrain transitions because a tile may define several terrains at once.

Godot's `set_cells_terrain_connect()` updates the requested cells and may update neighbors to create terrain transitions. That behavior conflicts with PentaTile's deterministic generated-output layer: PentaTile needs to preserve its own mask/layout dispatch, synthesized Penta atlases, and dual-grid offset logic.

`TileData` exposes both custom data and terrain peering accessors, including `get_terrain_peering_bit(peering_bit)` and `set_terrain_peering_bit(peering_bit, terrain)`. That is the right bridge: use metadata as input, not Godot's solver as output.

Sources:

- Godot 4.6 `TileMapLayer.set_cell()` and terrain APIs: https://docs.godotengine.org/en/4.6/classes/class_tilemaplayer.html
- Godot 4.6 TileSet terrain guide: https://docs.godotengine.org/en/4.6/tutorials/2d/using_tilesets.html
- Godot 4.6 `TileData` custom data / terrain peering APIs: https://docs.godotengine.org/en/4.6/classes/class_tiledata.html

### TileMapDual

TileMapDual is the closest architectural cousin. It scans every atlas source in a `TileSet`, reads `TileData.terrain_set`, `TileData.terrain`, and peering bits, then builds rule structures used by display layers.

Important details:

- `terrain_dual.gd` iterates all TileSet sources and all atlas tiles.
- It only supports terrain set `0`; tiles in other terrain sets are warned and skipped.
- It registers source ID and atlas coordinates in its mappings.
- `terrain_layer.gd` stores rules in a trie keyed by neighboring terrain values.
- It treats empty as a sentinel terrain during lookup.
- It uses `TileData.probability` for weighted deterministic selection.
- The README explicitly encourages multiple TileMapDual layers for more than two terrain types.

The trick to borrow is the candidate index keyed by terrain-neighborhood signatures. The trick to avoid, at least for first pass, is TileMapDual's broad grid-shape system and multi-layer recommendation as the primary answer.

Sources:

- TileMapDual README: https://github.com/pablogila/TileMapDual
- TileMapDual `terrain_dual.gd`: https://raw.githubusercontent.com/pablogila/TileMapDual/main/addons/TileMapDual/terrain_dual.gd
- TileMapDual `terrain_layer.gd`: https://raw.githubusercontent.com/pablogila/TileMapDual/main/addons/TileMapDual/terrain_layer.gd

### Better Terrain

Better Terrain replaces Godot's solver with its own metadata, categories, decorations, cache invalidation, seeded weighted selection, and runtime update API. It works with existing `TileMapLayer` and `TileSet`, but it is intentionally a full terrain system.

Useful ideas:

- Terrain categories solve "these terrain types connect to each other" cases.
- Decoration terrain treats decorative edge tiles as empty for core terrain matching.
- Seeded weighted selection is important for deterministic variation.
- Runtime API separates "set terrain data" from "update terrain cells."

Rejected for PentaTile's first terrain pass:

- Full custom metadata schema.
- Versioned terrain-system metadata.
- Persistent tile cache/watchers as a core dependency.
- Terrains dock/editor replacement as baseline scope.

Sources:

- Better Terrain README: https://github.com/Portponky/better-terrain
- Better Terrain source: https://raw.githubusercontent.com/Portponky/better-terrain/main/addons/better-terrain/BetterTerrain.gd

### TileBitTools

TileBitTools is not a runtime solver. Its value is authoring: built-in templates, bulk terrain-bit editing, custom reusable templates, and explicit warnings that Godot 4 terrain placement differs from Godot 3 autotiles. It also confirms two constraints: hex/isometric and alternative tiles are outside its support.

For PentaTile, this points to documentation and template fixtures before heavy editor UI. Multi-terrain authoring is painful enough that exact atlas/terrain-bit recipes should ship with the feature.

Source:

- TileBitTools README: https://github.com/dandeliondino/tile_bit_tools

## Architecture Options

| Option | Summary | Pros | Cons | Verdict |
| --- | --- | --- | --- | --- |
| A. Native Godot terrain solver | Call `set_cells_terrain_connect()` and let Godot choose visuals. | Uses built-in editor behavior; true terrain-to-terrain transitions if fully authored. | Breaks PentaTile layout library, synthesized Penta atlases, dual-grid offset, deterministic hot path, and native `set_cell()` interception model. | Reject for generated visuals. |
| B. Godot terrain metadata + PentaTile solver | Read `TileData.terrain*` and peering bits; PentaTile picks candidates and paints with `set_cell()`. | One public layer, one TileSet, multiple atlas sources, deterministic, compatible with all current layout families by staged implementation. | Requires a terrain candidate index and new layout-aware matching path. | Recommended. |
| C. Per-terrain internal visual layers | Keep one public node, create hidden child visual layers per terrain. | Simple for dual-grid hard boundaries; avoids one-cell multi-quadrant conflicts. | Internally layer-based, can complicate collisions/z ordering, less aligned with the user's "one layer" ideal. | Fallback only for dual-grid if one-cell candidate coverage is too costly. |
| D. Runtime composite tile synthesis | Generate composite atlas tiles for terrain combinations. | One actual visual TileMapLayer cell can represent many terrains. | Combinatorial explosion, hard collision/custom-data semantics, much more code. | Research later, not first pass. |
| E. Better Terrain-style full solver | Categories, decorations, custom metadata, score-based matching. | Powerful and proven. | Turns PentaTile into a terrain framework, not a small layout dispatcher. | Reject unless identity is renegotiated. |

## Recommended Design

### 1. Add a Terrain-Aware Dispatcher Mode

Keep the public API exactly where it is: users paint logic cells with `set_cell()`. PentaTile samples terrain metadata from the painted tile:

```gdscript
var data := get_cell_tile_data(logic_cell)
var terrain_set := data.terrain_set
var terrain := data.terrain
```

An empty cell remains `terrain = -1`. If a painted tile has no terrain metadata, terrain-aware dispatch can warn and either treat it as a binary occupied tile or skip it, depending on the phase plan.

### 2. Build a Transient Terrain Candidate Index

Scan the active `TileSet` at dispatch/rebuild time:

- Iterate all `TileSetAtlasSource` sources when `atlas_source_id == -1`.
- Treat explicit `atlas_source_id >= 0` as a filter, not a global output source.
- Iterate atlas tiles and alternatives.
- Read `TileData.terrain_set`, `TileData.terrain`, `get_terrain_peering_bit()`, and `probability`.
- Store candidate records containing `source_id`, `atlas_coords`, packed `alternative_tile`, terrain identity, peering signature, and weight.

This is a tile-definition index, not a persistent coordinate cache. It can be rebuilt lazily when `tile_set` or `layout` changes and brute-force rebuilt during `rebuild()` at demo scale.

### 3. Route Output by Candidate, Not Global Source

The current `PentaTileAtlasSlot` is insufficient for multi-atlas output. Terrain-aware output must carry `source_id` as part of the selected candidate, or `PentaTileAtlasSlot` must gain an explicit `source_id`.

Also fix the existing split between `transform_flags` and `alternative_tile`: the final value passed to `set_cell()` is one packed alternative integer. Terrain support must preserve the Pitfall #1 rule: low alternative ID OR'd with transform flags, with alt ID under 4096.

### 4. Implement Single-Grid Layouts First

Best first target:

- `PentaTileLayoutWang2Edge`
- `PentaTileLayoutWang2Corner`
- `PentaTileLayoutMinimal3x3`
- `PentaTileLayoutBlob47Godot`
- PixelLab top-down / side-scroller after variation selection is reopened

These layouts already paint visual cells on the logic grid, so a cell can choose one terrain candidate directly. The terrain signature is "center terrain plus neighbor/peering terrains." This is the closest match to Godot's built-in terrain modes and TileBitTools templates.

### 5. Add Dual-Grid Terrain Support Second

Dual-grid display cells are harder because one display cell may need to represent four logic terrain IDs at once. The best one-layer approach is TileMapDual-style 4-corner signatures:

```text
display_cell -> [top_left_terrain, top_right_terrain, bottom_left_terrain, bottom_right_terrain] -> candidate tile
```

This can work in one public layer and one TileSet when users author the needed quadrant-combination tiles. The limitation is art coverage: for `N` terrains, the theoretical state space is `N^4` before symmetry/fallbacks. This is why TileMapDual recommends multiple layers for more than two terrain types.

Fallback policy should be explicit:

1. Exact quadrant signature candidate.
2. Same-terrain binary candidate when all non-empty quadrants share one terrain.
3. Priority terrain / hard-boundary candidate if configured.
4. Erase or warn when no candidate exists.

### 6. Treat Penta Layouts as Terrain Banks First

Penta archetypes are binary silhouettes: terrain vs empty. They are excellent for "stone bank", "grass bank", "sand bank" in one TileSet, but not inherently a universal grass-to-dirt-to-water transition format.

Recommended Penta path:

- Each terrain has its own Penta strip or atlas source.
- The painted logic tile's terrain metadata selects the bank.
- Existing Penta synthesis runs per bank.
- Mixed-terrain display cells treat other terrains as empty unless a future candidate-based transition mode is explicitly authored.

This preserves the Penta value proposition and avoids pretending five archetypes can encode arbitrary multi-terrain blends.

## Layout Feasibility Matrix

| Layout family | One TileSet / one public layer | True multi-terrain transition support | First-pass plan |
| --- | --- | --- | --- |
| Wang2Edge | High | Medium, if peering candidates are authored | Native terrain metadata candidate index |
| Wang2Corner | High | Medium, if peering candidates are authored | Native terrain metadata candidate index |
| Min3x3 | High | Medium-high, closest to Godot 3x3 minimal | Native terrain metadata candidate index |
| Blob47Godot | High | Medium, authored 47-style transitions required | Native terrain metadata candidate index |
| PixelLab | High | Medium, plus variation-bank work | Wait until deterministic variation reopens |
| DualGrid16 | Medium | Medium, but art grows toward `N^4` corner signatures | TileMapDual-style corner signature index |
| Penta | Medium | Low without extra transition candidates | Per-terrain Penta banks first |
| Single-Tile/Penta ONE | Medium | Low | Per-terrain source image bank |

## Risks and Hard Limits

- **One cell holds one tile.** A single generated `TileMapLayer` cell can paint only one `source_id/atlas_coords/alternative_tile` tuple. Arbitrary overlapping terrain visuals require either authored composite tiles or multiple visual layers.
- **Godot terrain metadata is not a layout table by itself.** PentaTile still needs layout-specific signature matching.
- **Dual-grid multi-terrain art cost grows quickly.** Exact four-corner combinations become expensive as terrain count rises.
- **Penta is binary by design.** Terrain banks are a clean fit; true terrain-to-terrain blends are a separate transition feature.
- **Collision/custom data need a policy.** Generated visual collisions may come from transition candidates, logic cells, or a separate logic path. Do not silently mix them.
- **Variation and terrain compete for atlas organization.** The old "Y axis as terrain" idea is too narrow; terrain identity should come from `TileData` metadata or source/bank indexing, leaving Y for variation where layouts need it.

## Requirement Updates

Supersede the older `MULTITERR-01..05` Y-axis-only brainstorm with this shape:

- `MULTITERR-01`: Terrain-aware mode samples `TileData.terrain_set` and `TileData.terrain` from painted logic cells.
- `MULTITERR-02`: A transient `TerrainTileIndex` scans all atlas sources and alternatives in one `TileSet`.
- `MULTITERR-03`: Generated output can route to per-candidate `source_id`, not only global `atlas_source_id`.
- `MULTITERR-04`: Single-grid layouts get first implementation and visual UAT.
- `MULTITERR-05`: Dual-grid layouts use 4-corner terrain signatures and explicit missing-candidate warnings.
- `MULTITERR-06`: Penta layouts support terrain banks first; true Penta transition art is `TERRAIN-01`.
- `MULTITERR-07`: Godot terrain metadata is input only; PentaTile does not call the built-in terrain solver for generated visuals.
- `MULTITERR-08`: Tests compose rendered output across at least 2 terrains, 3 terrains, multiple sources, alternatives/transforms, and the standard pattern matrix.

## Recommended First Phase

Create a dedicated phase after Phase 8 scope selection:

**Phase candidate:** Native Terrain Metadata Dispatch for Single-Grid Layouts

Deliverables:

1. Terrain candidate index over one `TileSet`, all atlas sources, and alternatives.
2. Source-aware output candidate painting.
3. Single-grid layout terrain signatures for Wang2Edge, Wang2Corner, Min3x3, Blob47Godot.
4. Deterministic weighted candidate selection using `TileData.probability`.
5. Inspector/configuration warnings for missing terrain metadata and missing candidates.
6. Demo scene showing at least grass/dirt/stone in one public `PentaTileMapLayer`.
7. Composed-canvas tests proving no shimmer on `rebuild()` and no wrong-source painting.

Dual-grid and Penta terrain support should follow once the single-grid candidate index is proven.
