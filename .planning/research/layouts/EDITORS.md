# External Editor & Engine Autotiling Conventions

**Scope:** Drop-in compatibility for atlases authored in other tools. For each editor we want to answer:

1. What does the *atlas image itself* look like (tile order, dimensions, count)?
2. What metadata does the editor attach (corner/edge colors, rules, peering bits, none)?
3. Is the convention **layout-only** (atlas position uniquely identifies tile semantics → TetraTile can ship a Resource) or **rule-based** (semantic meaning lives in editor metadata, not atlas position → harder to support)?
4. What mask system is implied (corner / edge / mixed / subtile composition)?
5. What does the user's authoring workflow look like?

The downstream consumer of this document is the `TetraTileLayoutXxx` Resource library. Layout-only conventions become built-in resources; rule-based conventions get deferred or require companion metadata import.

**Methodology note:** All findings below come from the editor's official documentation, GitHub repositories, or community wikis. Training data was deliberately not relied on. Where a source could not be verified, the section is flagged HONEST GAP. Confidence levels are explicit per editor.

---

## Quick-Reference Compatibility Matrix

| Editor / Engine | Mask System | Layout-Only? | Tile Count | Atlas Shape | TetraTile Effort |
|---|---|---|---|---|---|
| Tiled — Corner Set | Corner (V2) | No (rule-based) | 16 (full) / variable | Author-defined | Hard — needs `.tsx` wangid metadata import |
| Tiled — Edge Set | Edge (E2) | No (rule-based) | 16 (full) / variable | Author-defined | Hard — needs `.tsx` wangid metadata import |
| Tiled — Mixed Set | Mixed (V2E2) | No (rule-based) | 256 (full) / 47 (blob) | Author-defined | Hard — needs `.tsx` wangid metadata import |
| LDtk Auto-Layer | Rule patterns (1/3/5/7) | No (rule-based) | Arbitrary | Arbitrary | Hard — rules live in `.ldtk` JSON, not atlas |
| Tilesetter — Wang | Edge (E2) | **Yes** | 16 | Vendor-defined | Easy — fixed slot layout |
| Tilesetter — Blob | Mixed (V2E2) | **Yes** | 47 | 7×8 (with 9 unused) | Easy — fixed slot layout |
| Unity Rule Tile | Rule patterns (3×3) | No (rule-based) | Arbitrary | Arbitrary | Hard — rules in ScriptableObject, not atlas |
| RPG Maker A1 (water) | Subtile composition | **Yes** | 5-pattern blocks, animated | 768×576, 5 blocks ×3 frames | Medium — needs subtile compositor, not bitmask selector |
| RPG Maker A2 (ground) | Subtile composition | **Yes** | 32 kinds, 2T×3T blocks | 768×576 | Medium — needs subtile compositor |
| RPG Maker A3 (buildings) | Tile pairs (roof+wall) | **Yes** | Pair layout | 768×384 | Low priority — niche |
| RPG Maker A4 (walls) | Subtile composition (top + side) | **Yes** | 48 kinds | 768×720 | Medium — two compositors |
| RPG Maker A5 (normal) | None (regular atlas) | **Yes** | 128 tiles, 8×16 | 384×768 | Trivial — not autotiled |
| GameMaker — 16-tile | Edge (E2) | **Yes** | 16 (+1 fill) | Vendor template | Easy — fixed slot layout |
| GameMaker — 47-tile | Mixed (V2E2) | **Yes** | 47 | Vendor template | Easy — fixed slot layout |
| Aseprite tilemap | None / freeform | n/a | Arbitrary | Stack/Auto/Manual | n/a — not an autotile system |
| PyxelEdit | None (RPGM template) | Indirect | Variable | RPGM-shaped | Defer to RPG Maker layout |
| Pixaki | None | n/a | n/a | n/a | n/a — pixel-art tool, not autotile system |
| Godot 4.6 stock | Peering bits (corners/sides) | No (rule-based) | Arbitrary | Arbitrary | (covered by Researcher 3) |

**Legend:**
- **Layout-only:** Tile semantics can be inferred from atlas position alone. TetraTile can ship a single Resource describing slot positions.
- **Rule-based:** Tile semantics live in editor metadata (XML/JSON/ScriptableObject). TetraTile would need a metadata-import feature to consume these atlases.

---

## 1. Tiled Map Editor

**Source confidence:** HIGH — TMX format reference, scripting API, DeepWiki on tiled internals all consulted.

### Feature history

Tiled introduced "Terrains" in version 0.9 (a 2-corner system) and "Wang Tiles" in version 1.1 (a richer alternative). In **Tiled 1.5**, both features were unified into a single **Terrain Sets / Wang Sets** system. Terrain information defined in 1.5+ is *not* readable by older Tiled versions.

The legacy 4-corner-color terrain feature is gone. Modern Tiled has one mechanism with three set types.

### The three Wang Set types

Every Wang Set has a `type` attribute which controls what's matched at tile boundaries:

| Type | What's matched | Complete tile count (2 terrains) |
|---|---|---|
| **Corner** | Tile corners only | 16 |
| **Edge** | Tile sides only | 16 |
| **Mixed** | Both corners and sides | 256 (or 47 for "blob" subset) |

Up to 254 colors per set (255 since Tiled 1.5; capped at 254 since 1.10.2). Color 0 means "unset / don't care."

### How a tile is tagged: the `wangid` 8-position array

Every `<wangtile>` carries a `wangid` attribute. Since Tiled 1.5, this is a **comma-separated list of 8 integers** in the order:

```
top, top-right, right, bottom-right, bottom, bottom-left, left, top-left
```

So `wangid="1,2,2,1,1,2,2,1"`:
- Top edge = color 1, top-right corner = color 2, right edge = color 2, bottom-right corner = 1, bottom edge = 1, bottom-left corner = 2, left edge = 2, top-left corner = 1

For Corner Sets only the corner positions (1, 3, 5, 7 — odd indices) are meaningful; the edge slots (0, 2, 4, 6 — even indices) are zero. For Edge Sets it's the inverse.

**Pre-1.5 legacy format** (still appears in old projects): single 32-bit unsigned hex integer `0xCECECECE`, where each `C` is a corner color and each `E` is an edge color, in reverse order. Migration is one-way; old Tiled cannot read 1.5+ wangids.

### File format: relevant `.tsx` excerpt

