# Godot 4.6 Native Terrain System — Mechanical Reference

**Domain:** Godot 4.6 `TileSet` / `TileMapLayer` autotiling
**Researched:** 2026-04-25
**Confidence:** HIGH on documented API surface (verified in `docs.godotengine.org/en/4.6/` plus Context7 `/websites/godotengine_en_4_6`); MEDIUM on internal matching algorithm (no maintainer-authored algorithm spec exists; behavior reconstructed from issue threads, proposal #7670, and the Godot source layout); HIGH on community pain points (multiple corroborating GitHub issues and replacement plugins).

> **Why this document exists.** TetraTile's pitch is "autotiling that works out of the box if your atlas matches a known layout — no manual peering-bit authoring." That pitch is meaningful only if we can describe, precisely, what the user is currently forced to author *and* what TetraTile will do automatically in its place. This document is the reference spec for the system TetraTile is positioning against.

> **Note on naming.** Godot 4 calls this the **terrain** system. The Godot 3 name was **autotile**. The two systems are not API-compatible; Godot 4's terrain mode names (`MATCH_CORNERS_AND_SIDES`, `MATCH_CORNERS`, `MATCH_SIDES`) explicitly correspond to Godot 3's bitmask modes (`3x3`, `2x2`, `3x3 minimal`) — see the table in `using_tilesets.html` and the legacy `using_tilemaps.html` (3.5).

---

## Table of Contents

1. [Conceptual model: terrain sets, terrains, peering bits](#1-conceptual-model)
2. [`TileSet.TerrainMode` taxonomy and tile-count expectations](#2-terrainmode-taxonomy)
3. [`CellNeighbor` enum and per-mode validity rules](#3-cellneighbor-enum)
4. [Per-tile peering data: storage and API](#4-peering-data-storage)
5. [Painting API: `set_cells_terrain_connect` vs `set_cells_terrain_path`](#5-painting-api)
6. [Matching algorithm — what is actually documented vs inferred](#6-matching-algorithm)
7. [Determinism question, answered](#7-determinism)
8. [Limitations and pain points (with GitHub evidence)](#8-pain-points)
9. [Why no major dual-grid addon uses Godot's terrain system internally](#9-addons-bypass)
10. [Comparison points for TetraTile](#10-tetratile-comparison)
11. [Sources](#11-sources)

---

## 1. Conceptual model

A `TileSet` resource owns:

- **Sources** — `TileSetAtlasSource`, `TileSetScenesCollectionSource`. Each source owns tiles and their per-tile metadata (`TileData`).
- **Terrain sets** — flat list, indexed by integer. Each has its own `TerrainMode` and its own list of terrains.
- **Terrains** — flat list inside a terrain set, indexed by integer. Each has a name and color (color is editor-only, used for the peering-bit overlay).
- **Custom data layers, navigation layers, occlusion layers, physics layers, etc.** — orthogonal to terrains.

The hierarchy is two-deep:

```
TileSet
├── terrain_set 0  (mode = MATCH_CORNERS_AND_SIDES)
│   ├── terrain 0  ("grass")
│   ├── terrain 1  ("dirt")
│   └── terrain 2  ("water")
├── terrain_set 1  (mode = MATCH_SIDES)
│   ├── terrain 0  ("road")
│   └── terrain 1  ("rail")
└── ... sources ...
```

A tile (a `TileData` instance keyed by `(source_id, atlas_coords, alternative_id)`) belongs to **at most one** terrain set:

- `TileData.terrain_set: int = -1` — which terrain set this tile participates in (`-1` means none).
- `TileData.terrain: int = -1` — the **center terrain** (its own terrain ID inside that set; `-1` if the tile has no center terrain assigned).
- `TileData.set_terrain_peering_bit(peering_bit: CellNeighbor, terrain: int)` — for each *valid* direction (mode-dependent, see §3), the terrain ID this tile expects to find in that neighbor.

When the user paints with terrain `T` at cell `C` in terrain set `S`, Godot needs to pick a tile whose center terrain is `T` AND whose peering bits are consistent with the terrains present at `C`'s neighbors. (See §6 for what "consistent" means in practice.)

API surface for managing terrains/terrain-sets (verified in `class_tileset.html`):

```
TileSet:
  add_terrain_set(to_position: int = -1) -> void
  remove_terrain_set(terrain_set: int) -> void
  move_terrain_set(terrain_set: int, to_position: int) -> void
  get_terrain_sets_count() -> int
  get_terrain_set_mode(terrain_set: int) -> TerrainMode
  set_terrain_set_mode(terrain_set: int, mode: TerrainMode) -> void

  add_terrain(terrain_set: int, to_position: int = -1) -> void
  remove_terrain(terrain_set: int, terrain_index: int) -> void
  move_terrain(terrain_set: int, terrain_index: int, to_position: int) -> void
  get_terrains_count(terrain_set: int) -> int
  get_terrain_name(terrain_set: int, terrain_index: int) -> String
  set_terrain_name(terrain_set: int, terrain_index: int, name: String) -> void
  get_terrain_color(terrain_set: int, terrain_index: int) -> Color
  set_terrain_color(terrain_set: int, terrain_index: int, color: Color) -> void
```

(Caveat: Context7 returned several fabricated method names — `set_tile_terrain`, `terrain_set_add_terrain`, `terrain_set_set_transition`. These do **not** exist in Godot 4.6. The real API is the one listed above plus `TileData.terrain_set` / `TileData.terrain` / `TileData.set_terrain_peering_bit`. Treat any LLM-generated terrain code that calls those fabricated names as a red flag.)

When painting in the editor, the user picks `(terrain_set, terrain)` once via the Terrains tab and then click-paints — Godot's `set_cells_terrain_connect` runs internally per stroke.

---

## 2. `TileSet.TerrainMode` taxonomy

Source: `class_tileset.html` enum `TerrainMode`. Three values:

| Constant | Int value | Description (verbatim from docs) | Godot 3 equivalent |
|----------|-----------|-----------------------------------|---------------------|
| `TERRAIN_MODE_MATCH_CORNERS_AND_SIDES` | `0` | "Requires both corners and side to match with neighboring tiles' terrains." | `3x3` (full bitmask) |
| `TERRAIN_MODE_MATCH_CORNERS` | `1` | "Requires corners to match with neighboring tiles' terrains." | `2x2` |
| `TERRAIN_MODE_MATCH_SIDES` | `2` | "Requires sides to match with neighboring tiles' terrains." | `3x3 minimal` |

> The Godot 3.5 → 4 mapping comes from `using_tilesets.html`: *"These modes correspond to the previous bitmask modes autotiles used in Godot 3.x: 2×2, 3×3 or 3×3 minimal."*

### Bit count, state count, and full-coverage tile counts

The Godot 3.5 `using_tilemaps.html` page documents the legacy state-count math. Godot 4 inherits the same math (the modes are renamed, not redesigned), with one important architectural difference: Godot 4 collapses the legacy 3x3-full mode (256 states) into the same machinery as 3x3-minimal because the **center bit is no longer authored** — the center is implied by `TileData.terrain` itself.

| Mode | Peering directions | Distinct mask states (per-cell) | "Full coverage" tile count for one terrain (no transitions) |
|------|--------------------|----------------------------------|--------------------------------------------------------------|
| `MATCH_CORNERS` | 4 (the four corners only) | 2⁴ = 16 (15 non-empty + 1 empty) | **15 tiles** for a single-terrain blob. (The 16th = empty cell, no tile.) |
| `MATCH_SIDES` | 4 (the four cardinal sides only) | 2⁴ = 16 | **15 tiles**. |
| `MATCH_CORNERS_AND_SIDES` | 8 (4 corners + 4 sides) | 2⁸ = 256 raw, but only **47 are reachable** because corner bits are constrained by side bits (a corner cannot be set if the two adjacent sides are unset; otherwise the corner has no path to attach to the center). | **47 tiles** — the classic "blob" tileset. (See "blob autotiling" in any tile-art reference; Godot 3.5 docs explicitly state "3x3 minimal" needs 47 tiles, and 4.x's `MATCH_CORNERS_AND_SIDES` is the 4.x rename of that mode.) |

Confidence: HIGH on `MATCH_CORNERS` (16) and `MATCH_SIDES` (16). HIGH on `MATCH_CORNERS_AND_SIDES` requiring 47 for full single-terrain coverage (verified against Godot 3.5 docs and corroborated by the `Better Terrain` README's reference to 47-tile blob layouts and search results explicitly stating "Blob autotiling requires a set of 47 tiles + 1 empty tile").

### Multi-terrain explosion

For `N` terrains in a single set, the **transition** tile counts multiply. Each tile is a (center_terrain, peering_pattern) pair. With 8 peering directions and N+1 possible values per direction (N terrains + "empty"/`-1`), the worst-case search space per tile is `(N+1)⁸` for `MATCH_CORNERS_AND_SIDES`. In practice users author only the transitions they need, but every transition between two terrains effectively doubles the authoring burden in that mode.

### Canonical authoring layout

There is **no canonical atlas layout enforced by Godot**. Tiles can sit anywhere in any atlas; what makes them "the corner tile" or "the inside tile" is purely the peering bits the user paints onto them in the TileSet editor's Terrain tab. This is the load-bearing UX problem: **the visual layout of the atlas and the logical layout known to Godot are two entirely separate things**, and the user is responsible for keeping them in sync via mouse painting.

(This is the core difference from TetraTile's design: TetraTile **uses** atlas position as the source of truth — slot 0 is Fill, slot 1 is Inner Corner, etc. — so there is no second layer of metadata to author.)

---

## 3. `CellNeighbor` enum

Source: `class_tileset.html` enum `CellNeighbor`. The enum has **16 values** because it has to cover square, isometric, and hex grids in a single namespace. For a square grid only **8** of those 16 are meaningful.

| Constant | Int | Square grid? | Notes |
|----------|-----|--------------|-------|
| `CELL_NEIGHBOR_RIGHT_SIDE` | 0 | yes | east side |
| `CELL_NEIGHBOR_RIGHT_CORNER` | 1 | no (hex) | |
| `CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE` | 2 | no (hex/iso) | |
| `CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER` | 3 | yes | SE corner |
| `CELL_NEIGHBOR_BOTTOM_SIDE` | 4 | yes | south side |
| `CELL_NEIGHBOR_BOTTOM_CORNER` | 5 | no (hex) | |
| `CELL_NEIGHBOR_BOTTOM_LEFT_SIDE` | 6 | no (hex/iso) | |
| `CELL_NEIGHBOR_BOTTOM_LEFT_CORNER` | 7 | yes | SW corner |
| `CELL_NEIGHBOR_LEFT_SIDE` | 8 | yes | west side |
| `CELL_NEIGHBOR_LEFT_CORNER` | 9 | no (hex) | |
| `CELL_NEIGHBOR_TOP_LEFT_SIDE` | 10 | no (hex/iso) | |
| `CELL_NEIGHBOR_TOP_LEFT_CORNER` | 11 | yes | NW corner |
| `CELL_NEIGHBOR_TOP_SIDE` | 12 | yes | north side |
| `CELL_NEIGHBOR_TOP_CORNER` | 13 | no (hex) | |
| `CELL_NEIGHBOR_TOP_RIGHT_SIDE` | 14 | no (hex/iso) | |
| `CELL_NEIGHBOR_TOP_RIGHT_CORNER` | 15 | yes | NE corner |

For a **square grid**, the 8 valid neighbors are: `RIGHT_SIDE`, `BOTTOM_RIGHT_CORNER`, `BOTTOM_SIDE`, `BOTTOM_LEFT_CORNER`, `LEFT_SIDE`, `TOP_LEFT_CORNER`, `TOP_SIDE`, `TOP_RIGHT_CORNER`.

### `is_valid_terrain_peering_bit(peering_bit)` — what it actually checks

`TileData.is_valid_terrain_peering_bit(peering_bit)` returns true iff the direction is meaningful for `(grid_shape, terrain_mode)`. The docs state only "Returns whether the given peering_bit direction is valid for this tile" without listing the rules. From the source code's structure (see `tile_set.cpp` `is_valid_terrain_peering_bit_for_mode`) and the Cell shape constraints, the validity matrix for **square grids** is:

| Mode | Valid `CellNeighbor` directions (square grid) | Count |
|------|------------------------------------------------|-------|
| `MATCH_CORNERS_AND_SIDES` | `RIGHT_SIDE`, `BOTTOM_RIGHT_CORNER`, `BOTTOM_SIDE`, `BOTTOM_LEFT_CORNER`, `LEFT_SIDE`, `TOP_LEFT_CORNER`, `TOP_SIDE`, `TOP_RIGHT_CORNER` | **8** |
| `MATCH_CORNERS` | `BOTTOM_RIGHT_CORNER`, `BOTTOM_LEFT_CORNER`, `TOP_LEFT_CORNER`, `TOP_RIGHT_CORNER` | **4** |
| `MATCH_SIDES` | `RIGHT_SIDE`, `BOTTOM_SIDE`, `LEFT_SIDE`, `TOP_SIDE` | **4** |

Calling `set_terrain_peering_bit(peering_bit, t)` with an *invalid* `peering_bit` for the active mode emits a runtime error; the value is silently ignored. (Confirmed by issue #89909, which is specifically about `get_terrain_peering_bit()` returning errors when the direction is wrong for the mode.)

---

## 4. Per-tile peering data: storage and API

### `TileData` fields (verified in `class_tiledata.html`)

```
TileData:
  terrain_set: int                                         # default -1
  terrain: int                                             # default -1; the CENTER terrain
  set_terrain_peering_bit(peering_bit: CellNeighbor, terrain: int) -> void
  get_terrain_peering_bit(peering_bit: CellNeighbor) -> int
  is_valid_terrain_peering_bit(peering_bit: CellNeighbor) -> bool
```

`set_terrain_peering_bit` writes the **expected neighbor terrain** for one direction of one tile. The value is an `int`:

- `-1` ("empty") — this direction expects the neighbor cell to either be empty or contain a tile whose own terrain doesn't intersect this direction.
- `0..N-1` — this direction expects the neighbor cell to contain a tile with the given terrain ID *in the same terrain set*.

There is **no "wildcard"** value in stock Godot — every direction is either empty, or a specific terrain ID. This is one of proposal #4689's central asks: "Allow multiple terrain types as a tile's peering bits."

### Storage and serialization

`TileData` is a `Resource` subclass owned by `TileSetAtlasSource` indexed by `(atlas_coords, alternative_id)`. When the `TileSet` resource is saved (`.tres` or `.res`), `TileData` is serialized as part of the source. There is no separate file for terrain data.

The on-disk shape (visible in any `.tres` saved from the TileSet editor) for each tile that participates in terrains:

```
0:0/0/terrain_set = 0
0:0/0/terrain = 0
0:0/0/terrains_peering_bit/right_side = 0
0:0/0/terrains_peering_bit/bottom_right_corner = -1
0:0/0/terrains_peering_bit/bottom_side = 0
... (one line per VALID direction; invalid directions for the mode are not written)
```

Format: `<atlas_x>:<atlas_y>/<alternative_id>/terrains_peering_bit/<direction_name> = <terrain_id>`. The direction names use the `CellNeighbor` constant lower-cased and stripped of the `CELL_NEIGHBOR_` prefix.

Implication for any tool that wants to *generate* terrain metadata (e.g., a future "TetraTile → Godot terrain bridge"): you need to write per-tile peering bits via `TileData.set_terrain_peering_bit()` for every valid direction, for every tile in the atlas. For a 47-tile blob terrain that's 47 × 8 = **376 individual bit assignments** for one terrain. The "tedium" the user complains about is real and quantifiable.

### `terrain_id` semantics

`terrain_id` is a flat integer index into `TileSet.get_terrains_count(terrain_set)`. There is no namespace — terrain IDs in different sets are unrelated. Reordering terrains via `move_terrain()` automatically rewrites all peering bits referring to that terrain (per the docs: "updates atlas tiles accordingly"). This is one of the few places Godot does background bookkeeping for terrain metadata.

---

## 5. Painting API

### `TileMapLayer.set_cells_terrain_connect()`

Verified signature (`class_tilemaplayer.html`):

```
void set_cells_terrain_connect(
    cells: Array[Vector2i],
    terrain_set: int,
    terrain: int,
    ignore_empty_terrains: bool = true
)
```

Documented behavior:

> Updates all the cells in the `cells` coordinates array to use the given `terrain` for the given `terrain_set`. The function will fill an existing terrain area (cells not in the array) **with neighbors that share the same terrain**. […] If `ignore_empty_terrains` is true, empty terrains will be ignored when trying to find the best fitting tile for the given terrain constraints. **To work correctly, this method requires the `TileMapLayer`'s `TileSet` to have terrains set up with all required terrain combinations. Otherwise, it may produce unexpected results.**

Translation: the method takes a list of cells to convert to terrain `T`. It computes, for each affected cell (the painted cells **plus their neighbors that already use terrain `T`**), a target peering pattern, then asks the TileSet "give me a tile that matches this pattern" and writes it. The "neighbors get repainted too" is the headline feature — it's how a single click paints a corner tile next to existing fill.

### `TileMapLayer.set_cells_terrain_path()`

```
void set_cells_terrain_path(
    path: Array[Vector2i],
    terrain_set: int,
    terrain: int,
    ignore_empty_terrains: bool = true
)
```

Documented behavior:

> Update all the cells in the `path` coordinates array, so that each connect to the next, to use the given `terrain`. The function will fill an existing terrain area (cells not in the array) **only if it shares a corner/side with another cell from the path**. The function fails if a cell in the path doesn't have an horizontal or vertical neighbor in the path.

Translation: the method takes a **continuous path** of adjacent cells. Each pair of consecutive path cells is forced to be "connected" (share peering bits with each other) but not with terrain-T cells outside the path. This is how the editor's "Path" terrain mode draws roads next to each other without merging them.

### Editor mode mapping

The TileMap editor's Terrains tab exposes both as paint modes:

- **Connect mode** → `set_cells_terrain_connect` per stroke. Joins to existing terrain areas.
- **Path mode** → `set_cells_terrain_path` per stroke. Doesn't join to outside terrain areas.

There is also an implicit per-tile override mode where the user picks a specific tile from the atlas (the regular Paint tool) — that bypasses the terrain matching entirely.

### `ignore_empty_terrains`

When `true` (default), terrain-`-1`/"empty" peering bits are skipped during the matching step. In practice this means: if a cell's neighbor would force the matched tile to have an "empty" peering bit on that side, the match still succeeds even if no exact-match tile exists, by treating the empty side as a wildcard. When `false`, only tiles whose empty bits exactly match the empty-or-not state of neighbors are considered. The default exists because authoring exhaustive empty-bit variants is so expensive that most TileSets don't have them.

---

## 6. Matching algorithm — what is documented vs inferred

### What is documented

Almost nothing. The class docs for `set_cells_terrain_connect` say only "find the best fitting tile for the given terrain constraints." There is **no published spec** for what "best fitting" means.

### What is inferred from issue threads, proposal #7670, and the source structure

Per proposal #7670 (which is from a contributor working on a replacement and is the most authoritative public description of the current behavior):

> The existing implementation is "a local solver with a small scope, a linear update order, it only deterministically matches peering terrains that are the same as the tile terrain, and it cannot backtrack."

Reconstructed pipeline for a single `set_cells_terrain_connect(cells=[C], terrain_set=S, terrain=T)`:

1. **Determine the affected set.** Start with `C`. Add every neighbor of `C` (8 cells in `MATCH_CORNERS_AND_SIDES`, 4 in the others) that is currently using terrain `T` in set `S`. Affected cells get re-evaluated. Cells of *other* terrains do **not** get re-evaluated, even though their peering bits may now be wrong.
2. **For each affected cell `X`, build a target pattern.** The pattern is a `(center_terrain, peering_bits[8])` tuple where:
   - `center_terrain = T` for cells in the painted list.
   - For each neighbor direction valid in the mode, the expected terrain is read from the *current* tile in the neighbor cell (its `TileData.terrain`), or `-1` if the neighbor cell is empty.
3. **Look up tiles matching the pattern.** Internally, the TileSet maintains a cache (`_update_terrains_cache` in `tile_set.cpp`) that maps `(terrain_set, center_terrain, peering_pattern)` to a list of candidate tiles. The set of matching tiles is the value at that cache key.
4. **If multiple tiles match**, pick one via `get_random_tile_from_terrains_pattern()` which calls `Math::random()` (the global, un-seedable-from-userland generator unless you call `seed()` first). See §7.
5. **If no tile matches**, the algorithm falls back to a partial-match scoring loop: try to find the tile that maximizes the count of correctly-set peering bits. Empty bits are weighted by `ignore_empty_terrains`. If the fallback still finds nothing, the cell is **left as-is** — the algorithm does not error or clear the cell.
6. **Write the chosen tile** via `set_cell()`. Move to next affected cell.

Critical limitations of this approach (proposal #7670 again):

- **Linear update order.** Cells are processed in the order they appear in `cells`. A cell processed early may end up "wrong" once its neighbors are updated, but the algorithm doesn't re-examine it.
- **No backtracking.** If cell `A` picks a tile that makes cell `B` impossible to satisfy, `A` is not revisited.
- **Small scope.** Only the painted cells and their immediate same-terrain neighbors are considered. Other-terrain neighbors are not touched, so a paint stroke can leave a neighboring `dirt` tile with a peering bit pointing at `grass` even though `grass` is no longer there.
- **No principled empty handling.** "Empty" (`-1`) acts as both "no tile" and "wildcard, kind of" depending on `ignore_empty_terrains`, and the resulting tile choice for empty-adjacent cells is the chronic source of bug reports (#54587, #57783, #76493).

### Pattern computation, in concrete terms

For `MATCH_CORNERS_AND_SIDES` painting cell `C` with terrain `T`, the target peering pattern for `C` is:

```
center      = T
N           = (terrain of cell C+(0,-1), or -1)
NE corner   = (terrain of cell C+(1,-1) — but ONLY IF the N and E neighbors have terrain T)
E           = (terrain of cell C+(1,0), or -1)
SE corner   = (terrain of cell C+(1,1) — same caveat)
S           = (terrain of cell C+(0,1), or -1)
SW corner   = (terrain of cell C+(-1,1) — same caveat)
W           = (terrain of cell C+(-1,0), or -1)
NW corner   = (terrain of cell C+(-1,-1) — same caveat)
```

The "same caveat" on corners is the constraint that produces the 47-state count from the 256-state raw bitspace: a corner can only be set if both adjacent sides are also set, otherwise the corner is geometrically unreachable. This is the well-known "blob 47" reduction.

This **could** be re-derived purely from atlas position if the atlas layout is known and follows a canonical tile order — which is exactly the move TetraTile makes for its 4-tile layout, and the move TetraTile would have to extend to support a 47-tile blob layout.

---

## 7. Determinism

**Question: does the engine pick deterministically among matching tiles, or randomly?**

**Answer: random, via the global `Math::random()`, which is per-process state.**

Evidence chain:

1. Discussion #10948 (the user's known-about issue) directly addresses this: *"The TileMapLayer/TileSet terrain system uses randomization when selecting among multiple tiles that match the same terrain configuration. However, this randomization is non-deterministic, making it impossible to generate identical procedural levels programmatically."*
2. The same discussion describes the workaround: *"Just call `seed(...)` somewhere before calling `set_cells_terrain_connect`."* This works because Godot's `Math::random()` (the C++ side) is seeded by the same global state `seed()` controls in GDScript.
3. The source-side path is `set_cells_terrain_connect` → `get_random_tile_from_terrains_pattern` → `Math::random()`, confirmed by the proposal #10948 discussion.
4. The collaborator response (Groud) confirms the non-determinism is **intentional in the editor context**: the painter can re-stroke an area to randomize its appearance. He acknowledged that user-supplied seed support "would be fine."

Implications for runtime users:

- Calling `set_cells_terrain_connect` twice with identical inputs **does not** guarantee identical results.
- For procedural generation, you must call `seed()` immediately before each call. This is a global side effect that can interfere with other random consumers.
- For per-cell-deterministic visual variation (the TetraTile v0.2 milestone goal), the stock terrain system is actively *unsuitable* — its randomness is per-call, not per-cell.

Confidence: HIGH on the non-determinism (multiple corroborating sources including a maintainer-acknowledged proposal). HIGH on the `seed()` workaround. MEDIUM on the exact source-code path (we verified the call exists from the issue threads but did not inspect the full source).

---

## 8. Pain points (with GitHub evidence)

### Pain point 1: Manual peering-bit painting is mechanical and exhaustive

**Evidence:** [godot-proposals #5575 — "Rework the TileMap terrain system to improve its usability"](https://github.com/godotengine/godot-proposals/issues/5575). The proposal lists four critical complaints, two of which directly attack the authoring workflow: (1) "Editing terrains affects neighboring tiles in unexpected ways, often altering their type" and (2) order-dependent results.

**Quantification:** A 47-tile blob terrain in `MATCH_CORNERS_AND_SIDES` mode requires `47 × 8 = 376` individual peering-bit assignments per terrain. For a 2-terrain transition (grass+dirt) you need both terrains' tiles plus all transition tiles, often pushing the bit-painting count past 1,000 mouse clicks per atlas. This is the "tedious" the user is reacting to.

### Pain point 2: Non-determinism breaks procedural generation

**Evidence:**
- [godot-proposals discussion #10948](https://github.com/godotengine/godot-proposals/discussions/10948) — "In TileMapLayer / TileSet, add support for deterministic terrain randomization." Describes the exact scenario: building a level via GDScript produces different tiles each run.
- [godot/godot #76493](https://github.com/godotengine/godot/issues/76493) — "TileMap Terrain paints incorrect tiles from unrelated terrains." User reports tiles being chosen from terrains that shouldn't be candidates at all.
- [godot-proposals #7670](https://github.com/godotengine/godot-proposals/issues/7670) — "Refactor Terrain Tile Matching Algorithm for Accuracy and Determinism." Most thorough public analysis of why the current algorithm can't be made fully deterministic without backtracking and global solving.

### Pain point 3: Match Corners cannot draw a 2-wide strip

**Evidence:** [godot/godot #87929](https://github.com/godotengine/godot/issues/87929) — Click-painting in `MATCH_CORNERS` mode produces a 3×3 block instead of a 2×2 corner. The reporter states *"it seems impossible to create a 2-wide strip of 'match corners' terrain."* Root cause: the algorithm paints **tile centers** rather than **grid intersections**, which is geometrically wrong for corner-based modes. This is structurally identical to the dual-grid problem TetraTile solves — and Godot's solution is to not solve it. This is the strongest argument that **Godot's terrain system cannot replicate dual-grid semantics**, which is why dual-grid addons exist as separate systems.

### Pain point 4: Adjacent tiles fail to update on first paint pass

**Evidence:** [godot/godot #69737](https://github.com/godotengine/godot/issues/69737) — "Godot 4 terrain set auto-tiles not updating adjacent tiles consistently." Direct quote: *"Adjacent tiles seem to rarely update to the correct tiles according to the specified bitmask."* The reporter must paint over the same area "multiple times" to get correct results. This is the linear-update-order limitation surfacing as a workflow bug.

### Pain point 5: Tiles with no peering bits set are misclassified

**Evidence:** [godot/godot #57783](https://github.com/godotengine/godot/issues/57783) — Originally filed because a tile with no bits set (representing an "isolated" tile) wasn't recognized as a valid candidate. Closed via PR #61809, but the underlying conceptual issue (the engine has no clean way to say "this tile means *no neighbors*") still surfaces in #76493 and #87929.

### Pain point 6: API errors on cross-mode peering-bit access

**Evidence:** [godot/godot #89909](https://github.com/godotengine/godot/issues/89909) — `TileData.get_terrain_peering_bit()` returns error when called with a `CellNeighbor` that's invalid for the active terrain mode. This makes generic terrain-introspection code awkward to write — you have to call `is_valid_terrain_peering_bit` first for every direction, which is what TetraTile would have to do internally if it ever bridges to the terrain system.

### Pain point 7: NP-hard global solving, unsolvable with the current architecture

**Evidence:** Proposal #7670 contains the engineer-level analysis: *"The current algorithm is a local solver with a small scope, a linear update order, it only deterministically matches peering terrains that are the same as the tile terrain, and it cannot backtrack."* The proposal explicitly notes that fully solving the problem requires backtracking, which "is considered NP-Hard" in the worst case. This is why no maintainer has shipped the fix in 3+ years and why all major replacement plugins do their own solving.

---

## 9. Why no major dual-grid addon uses Godot's terrain system internally

Three replacement / sibling addons exist:

- **Better Terrain** ([Portponky/better-terrain](https://github.com/Portponky/better-terrain)) — Replaces `MATCH_SIDES` and `MATCH_CORNERS_AND_SIDES`. README states: *"It's also quite slow, and the API is difficult to use at runtime."* and *"very large functional gaps caused by the replacement of the Godot 3 autotile system."*
- **Terrain Autotiler** ([dandeliondino/terrain-autotiler](https://github.com/dandeliondino/terrain-autotiler)) — Drop-in replacement matcher. README pitches it as *"more accurate and deterministic terrain tile matching."* Notably, this one **stays compatible** with Godot's peering-bit metadata — it only replaces the *matcher*, not the metadata model. Even so, its existence is direct evidence the stock matcher is not fit for purpose.
- **TileMapDual** (the project TetraTile compares itself to) — Implements dual-grid autotiling. **Does not use Godot's terrain system at all.** It runs its own dual-grid logic on top of `TileMapLayer.set_cell()`.

**Why bypass?** Three structural reasons:

1. **Dual-grid semantics don't fit terrain semantics.** Godot's terrain operates on tile centers; dual-grid operates on grid intersections. Issue #87929 is a microcosm: Godot can't even draw a 2-wide path correctly in `MATCH_CORNERS`, because the operations that make sense for dual-grid don't exist as primitives.
2. **Runtime API is awkward and slow.** `set_cells_terrain_connect` is the only entry point. It allocates, mutates global RNG, and re-walks neighbors — overkill when the addon's own `_update_cells` already knows exactly which cells need updating.
3. **The metadata model is the *problem*.** Both TetraTile and TileMapDual exist partly to skip peering-bit authoring. Routing through a system whose only input is hand-painted peering bits would defeat the purpose.

**Why TetraTile in particular bypasses it:** TetraTile's mask is the 4-bit corner state of the *display* cell, derived purely from `get_cell_source_id()` reads on the *logic* cell — see `tetra_tile_map_layer.gd` lines 155–169. It needs zero per-tile metadata. Routing this through Godot's terrain system would require:
- Synthesizing a terrain-set + terrain on the user's TileSet,
- Synthesizing peering bits for every tile in the atlas (the thing TetraTile's whole pitch is "you don't need to author"),
- Calling `set_cells_terrain_connect` instead of doing the lookup directly,
- Surrendering determinism (TetraTile's mask→tile mapping is a static `match` statement).

This isn't a pure size win for the addon — it's an **identity loss**. The "no peering bits required" guarantee disappears.

---

## 10. Comparison points for TetraTile

### What TetraTile already does that overlaps with Godot's terrain matching

Verified against `addons/tetra_tile/tetra_tile_map_layer.gd`:

| Capability | Godot terrain | TetraTile current (`_update_cells` → `_paint_display_cell`) |
|------------|---------------|-------------------------------------------------------------|
| 4-bit corner-mask computation | Built into `MATCH_CORNERS` mode (step 2 of §6) | `_mask_at()` lines 155–165 — manual 4-bit OR |
| Lookup mask → tile | Cache lookup against authored peering bits | Static `match` on lines 116–152 |
| Multiple-match resolution | Random via `Math::random()` | N/A — TetraTile's mapping is one-to-one (no ambiguity exists) |
| No-match fallback | Partial-match scoring + leave-as-is | N/A — the 16 cases are exhaustive |
| Per-cell determinism | Non-deterministic (§7) | Fully deterministic (`match` is pure) |
| Authoring burden per atlas | 8 bits × N tiles (376+ for blob) | **Zero** — atlas position is the metadata |

The overlap is structural: both systems compute a mask from neighbors, then look up a tile. TetraTile is a specialization of the same idea at one specific atlas size with one specific corner-mode mask, achieved by hardcoding the lookup table that Godot tries to learn from peering bits.

### What TetraTile would *gain* by integrating with Godot's terrain system

1. **Stock paint tools "just work."** The TileMap editor's Terrains tab (Connect mode, Path mode, terrain selector dropdown) becomes a TetraTile-aware authoring surface for free. Currently those tools paint TetraTile's logic layer correctly because they paint *tiles*, but they don't speak in terrain semantics — the user can paint any atlas tile, not just "logic-on" or "logic-off."
2. **Multi-terrain becomes free.** The "outer transition tile support" parking-lot item from `PROJECT.md` (grass→dirt) maps cleanly onto adding a second terrain to the same terrain set.
3. **Better dialog with TileMapDual users.** Anyone with a 47-tile blob TileSet already authored for Godot's terrain system could drop TetraTile in if TetraTile speaks the same metadata.
4. **Editor visualization.** The Terrain tab's color overlay would show the user which tiles TetraTile will pick for which mask without a custom inspector plugin.

### What TetraTile would *lose* by integrating

1. **The "no manual bitmask authoring" promise.** Gone. To use Godot's terrain system, every tile needs peering bits painted. Even if TetraTile auto-paints them on first scan, the user now has metadata they can edit and break.
2. **Determinism.** §7 — Godot's matcher is non-deterministic by design. TetraTile's per-cell variation goal (v0.2.0) becomes much harder if tile selection is downstream of `Math::random()`.
3. **The 4-tile contract.** The 47-tile assumption is implicit in `MATCH_CORNERS_AND_SIDES`. To reach Godot's terrain system from a 4-tile atlas requires synthesizing 47 virtual tiles (via alternative tiles + transforms) and writing peering bits for each. That's worse, not better.
4. **The 2-wide-strip bug (§8 pain point 3) inherits.** TetraTile's correct behavior on dual-grid corner cases gets clobbered by Godot's tile-center painter.
5. **Lean architecture.** `_update_cells` currently calls `set_cell` directly. Routing through `set_cells_terrain_connect` adds a re-entrant path and forces TetraTile to defend against the matcher repainting the same cells back.

### The verdict for the v0.2.0 redesign

**Don't integrate.** The pain points TetraTile's pitch attacks (manual peering-bit authoring, non-determinism, dual-grid incompatibility) are exactly the features Godot's terrain system *brings*. The integration would invert TetraTile's value proposition.

**What TetraTile should do instead** to address the "stock paint tools" gap:
- Keep the contract Resource model from `STACK.md`. The contract describes atlas layout; per-cell semantics stay derived from atlas position.
- For the `MATCH_CORNERS_AND_SIDES` 47-tile case (a future roadmap item), the **mask system** (researcher 4's domain) needs a layout descriptor that maps each of the 47 reachable patterns to an atlas slot. That descriptor *is* the equivalent of Godot's per-tile peering bits — but it's **per-layout** (authored once by TetraTile maintainers), not **per-atlas** (authored repeatedly by every user).
- This is the same trick TetraTile already does for the 4-tile layout: bake the table into the addon, expose only "which atlas layout am I" as a config knob.

Restated: **Godot's terrain system asks every user to author the lookup table. TetraTile asks the addon author to author the lookup table once, and the user only declares which table to use.** That is the entire competitive position, and any integration with the engine's terrain system has to preserve it.

### README copy-ready bullet for "Why TetraTile vs Godot's terrain"

> Godot's built-in terrain system asks you to paint up to 8 peering bits onto every tile in your atlas — 376+ clicks for a single-terrain blob set, and the matcher is non-deterministic by design ([discussion #10948](https://github.com/godotengine/godot-proposals/discussions/10948), [proposal #7670](https://github.com/godotengine/godot-proposals/issues/7670)). TetraTile reads atlas position directly: drop a 4-tile atlas in TetraTile's order and you get correct dual-grid autotiling without authoring any per-tile metadata.

---

## 11. Sources

### Authoritative (HIGH confidence)

- [Godot 4.6 — `class_tileset.html`](https://docs.godotengine.org/en/4.6/classes/class_tileset.html) — `TerrainMode` enum, `CellNeighbor` enum, `add_terrain_set` / `add_terrain` / `set_terrain_set_mode` API.
- [Godot 4.6 — `class_tiledata.html`](https://docs.godotengine.org/en/4.6/classes/class_tiledata.html) — `set_terrain_peering_bit`, `get_terrain_peering_bit`, `is_valid_terrain_peering_bit`, `terrain`, `terrain_set` properties.
- [Godot 4.6 — `class_tilemaplayer.html`](https://docs.godotengine.org/en/4.6/classes/class_tilemaplayer.html) — `set_cells_terrain_connect`, `set_cells_terrain_path` signatures and descriptions.
- [Godot 4.6 — `using_tilesets.html`](https://docs.godotengine.org/en/4.6/tutorials/2d/using_tilesets.html) — Terrain authoring workflow, mode → 3.x bitmask correspondence, peering-bit color overlay.
- [Godot 4.6 — `using_tilemaps.html`](https://docs.godotengine.org/en/4.6/tutorials/2d/using_tilemaps.html) — Connect / Path painting modes.
- [Godot 3.5 — `using_tilemaps.html`](https://docs.godotengine.org/en/3.5/tutorials/2d/using_tilemaps.html) — Legacy bitmask state-count math (15 / 47 / 256 tiles for 2x2 / 3x3-minimal / 3x3). 4.x's TerrainMode is the rename of these.
- Context7 `/websites/godotengine_en_4_6` — cross-checked the above against current canonical docs. **Caveat**: returned several fabricated TileSet methods (`set_tile_terrain`, `terrain_set_add_terrain`, `terrain_set_set_transition`) that do not exist in 4.6. Treat any LLM-generated terrain code citing those as suspect.

### Community pain-point evidence (HIGH confidence — multiple sources corroborate)

- [godot-proposals #5575](https://github.com/godotengine/godot-proposals/issues/5575) — "Rework the TileMap terrain system." Four-point usability complaint.
- [godot-proposals #7670](https://github.com/godotengine/godot-proposals/issues/7670) — "Refactor Terrain Tile Matching Algorithm for Accuracy and Determinism." Most authoritative public algorithm description.
- [godot-proposals discussion #10948](https://github.com/godotengine/godot-proposals/discussions/10948) — "Add support for deterministic terrain randomization." (Cited in the prompt as known.)
- [godot/godot #69737](https://github.com/godotengine/godot/issues/69737) — Adjacent tiles don't update on first pass.
- [godot/godot #76493](https://github.com/godotengine/godot/issues/76493) — Matcher picks tiles from unrelated terrains.
- [godot/godot #87929](https://github.com/godotengine/godot/issues/87929) — `MATCH_CORNERS` cannot draw 2-wide strip; reveals tile-center vs intersection painting bug.
- [godot/godot #57783](https://github.com/godotengine/godot/issues/57783) — Tile-with-no-bits handling bug. Closed by PR #61809.
- [godot/godot #89909](https://github.com/godotengine/godot/issues/89909) — `get_terrain_peering_bit` errors on cross-mode access.
- [godot-proposals #4689](https://github.com/godotengine/godot-proposals/issues/4689) — "Allow multiple terrain types as a tile's peering bits." Wildcard-bit feature gap.

### Replacement-plugin evidence (MEDIUM confidence on internal claims, HIGH that bypass exists)

- [Portponky/better-terrain](https://github.com/Portponky/better-terrain) README — "tricky behaviors", "quite slow", "API is difficult to use at runtime", "very large functional gaps caused by the replacement of the Godot 3 autotile system."
- [dandeliondino/terrain-autotiler](https://github.com/dandeliondino/terrain-autotiler) README — replacement matcher built specifically for "accurate and deterministic" results, faster than the engine's, addresses "multiple open issues."

### Lower confidence / inferred

- §6 "Matching algorithm" pipeline reconstructed from proposal #7670 + issue threads + source-file structure. Not from a maintainer-authored spec. MEDIUM confidence overall, HIGH on the directional claims (linear, no-backtracking, local) because proposal #7670 quotes them verbatim.
- §3 "validity matrix" rules per mode + grid shape inferred from source structure. HIGH on the *square grid* validity table; MEDIUM on what changes for hex/iso (out of scope for TetraTile).

---

*Reference document for: TetraTile mask-system unification (researcher 4 input) and README "vs Godot's terrain" copy.*
*Researched: 2026-04-25*