```xml
<tileset name="grass" tilewidth="32" tileheight="32" tilecount="16" columns="4">
  <image source="grass.png" width="128" height="128"/>
  <wangsets>
    <wangset name="GrassEdges" type="edge" tile="-1">
      <wangcolor name="grass" color="#7eaa3d" tile="-1" probability="1"/>
      <wangcolor name="dirt"  color="#5b3a1d" tile="-1" probability="1"/>
      <wangtile tileid="0"  wangid="0,0,0,0,0,0,0,0"/>
      <wangtile tileid="1"  wangid="1,0,2,0,1,0,1,0"/>
      <!-- ... -->
    </wangset>
  </wangsets>
</tileset>
```

Key points:
- `<image source="grass.png">` — the atlas image. **This is just a regular image grid.** Tiled does not enforce any tile order; the user can arrange tiles however they like.
- `<wangset type="...">` — Edge / Corner / Mixed.
- `<wangcolor probability="1">` — relative selection weight when multiple tiles satisfy a constraint.
- `<wangtile tileid="..." wangid="...">` — the per-tile tagging. The `tileid` is a row-major index into the atlas grid; the `wangid` describes the colors at the 8 boundary positions.

### Painting algorithm (DeepWiki on Tiled internals)

Tiled separates painting into two stages:

1. **WangBrush** captures mouse events and decides which corner/edge the user is painting. For a corner brush it computes the nearest tile-grid corner using a 0.5 threshold on each axis; for an edge brush it picks the closest of the four edges.
2. **WangFiller** maintains a grid of `CellInfo { desired, mask }` entries and resolves tile choices:
   - **Hard filter:** Candidate tile must satisfy `(candidate.wangId & mask) == (desired & mask)`. Candidates that fail are rejected.
   - **Penalty score:** Unmasked indices accumulate a `transitionPenalty()` based on how distant the candidate's color is from neighbor colors.
   - **Lowest penalty wins.** Ties are broken by `WangSet::wangIdProbability() × Tile::probability()`.
   - **Forward checking** (when corrections are off and tileset is incomplete) ensures neighbors can still be satisfied.
   - **Correction propagation** (when corrections are on) re-resolves outward neighbors that no longer match, until consistent.

### Authoring workflow

1. Open or create a tileset (`.tsx`).
2. Use the Wang Sets panel to add a set, choose Edge/Corner/Mixed, define colors.
3. For each tile in the atlas, click corner/edge slots to assign colors. (No fixed atlas layout — paint in any tile order.)
4. Save `.tsx`; metadata travels with the tileset, not the image.

### Classification

- **Layout-only?** **No** — the atlas image alone is meaningless. The semantic data lives in the `<wangtile>` records inside the `.tsx`. Different artists can use radically different atlas arrangements for the same Wang Set.
- **Mask system:** Corner / Edge / Mixed (configurable per set).
- **Authoring step:** Paint atlas + tag every tile with wang colors → save `.tsx`.

### Implications for TetraTile

- A `TetraTileLayoutTiled` Resource that just describes "tile X in atlas slot Y" cannot work in general because Tiled has no canonical layout.
- However: if a community/vendor **convention** ("Tiled Edge 4×4 standard arrangement") exists, TetraTile could ship a layout for that. There is no such canonical arrangement in Tiled itself — artists draw their atlases in whatever order suits them.
- True drop-in support would require parsing `.tsx` to extract wangids → outside the deferred "file-format import" scope.

---

## 2. LDtk

**Source confidence:** HIGH — official docs + Bevy LDtk Rust types (which mirror the JSON schema 1:1).

### How LDtk separates "data" from "rendering"

LDtk's autotiling is fundamentally split:

- **IntGrid layer** stores per-cell integers (e.g., 1=wall, 2=grass). This is the source of truth.
- **Auto-layer** (or an Auto-Layer attached to an IntGrid) reads the IntGrid and applies pattern-matching **rules** to paint tiles from a tileset.

Two flavors:

1. **IntGrid layer with rules.** Single layer; user paints integers and rules render tiles automatically.
2. **Pure auto-layer.** Distinct layer that sources data from an external IntGrid layer. Used to render multiple visual variations from one logical IntGrid (e.g., foreground decoration + background fill from the same `walls` IntGrid).

**Tilesets in LDtk are just images.** They contain no rule data. Rules live in the project file (`.ldtk` JSON), attached to the layer definition.

### Rule pattern grid

Each rule has a `size` of **1, 3, 5, or 7** (only odd numbers). The rule's `pattern` is a `Vec<i32>` of `size × size` entries describing what IntGrid value each cell in the pattern must contain (with special values for "any" and "not-N").

So a wall-corner rule might be a 3×3 with center=`wall`, top=`empty`, left=`empty`, others=anything.

### Rule modifiers (the full field list)

From the JSON schema (`AutoLayerRuleDefinition`):

- `uid: i32` — unique ID
- `active: bool` — disable without deleting
- `pattern: Vec<i32>` — the size × size match grid
- `size: i32` — 1, 3, 5, or 7
- `checker: Checker` — None / Horizontal / Vertical (for checkerboard alternation)
- `flip_x: bool` — also try horizontally-flipped pattern; tile mirrors
- `flip_y: bool` — also try vertically-flipped pattern; tile mirrors
- `tile_rects_ids: Vec<Vec<i32>>` — array of candidate tile-ID rectangles (random pick)
- `tile_mode: TileMode` — Single or Stamp (Stamp = multi-cell brush)
- `tile_x_offset, tile_y_offset: i32` — visual offset within the cell
- `chance: f32` — application probability (0..1)
- `tile_random_x_min/max, tile_random_y_min/max: i32` — random placement jitter
- `perlin_active, perlin_scale, perlin_octaves, perlin_seed` — Perlin-noise gating
- `x_offset, y_offset, x_modulo, y_modulo: i32` — spatial periodicity
- `pivot_x, pivot_y: f32` — stamp pivot
- `break_on_match: bool` — defaults TRUE; if matched, no later rule applies in this cell
- `out_of_bounds_value: Option<i32>` — what value to use beyond level edge
- `alpha: f32` — opacity
- `tile_ids: Option<Vec<i32>>` — DEPRECATED, kept for back-compat

### Quick Rules (1.2.0+)

LDtk 1.2.0 introduced a **rules assistant**: instead of building rules one at a time, the user fills a pre-baked layout of "what tiles look like" — corner, edge, fill — and LDtk auto-generates the corresponding rules. By default, missing orientations are filled by symmetric variants (rotation/mirror), so the user only needs to draw a partial set.

I could not get the dedicated Quick Rules doc page (404). The 1.2.0 itch devlog confirms the feature: "fill layouts with your own tiles, and LDtk will create all the rules accordingly."

**HONEST GAP:** I do not have a complete picture of the exact "Quick Rule" layout templates LDtk uses. The 1.2.0 devlog implies multiple presets but the specific layouts (e.g., is there a 47-tile preset, a 16-tile preset?) are not documented in the sources I could access.

### Authoring workflow

1. Define IntGrid values in the layer settings (e.g., `1=wall`, `2=grass`).
2. Attach a tileset to the layer.
3. Open the Rules editor; either:
   - Use Quick Rules (paint a sample layout of your tiles → rules are auto-built), or
   - Author rules manually (define pattern grids, pick candidate tiles, set modifiers).
4. Paint with IntGrid values; the auto-layer renders tiles immediately.

### Classification

- **Layout-only?** **No.** LDtk tilesets are plain images with no inherent semantic structure. All meaning is in the `.ldtk` project's rule definitions.
- **Mask system:** Generalized pattern matching — far more flexible than corner/edge bitmasks. Rules can express things like "paint tile X if 5 cells away there's a wall" which no bitmask system can.
- **Authoring step:** Paint atlas in any order; define IntGrid values; build rules (or use Quick Rules to auto-generate them); paint integers, rules render tiles.

### Implications for TetraTile

- LDtk atlases are **not portable** to TetraTile via a layout Resource. The semantics live in the `.ldtk` project file, not the atlas.
- A user wanting "drop-in LDtk compatibility" would actually need a `.ldtk` rule importer, which is out of scope.
- However, if a user authored their tiles in LDtk *using a known fixed pattern* (e.g., the standard 47-tile blob arrangement) and exports the atlas image, TetraTile could still consume it via the matching `TetraTileLayoutBlob47` resource — but that's true regardless of LDtk; it's about the atlas convention, not LDtk specifically.

---

## 3. Tilesetter

**Source confidence:** HIGH for output formats and tile counts; MEDIUM for the per-edge sources UX (the docs page descriptions are sparse on workflow specifics).

### What Tilesetter is

A standalone authoring tool (Mac/Windows/Linux) that **builds final tilesets from per-edge "Sources"**. The user supplies a base texture and per-edge textures, and Tilesetter composites them into a finished autotile atlas.

### Sources system

Tilesetter separates **Sources** (image data) from **Tiles** (logical tile definitions referencing one or more Sources). A composed tile pulls from multiple sources:

- A **base** source (the fill texture).
- Per-edge sources for top, bottom, left, right.
- Optionally, per-corner sources for outer/inner corners.

By default, corners are auto-generated by splicing intersecting edge textures. The user can override with dedicated corner graphics if the auto-spliced result is wrong (common for stylized art).

A `Cutoff` property controls how many pixels of the base texture are shaved at the edges, preventing the base from bleeding past the edge graphic.

### Output: Blob Sets vs Wang Sets

Two output configurations:

**Wang Set output**
- 16 tiles
- Suited for top-down views
- Borders sit in the middle of tiles
- Edge-style autotiling (E2 in Boris's classification)

**Blob Set output**
- 47 tiles
- Suited for platformer / sidescroller views
- Borders on opposite sides with merge points (prevents overlapping edge textures)
- Mixed-style autotiling (V2E2 with 47-tile restriction)
- Packed into a 7×8 atlas grid (47 used + some unused slots)
- Each tile is composed of 9 parts: a center + 8 side/corner overlays

### Tile order

The 47-tile blob arrangement uses **binary indexing**: an 8-bit mask
```
N = 1, NE = 2, E = 4, SE = 8, S = 16, SW = 32, W = 64, NW = 128
```
combined with the **blob constraint**: an edge between two corners is only present when both corners are present. This collapses the 256 raw permutations down to 47 valid configurations.

The 47 valid base indices (per Boris the Brave's blob reference) are:
```
0, 1, 5, 7, 17, 21, 23, 29, 31, 85, 87, 95, 119, 127, 255
```
plus all rotations (multiply by 4 mod 256). The atlas slot for each tile is a fixed mapping (Tilesetter uses a 7-column-wide pack), so consumers can compute the correct slot deterministically from the bitmask.

**HONEST GAP:** The Tilesetter docs do not publish the exact slot-by-slot mapping table. The 7×8 packing and binary indexing are documented in community references; reverse-engineering the precise slot order would be needed for a `TetraTileLayoutTilesetter47` Resource. This is feasible but not done in this research pass.

### Export targets

Tilesetter exports to:

- **Defold** — selected tiles export, no behaviors
- **GameMaker Studio 2** (`.yy`) and GMS2 2.3.0+ — auto-tile pre-configured
- **Godot** — auto-tile bitmasks pre-configured for Blob and Wang sets
- **Unity** — `.unitypackage`; auto-tiling pre-configured but requires `2d-extras` (Rule Tile system) installed
- **Image** — straight PNG of the selection
- **JSON** — PNG + JSON sidecar describing tile placements

The `Auto-tile bitmasks are already configured for Blob and Wang sets when exporting from the Set View` line is the key insight: Tilesetter knows the canonical bitmask-to-slot mapping for both modes, and bakes it into each engine's native autotile configuration.

### Authoring workflow

1. Import or paint a base texture and edge textures as **Sources**.
2. Configure per-tile which sources apply to which edges (Tile Properties View).
3. Choose Blob or Wang set type.
4. Press "Generate Tileset" → Tilesetter composes the final 16 or 47 tile atlas.
5. Export to Godot / Unity / GMS2 / image+JSON.

### Classification

- **Layout-only?** **YES** for the output atlas. Once Tilesetter generates the 47-tile blob (7×8) or 16-tile Wang atlas, the slot positions are fixed and deterministic — no per-tile metadata needed for a consumer that knows the convention.
- **Mask system:** Edge (Wang Set 16-tile) or Mixed (Blob 47-tile).
- **Authoring step in Tilesetter:** edge-source authoring → Generate Tileset. The user does not paint each composed tile by hand; Tilesetter composes them.
- **Authoring step in TetraTile to consume:** drop the exported PNG into a Godot project; attach `TetraTileLayoutTilesetterWang16` or `TetraTileLayoutTilesetterBlob47` Resource; done.

### Implications for TetraTile

- **Tilesetter is the friendliest external tool to support** — its outputs are deterministic and layout-only.
- Two layout Resources are sufficient: one for 16-tile Wang, one for 47-tile Blob.
- The exact slot mapping for the 47-tile blob needs to be empirically derived (paint a known atlas in Tilesetter, observe which tile lands in which slot, codify). The 16-tile arrangement is more standardized across the industry (see GameMaker section below).

---

## 4. Unity 2D (Rule Tile)

**Source confidence:** MEDIUM — Unity docs page is light on storage details; the rule pattern, default sprite, and brush list are well documented; the on-disk format details required some inference.

### Rule Tile basics

`RuleTile` is the headline autotile asset in Unity's `2D Tilemap Extras` package (since 2018; current LTS package version 4.0+). It is a **ScriptableObject** asset (`.asset` file) — not just an image.

Each Rule Tile has:

- A **Default Sprite** (fallback)
- A list of **Tiling Rules**, each containing:
  - A **3×3 neighbor pattern** (center + 8 neighbors)
  - Per-neighbor flag: **Don't Care** / **This** (must be same Rule Tile) / **Not This** (must not be same Rule Tile)
  - Output mode: **Fixed** sprite / **Random** (list of sprites with weights) / **Animation** (list of sprites cycled)
  - Transform mode: **Fixed** / **Rotated** (also tries 90/180/270° rotations) / **Mirror X / Y / XY**
  - Optional GameObject to spawn
  - Collider type override

### Rule evaluation

Rules are evaluated **top-to-bottom**. The first match wins. Hence the optimization tip in Unity's docs: "Set the most common Rule at the top of the list."

The "Don't Care" flag lets a single rule cover many neighbor configurations. With Rotated transform mode, a single rule covers all four 90° rotations — a "tile with one neighbor on top" rule covers all four cardinal cases.

### Tile types in 2D Tilemap Extras

Confirmed from the latest doc page:

- **Animated Tile** — frame-by-frame animation, no neighbor matching
- **Rule Tile** — 3×3 neighbor pattern matching (described above)
- **Hexagonal Rule Tile** — Rule Tile for hex grids
- **Isometric Rule Tile** — Rule Tile for isometric grids
- **Rule Override Tile** — replace sprites/GameObjects in another Rule Tile without copying its rules
- **Advanced Rule Override Tile** — override a *subset* of rules

The latest docs do not list "Random Tile" or "Pipeline Tile" as separate tile types in the current version. Earlier versions of `2d-extras` had a Random Tile; that functionality is now subsumed into Rule Tile's "Random" output mode and the **Random Brush**.

### Brushes

- **GameObject Brush** — places GameObjects directly
- **Group Brush** — grabs groups of tiles by relative position
- **Line Brush** — draws line of tiles between two points
- **Random Brush** — places random tiles

The Pipeline Brush from older versions is not in current docs.

### Atlas conventions

Rule Tile imposes **no atlas layout requirements**. The user can have a Texture2D with sprites sliced however they like (via the Sprite Editor); the Rule Tile asset references each sprite individually in its rule outputs.

### Authoring workflow

1. Slice a sprite sheet in the Sprite Editor into individual sprites (any layout, any order).
2. Create a Rule Tile asset (Project → Create → 2D → Tiles → Rule Tile).
3. Set the Default Sprite.
4. Add Tiling Rules: configure the 3×3 pattern, pick output sprite(s), set transform mode.
5. Drag the Rule Tile to the Tile Palette; paint with it.

### Classification

- **Layout-only?** **No.** Atlas layout is irrelevant; rules and sprite references live in the `.asset` ScriptableObject.
- **Mask system:** Generalized 3×3 pattern matching with rotation/mirror permissions per rule. Roughly equivalent to Boris-classification S-V2E2 with rotation symmetries when transform=Rotated, but rule mode is fully expressive.
- **Authoring step:** slice atlas → author Rule Tile asset (rules + sprite refs) → paint.

### Implications for TetraTile

- A user moving a Unity-authored atlas to Godot would lose the Rule Tile metadata entirely. A layout Resource cannot recover it.
- Tilesetter's Unity export sidesteps this by configuring auto-tiling for the user; the underlying atlas is still in Tilesetter's Wang or Blob convention. TetraTile can consume the atlas image directly via the matching `TetraTileLayoutTilesetterXxx` Resource and ignore the Unity-side config.
- Direct "Unity Rule Tile" support is out of scope — would require parsing Rule Tile `.asset` files and translating rule expressions into TetraTile masks. Not a layout-only path.

---

## 5. RPG Maker MV / MZ

**Source confidence:** HIGH — official MZ asset standards page + tileset-format-specs GitHub repo + RPG Maker blog tutorial all consulted.

RPG Maker is the hardest case. Its autotiling is **fundamentally different** from corner/edge bitmask systems: the engine **composes a 48×48 final tile from four 24×24 quarter samples** drawn from a fixed-shape autotile sheet. There is no per-tile bitmask selection of a single source tile — every visible tile is constructed at runtime.

### The five sheet kinds

| Sheet | Purpose | Dimensions (MZ) | Animated? | Local kinds | Layout |
|---|---|---|---|---|---|
| A1 | Animated terrain (water, lava) | 768×576 | YES (3 frames horizontal) | 5 patterns × animated | 5-pattern blocks |
| A2 | Ground (grass, dirt, sand) | 768×576 | NO | 32 | 8 cols × 4 rows of 2T×3T blocks |
| A3 | Buildings (roof + wall) | 768×384 | NO | 16 | 8 horizontal × 4 vertical |
| A4 | Walls (top + side) | 768×720 | NO | 48 | 16T × 15T, 3 vertical bands |
| A5 | Normal (non-autotile) | 384×768 | NO | 128 | 8 × 16 grid |
| B-E | Upper layers (props, decorations) | 768×768 | NO | 256 | 16 × 16 grid |

T = tile size = 48 pixels. Q = quarter size = 24 pixels.

### A2 ground autotile: how subtile composition works

A single A2 "kind" occupies a 2T-wide × 3T-tall block (96×144 pixels, or 4×6 quarter-cells). This 2×3 block contains:

- **Top-left tile** (T×T): The "preview" tile shown in the editor — never used in maps.
- **Remaining quarters across the 2×3 block:** 24 quarter-textures grouped into colored regions: red (always upper-left of composed tile), green (always upper-right), yellow (always lower-left), blue (always lower-right).

When the engine needs to render a cell with a given neighbor configuration:

1. Look up the neighbor pattern in the **`FLOOR_AUTOTILE_TABLE`** (48 entries for A2/A4-walltops, 16 for A4-walls).
2. The table entry specifies, for each of the 4 quarters (TL, TR, BL, BR), which (col, row) within the 2×3 block to sample.
3. Copy the four 24×24 quarter pieces into the destination tile at offsets (0,0), (24,0), (0,24), (24,24).

This produces 47 unique compositions per kind (48 if you include the all-fill case) — equivalent to the 47-tile blob, but stored as 6 quarters' worth of source material per kind instead of 47 pre-rendered tiles.

**Why this is fundamentally different:**
- Corner/edge bitmasks **select** a single tile from an atlas based on neighbors.
- RPG Maker **constructs** a tile by stitching four quarter-samples chosen by neighbor pattern.
- A 47-blob atlas has 47 distinct source images; an A2 kind has 24 quarters worth of source (~6 logical tiles' worth) and the engine composes 47 visually distinct outputs from them.

### A1 animated autotile

A1 sheets follow A2's layout but the kind block is replicated **horizontally three times** for animation frames (water ripples, lava flow). The animation is independent of the autotile composition — the engine swaps the source block per frame and re-composes.

Waterfalls animate vertically (3 frames stacked) instead of horizontally.

### A3 building autotile

A3 is a "roof + wall" pair convention. The top half of a kind is the roof texture, the bottom half is the wall. When stacked vertically on the map, the engine draws both halves automatically. Less general than A2 — no full corner support, but suited to RPG Maker's iconic top-down village look.

### A4 wall autotile

A4 has two different composition tables:

- **Wall-top** kinds (top portion of each band, 8 kinds × 3 bands = 24 wall-tops): use `FLOOR_AUTOTILE_TABLE` (same as A2, 48 entries).
- **Wall-side** kinds (bottom portion, 8 kinds × 3 bands = 24 wall-sides): use `WALL_AUTOTILE_TABLE` (16 entries — only 4-direction matching, no corners).

This mirrors the RPG-tile-format split between "floor-style" and "wall-side-style" autotiles.

### A5 normal tiles

A5 is **not autotiled**. It's a plain 8×16 atlas of 128 stand-alone tiles. Just a regular atlas.

### B / C / D / E layers

Upper-layer atlases (props, doodads). Plain 16×16 atlases of 256 tiles each. Not autotiled.

### Authoring workflow

1. Start from the official RPG Maker A1/A2/A3/A4/A5 templates (correct dimensions and quarter-block structure).
2. Paint pixel art **per quarter region**, respecting the color-coded quadrant assignment (red=UL, green=UR, yellow=LL, blue=LR within composed tiles).
3. Drop the PNG into the project's `img/tilesets` folder using the correct filename prefix (`A1_`, `A2_`, etc.).
4. The engine handles all composition at runtime via the lookup tables.

### Classification

- **Layout-only?** **YES** in the sense that the atlas slot positions and quarter-block geometries are fixed and known. A consumer that implements the lookup tables can render the same composition the official engine does.
- **Mask system:** **Subtile composition** — categorically different from corner/edge tile selection. Implementing this means writing a quarter-sample compositor, not a tile-selector.
- **Authoring step:** paint within the fixed quarter regions of the template; no metadata file.

### Implications for TetraTile

This is the **hardest** convention to support and the most different from TetraTile's current architecture.

- A `TetraTileLayoutRPGMakerA2` Resource cannot just describe slot positions — it would also need a **subtile compositor**: at runtime (or at atlas-bake time), pick four quarter-samples from the source block and stitch them into a `(4n)×(4m)` synthesized atlas.
- TetraTile's current 16-state binary mask is the *output* of this composition (mask → composed tile), but the *source* art is at quarter granularity.
- One viable architecture: at TileSet load time, run a compositor that produces 47 (or 16) full-size tiles from each A2 kind, then have a normal `TetraTileLayoutBlob47` lookup against the synthesized atlas. This keeps TetraTile's runtime simple at the cost of a baking step.
- Alternative: skip A2/A4 quarter-composition entirely and only support A5 (the plain non-autotile atlas). Trivial but defeats most of the value.
- A1 animated water requires per-frame composition and ties into Godot's TileSet animation feature. Probably out of scope for v0.2.

A1/A2/A3/A4 should be deferred behind a TetraBake-style baking utility. A5 + B/C/D/E (plain atlases) are not autotile concerns at all.

---

## 6. Godot 4.6 Stock Terrain System

**Source confidence:** HIGH — official Godot docs.

Cross-referenced because the question asks: do other editors share Godot's terrain conventions?

### Godot's three terrain modes

In Godot 4 (current 4.6 stable as of April 2026), TileSet `Terrain Sets` have three modes:

- **Match Corners and Sides** — corresponds to Godot 3.x's 2×2 bitmask
- **Match Corners** — corresponds to Godot 3.x's 3×3 minimal bitmask
- **Match Sides** — corresponds to Godot 3.x's 3×3 bitmask

Each tile in a terrain set has **Terrain Peering Bits** — per-direction terrain values that say "this tile's left edge is terrain 0, top-left corner is terrain 1, etc." When painting, Godot looks up tiles whose peering bits match the surrounding terrain configuration.

### Comparison to other systems

| System | Match-Corners-and-Sides equivalent | Author shape |
|---|---|---|
| Godot — Match Sides | Tiled Edge Set (with peering instead of wangid) | Free atlas + per-tile peering metadata |
| Godot — Match Corners | Tiled Corner Set | Free atlas + per-tile peering metadata |
| Godot — Match Corners and Sides | Tiled Mixed Set | Free atlas + per-tile peering metadata |
| Tilesetter Wang | Match Sides (16) | Vendor-fixed atlas |
| Tilesetter Blob | Match Corners and Sides (47) | Vendor-fixed atlas |
| GameMaker 16-tile | Match Sides | Vendor-fixed template |
| GameMaker 47-tile | Match Corners and Sides | Vendor-fixed template |
| LDtk | Strictly more general | Free atlas + per-rule patterns |
| Unity Rule Tile | Strictly more general | Free atlas + per-rule patterns |
| RPG Maker A2/A4 | Subtile composition (orthogonal) | Vendor-fixed template |

**Key insight:** Godot's stock terrain is the same *family* as Tiled (free atlas + per-tile metadata) but uses *peering bits* instead of *wangids*. Conceptually equivalent; data formats incompatible. Tilesetter's Godot export likely targets the peering-bit format.

No other editor I researched uses Godot's exact peering-bit data format. Godot is a fellow rule-based system, not a layout-only one.

---

## 7. GameMaker Studio 2

**Source confidence:** HIGH — official manual + community tutorials confirm.

### The two templates

GameMaker Studio 2 ships with **two fixed-slot autotile templates**:

**16-tile template**
- 16 unique tiles + 1 fill tile (sometimes the user supplies a 17th solid tile)
- Edge-based matching (4 cardinal neighbors only)
- Suited for top-down terrain (grass, dirt) where wider transitions look better
- Cannot create paths narrower than 2 tiles

**47-tile template**
- 47 tiles, full mixed corner/edge matching (V2E2 blob)
- Suited for platformer structural features (walls, fences, holes, water)
- Can create 1-tile-wide paths
- Same 47-tile blob convention as Tilesetter and the wider community

### Authoring workflow

1. Import the source spritesheet into GameMaker.
2. Open Tile Set Editor → Auto Tile Sets → "+" → choose 16-tile or 47-tile template.
3. The template shows a grid where light-grey areas represent solid tile content and dark-grey areas represent empty space.
4. Click each template slot in order; for each slot, click the corresponding tile from the user's spritesheet.
5. The selected slot is highlighted red and auto-advances to the next.
6. **Every slot must be filled** for the auto tile library to function.

This is the **canonical "fill the template" UX**. Unlike Tiled's free-form wangid tagging or LDtk's rule pattern editor, GameMaker enforces a fixed slot order and the user maps their existing tiles into the predefined slots.

### Atlas conventions

Templates come in resolutions 8×8, 16×16, 32×32, 64×64, 128×128. Internal slot order is GMS2-specific but well documented (community-published cheat-sheets exist).

### Classification

- **Layout-only?** **YES.** Once the user fills the template, the resulting tileset image has fixed slot semantics. A third-party consumer that knows the GMS2 slot order can use the atlas directly.
- **Mask system:** Edge (16-tile) or Mixed (47-tile blob).
- **Authoring step:** paint atlas in any order → drag tiles into fixed template slots.

### Implications for TetraTile

- A `TetraTileLayoutGMS2_47` Resource is straightforward — codify the slot order.
- A `TetraTileLayoutGMS2_16` Resource ditto.
- Tilesetter's GMS2 export (`.yy`) produces atlases in this exact convention; the two ecosystems are compatible at the atlas level.

---

## 8. Aseprite

**Source confidence:** MEDIUM-HIGH — Aseprite docs cover tilemap modes; Aseprite has no native autotiling.

### What Aseprite v1.3+ provides

Aseprite added native tilemap support in v1.3. A tilemap layer references tiles by index from a tileset. Each pixel in the tilemap is a 32-bit value: index + flip bits + diagonal-flip bit.

**Three tileset modes** (all about how new pixels become tiles):

- **Manual Mode** (`Space+1`) — modifications change tile content without re-ordering or adding tiles.
- **Auto Mode** (`Space+2`, default) — drawing creates new tiles or reuses existing ones; unused tiles are erased.
- **Stack Mode** (`Space+3`) — every modification creates a new tile, preserving previous versions.

These modes govern **tileset bookkeeping during pixel-art editing**, not autotile placement on a map. Aseprite tilemaps require manual placement; there is no neighbor-aware tile selection.

### Autotiling status

There is no native autotile feature. Community feature requests exist (multiple linked forum threads). Workarounds:

- Hand-paint the canonical 47 (or 16) blob layout in Aseprite, export the atlas, use it as a regular blob tileset in another tool.
- Community Aseprite scripts (e.g., `tilemap_scripts_aseprite`, `lotovik/tile47-autotiling`) auto-generate the 47-tile blob from a small set of source tiles using Aseprite's scripting API.

### Export

Aseprite exports tilemaps to JSON/XML/text. Exporting tilesets as plain PNG atlases works; the standard atlas conventions (47-blob, 16-Wang) can be authored in Aseprite by hand.

### Classification

- **Layout-only?** N/A — Aseprite has no autotile semantics. It's an atlas authoring tool.
- **Mask system:** N/A.
- **Authoring step:** paint atlas in whatever convention the target engine wants (often blob-47 done by hand, or via a community script).

### Implications for TetraTile

- Aseprite is upstream of TetraTile, not an autotile peer.
- A user authoring in Aseprite would output a blob-47 or Wang-16 PNG; TetraTile consumes it via the matching `TetraTileLayoutBlob47` or `TetraTileLayoutWang16` Resource.
- No "Aseprite layout" needed.

---

## 9. PyxelEdit

**Source confidence:** MEDIUM — PyxelEdit features page + community RPG Maker workflow tutorials.

### What PyxelEdit provides

A pixel-art tool with explicit tileset support: it auto-detects unique tiles in imported images and lets the user rearrange/edit them. It exports tilemaps to XML/JSON/plain text.

The `.pyxel` file is a zipped collection of PNGs + a JSON metadata file.

### Autotile support

**No native autotile feature.** PyxelEdit is widely used to create RPG Maker autotiles by hand: the user creates a 4×4-tile canvas at 24×24-tile size (the RPGM quarter granularity), paints the quarters, and exports a PNG that conforms to the A1/A2 template.

There is no other autotile convention support; PyxelEdit doesn't compose tiles or apply rules.

### Classification

- **Layout-only?** Indirect — PyxelEdit doesn't define a layout, but is most commonly used to author the **RPG Maker A2 template layout**. So a TetraTile RPGM resource indirectly handles PyxelEdit output.
- **Mask system:** None of its own; the user is targeting RPG Maker's subtile composition.
- **Authoring step:** paint within RPG Maker template structure → export PNG.

### Implications for TetraTile

- Same as RPG Maker: support PyxelEdit by supporting RPG Maker A2 (subtile composition) — both deferred behind a baking utility.

---

## 10. Pixaki

**Source confidence:** LOW-MEDIUM — Pixaki's docs focus on pixel-art features generally; tileset-specific autotile features are not documented.

### What Pixaki provides

iPad pixel-art tool with grid overlay (toggleable, useful for tile alignment), symmetry tools (mirror axis), and adjustments. Aimed at pixel art creation rather than tileset workflow specifically.

### Autotile support

**HONEST GAP:** I could not find evidence of any autotile or tileset-rule feature in Pixaki. The grid overlay helps with manual tile alignment but does not generate or compose tiles automatically.

### Classification

- **Layout-only?** N/A.
- **Mask system:** N/A.
- **Authoring step:** paint atlas manually, no autotile integration.

### Implications for TetraTile

- Like Aseprite, Pixaki is upstream of any autotile system. Output is a plain PNG; consumers attach whatever layout Resource matches the chosen convention.
- No specific Pixaki support is needed.

---

## Cross-Cutting Synthesis

### Two-axis classification of editors

```
                Layout-only (atlas slot = semantics)
                          │
      Tilesetter ─────────┼───── GameMaker
        (Wang/Blob)       │      (16/47 templates)
                          │
                   RPG Maker A2/A4
                  (subtile composition)
                          │
   ──────────────────────────────────────── Mask/composition complexity
                          │
        Aseprite          │     Tiled Wang Sets
        Pixaki            │     Godot Terrains
        PyxelEdit         │     LDtk Auto-Layers
        (no autotile)     │     Unity Rule Tile
                          │     (rule-based)
                Free atlas + metadata
```

### Layout-only candidates (low effort to support)

These can become `TetraTileLayoutXxx` Resources with deterministic slot mappings:

1. **Tilesetter Wang 16-tile** — well-defined, common.
2. **Tilesetter Blob 47-tile** — well-defined, very common, same convention as GameMaker 47.
3. **GameMaker 16-tile auto-tile template** — slot order documented in community references.
4. **GameMaker 47-tile auto-tile template** — same convention as Tilesetter Blob.
5. **Boris-the-Brave standard 47-tile blob** — community-canonical reference.

The 47-blob convention is *the* de facto standard for layout-only blob atlases. Multiple tools (Tilesetter, GameMaker, community generators like `itsjavi/autotiler`, `Enichan/blobator`) produce compatible outputs.

### Subtile-composition candidates (medium effort, baker required)

6. **RPG Maker A2** — common, but requires a quarter-sample compositor.
7. **RPG Maker A4** (walls) — same compositor with a different lookup table.
8. **RPG Maker A1** (animated) — A2 + animation frames; requires Godot animation tie-in.

### Rule-based, deferred (high effort, out of scope for v0.2)

9. **Tiled Wang Sets / Terrain Sets** — needs `.tsx` parser to extract wangids.
10. **LDtk Auto-Layers** — needs `.ldtk` JSON parser + rule-evaluation runtime.
11. **Unity Rule Tile** — needs `.asset` ScriptableObject parser + rule translator.
12. **Godot stock terrain** — already supported by Godot itself; outside TetraTile's value-add.

### Recommended TetraTile Resource library (v0.2 scope decision)

**Ship in v0.2:**

- `TetraTileLayoutHorizontal4` — current 4×1 contract (already shipped).
- `TetraTileLayoutVertical4` — current 1×4 contract (already shipped).
- `TetraTileLayoutBlob47` — the universal 47-blob convention (= Tilesetter Blob = GameMaker 47 = community standard).
- `TetraTileLayoutWang16` — the universal 16-edge convention (= Tilesetter Wang = GameMaker 16 — needs verification that Tilesetter's slot order matches GameMaker's).

These four cover the majority of the layout-only ecosystem in one design pass.

**Defer to v0.3+ (TetraBake-shaped baking utility):**

- RPG Maker A2/A4 (subtile composition baker).
- A1 animated water (after A2 lands).

**Out of scope indefinitely (file-format imports):**

- Tiled `.tsx` import.
- LDtk `.ldtk` import.
- Unity Rule Tile `.asset` import.

### README documentation note

The README will need a "Supported Layouts" section listing each `TetraTileLayoutXxx` Resource with:
- Tile count
- Atlas dimensions (e.g., "7×8 with 9 unused slots" for blob-47)
- Source convention name (Tilesetter / GameMaker / community blob)
- Example diagram showing slot assignments
- A one-line workflow description ("Author in Tilesetter → export PNG → drop into Godot → attach this Resource")

The 47-blob slot-order diagram is the most important — it's the de facto standard and the one with least ambiguity to verify.

---

## Confidence Assessment Per Editor

| Editor | Confidence | Notes |
|---|---|---|
| Tiled | HIGH | TMX format reference + scripting API + DeepWiki internals all consulted |
| LDtk | HIGH | Official docs + Bevy LDtk Rust schema (mirrors JSON) |
| Tilesetter | MEDIUM-HIGH | Output formats and tile counts well-documented; exact 47-blob slot mapping not verified |
| Unity Rule Tile | MEDIUM | Doc page light on storage details, but core mechanics clear |
| RPG Maker | HIGH | Official MZ asset standards + tileset-format-specs GitHub repo |
| Godot | HIGH | Official docs (cross-reference only) |
| GameMaker | HIGH | Official manual + multiple community tutorials |
| Aseprite | MEDIUM-HIGH | Tilemap docs + clear "no autotile" status from issue tracker |
| PyxelEdit | MEDIUM | Features page + RPGM workflow tutorials |
| Pixaki | LOW-MEDIUM | No autotile-specific docs found |

---

## HONEST GAPS

1. **Tilesetter 47-blob exact slot mapping.** The `Generate Tileset` produces a 7×8 packed atlas with 47 used + ~9 unused slots, but the precise slot-by-slot order (which mask value lands in which (col, row)) is not published in Tilesetter's docs. Empirical verification needed (paint a known fingerprint and observe).

2. **GameMaker 47-tile vs Tilesetter 47-tile slot equivalence.** Both use the 47-blob convention, but I did not verify the exact slot orderings match. Tilesetter exports `.yy` files for GMS2 with auto-tiling pre-configured, which strongly implies compatibility — but verification is warranted before claiming a single Resource covers both.

3. **LDtk Quick Rules templates.** The 1.2.0 devlog confirms a "rules assistant" exists with sample tile layouts that auto-generate rules, but the specific layout templates (is there a 47-blob preset? a 16-Wang preset?) are not documented in pages I could access.

4. **Pixaki autotile capabilities.** Could not confirm presence or absence of any tileset-specific autotile feature; documentation focuses on general pixel-art tools.

5. **Tiled Wang painting algorithm edge cases.** The DeepWiki source describes `transitionPenalty()` and `wangIdProbability()` at high level, but the exact penalty function and how mixed-set ties resolve are undocumented in the sources accessed. Not material to layout-only research, but would matter for any future Tiled importer.

---

## Sources

### Tiled
- [TMX Map Format — Tiled stable docs](https://doc.mapeditor.org/en/stable/reference/tmx-map-format/)
- [TMX Map Format reference (GitHub source)](https://github.com/mapeditor/tiled/blob/master/docs/reference/tmx-map-format.rst)
- [Using Terrains — Tiled stable docs](https://doc.mapeditor.org/en/stable/manual/terrain/)
- [WangSet scripting API class](https://www.mapeditor.org/docs/scripting/classes/WangSet.html)
- [Wang Brush and Terrain Filling — DeepWiki on tiled](https://deepwiki.com/mapeditor/tiled/6.4-wang-brush-and-terrain-filling)
- [More Wang Tiling Improvements devlog](https://thorbjorn.itch.io/tiled/devlog/180838/more-wang-tiling-improvements)

### LDtk
- [Auto Layers — LDtk docs](https://ldtk.io/docs/general/auto-layers/)
- [Rules — LDtk docs](https://ldtk.io/docs/general/auto-layers/auto-layer-rules/)
- [LDtk JSON format index](https://ldtk.io/json/)
- [AutoLayerRuleDefinition (Bevy LDtk Rust mirror of JSON schema)](https://docs.rs/bevy_ecs_ldtk/latest/bevy_ecs_ldtk/ldtk/struct.AutoLayerRuleDefinition.html)
- [LDtk 1.2.0 release devlog](https://deepnight.itch.io/ldtk/devlog/471310/ldtk-120-is-out-happy-new-year)

### Tilesetter
- [Tilesetter docs index](https://www.tilesetter.org/docs/)
- [Generating Tilesets](https://www.tilesetter.org/docs/generating_tilesets)
- [Tileset Behavior](https://www.tilesetter.org/docs/tileset_behavior)
- [Tiles and Sources](https://www.tilesetter.org/docs/tiles_and_sources)
- [Working with Tiles](https://www.tilesetter.org/docs/working_with_tiles)
- [Exporting](https://www.tilesetter.org/docs/exporting)

### Unity 2D Tilemap Extras
- [2D Tilemap Extras package docs](http://docs.unity3d.com/Packages/com.unity.2d.tilemap.extras@latest/)
- [Rule Tile reference](https://docs.unity3d.com/Packages/com.unity.2d.tilemap.extras@4.0/manual/RuleTile.html)

### RPG Maker MV/MZ
- [Asset Standards — RPG Maker MZ official help](https://rpgmakerofficial.com/product/MZ_help-en/01_11_01.html)
- [tileset-format-specs / rpg-maker-mv-mz / autotiles.md](https://github.com/yxbh/tileset-format-specs/blob/main/formats/rpg-maker-mv-mz/specs/autotiles.md)
- [Classic Tutorial: How Autotiles Work — RPG Maker blog](https://www.rpgmakerweb.com/blog/classic-tutorial-how-autotiles-work)
- [The Power to Bring Light: Autotiles - Formats and Algorithms](https://thepowertobringlight.blogspot.com/2016/11/autotiles-formats-and-algorithms.html)

### GameMaker Studio 2
- [Auto Tiles — GameMaker manual](https://manual.gamemaker.io/lts/en/The_Asset_Editors/Tile_Set_Editors/Auto_Tiles.htm)
- [How To Use The Tile Set Editor In GameMaker](https://gamemaker.io/en/tutorials/tile-set-editor)
- [GMS2 Impressions: Tilesets and AutoTiling — csanyk.com](https://csanyk.com/2016/12/gms2-impressions-tilesets-autotiling/)
- [GMS2-Autotile-Converter README](https://github.com/null-sharp/GMS2-Autotile-Converter/blob/master/README.md)

### Aseprite
- [Aseprite Tilemap docs](https://www.aseprite.org/docs/tilemap/)
- [Auto Tiling community thread](https://community.aseprite.org/t/auto-tiling-auto-tile/25539)

### PyxelEdit
- [PyxelEdit features page](https://pyxeledit.com/features.php)
- [Making RPG Maker AutoTiles in Pyxel Edit (forum tutorial)](https://forums.rpgmakerweb.com/index.php?threads/making-rpg-maker-autotiles-in-pyxel-edit.73309/)

### Pixaki
- [Pixaki adjustments / grid docs](https://pixaki.com/user-guide/adjustments/)

### Godot 4 (cross-reference)
- [Using TileSets — Godot stable docs](https://docs.godotengine.org/en/stable/tutorials/2d/using_tilesets.html)
- [TileSetAtlasSource — Godot API](https://docs.godotengine.org/en/stable/classes/class_tilesetatlassource.html)

### Tileset theory and classification
- [Classification of Tilesets — BorisTheBrave](https://www.boristhebrave.com/2021/11/14/classification-of-tilesets/)
- [Wang Blob Tileset reference — BorisTheBrave](http://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/blob.html)
- [Autotiling Technique — Excalibur.js](https://excaliburjs.com/blog/Autotiling%20Technique/)
- [Wang 'Blob' Tileset — OpenGameArt](https://opengameart.org/content/wang-%E2%80%98blob%E2%80%99-tileset)
- [Bitmask Autotiling: 47-Tile Reference — Jaconir](https://jaconir.online/blogs/bitmask-autotile-guide)

### Cross-tool conversion / community tools
- [itsjavi/autotiler — 47-tile blob generator with Godot export](https://github.com/itsjavi/autotiler)
- [Enichan/blobator — blob tileset utility](https://github.com/Enichan/blobator)
- [Tilesetter to GMS2 converter — Nikles](https://ts2gms2.nikles.it/)
