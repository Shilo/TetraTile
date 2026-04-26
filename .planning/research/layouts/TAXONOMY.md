---
title: Autotiling Layout Taxonomy
project: TetraTile v0.2.x — Layout Library Milestone
researched: 2026-04-25
researcher: layouts-1
mode: ecosystem
overall_confidence: HIGH on top-tier layouts (tetra, dual-grid 16, blob/47, marching squares, RPG Maker A2/A4); MEDIUM on Godot-4 terrain mode internals (Match Sides) and platformer top-cap conventions; LOW on a few historical layouts (CR31's 3-edge / 3-corner / 4-order, Tilesetter's per-edge "Sources").
primary_disambiguation_source: BorisTheBrave, "Classification of Tilesets" (2021-11-14) — https://www.boristhebrave.com/2021/11/14/classification-of-tilesets/
quality_gate:
  layouts_documented: 18
  every_layout_has_mask_system: true
  every_layout_has_tile_count: true
  rpg_maker_subtile_explained: true
  boris_used_as_primary_disambiguator: true
  honest_unknowns_flagged: true
---

# Autotiling Layout Taxonomy

> One purpose: enumerate every standard autotiling atlas layout that exists in the 2D tile-art ecosystem, in enough detail that the v0.2 architectural decision ("can `_update_cells()` dispatch across all of these via a polymorphic Resource, or do we need per-layout pipelines?") can be made on evidence rather than vibes.
>
> If a researcher finds this document is missing a layout you encountered in the wild, ADD IT — do not patch over the gap silently. The "Open Questions" section at the bottom is the place to flag known gaps.

## Reading Guide

For every layout this document captures, in order:

1. **Names & aliases** — canonical name + alternate names you'll see in different communities.
2. **Mask system** — what bit-level signal the layout consumes (4-bit corner, 4-bit edge, 8-bit Moore, subtile composition).
3. **Tile count** — minimum unique tiles required, with vs without rotation reuse.
4. **Atlas arrangement** — how tiles are laid out in the source image (rows × cols, ordering).
5. **Where it's used** — engines/editors/asset packs that adopt the layout.
6. **Strengths / weaknesses** — when to pick it.
7. **Reference image URL** — public-domain or community-standard reference where one exists.

A scan-friendly summary table sits at the bottom under "Mask System Summary."

## Vocabulary Sanity Check (the Single Biggest Source of Confusion)

The terms **Wang**, **blob**, **dual-grid**, and **marching squares** are routinely conflated across blog posts, forum threads, and asset packs. BorisTheBrave's "Classification of Tilesets" formalises a 4-axis code (Cell type · Tile-feature identification · Symmetry · Restrictions) that disambiguates them definitively. Internalize this disambiguation before writing any per-layout consumer:

| Common term | Boris's formal code | Real meaning |
|---|---|---|
| **Marching Squares** | `S-V2` | 4-bit *vertex* (corner) mask. 16 tiles total. Tile sits at the intersection of 4 vertex states. |
| **Wang tiles (2-edge)** | `S-E2` | 4-bit *edge* mask. 16 tiles total. Tile is identified by the colors on its 4 edges. |
| **Wang tiles (2-corner)** | `S-V2` again | Mathematically identical to Marching Squares. The "Wang corner" name is a video-game-community usage; the math is the same as marching squares. |
| **Blob (47-tile)** | `S-V2E2-Blob` with corner-gating restriction | 8-bit *Moore* mask (4 edges + 4 corners). Naively 256 states, reduced to 47 by the rule "a corner only matters if both adjacent edges are filled." |
| **Dual-grid** | `S-V2` realised on a half-tile-offset display layer | Marching squares in a different costume. The display tilemap is offset by half a tile so each display tile reads 4 logic-cell vertices. Tile count: 16 (or 6 with rotation, or 5 + 1 transparent). |
| **Tetra (this addon, v0.1)** | `S-V2` realised with rotation-symmetry-and-2-layer composition | Marching squares with rotational symmetry reducing 16 → 4 archetypes + a 2-layer composition trick for the diagonals. |

**The rule of thumb:** if someone says "Wang tiles" without qualifying *2-edge* or *2-corner*, ask. Most modern uses of "Wang" in indie game dev mean 2-corner — which is identical to marching squares.

Source: [BorisTheBrave: Classification of Tilesets (2021)](https://www.boristhebrave.com/2021/11/14/classification-of-tilesets/) · [BorisTheBrave: Tileset Roundup (2013)](https://www.boristhebrave.com/2013/07/14/tileset-roundup/) · [CR31 Stagecast: Wang Tiles intro](https://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/intro.html)

---

## Layout 1 — Tetra (this addon)

**Aliases:** TetraTile, "4-tile dual-grid", "minimal corner-mask set."

**Mask system:** 4-bit corner mask (TL=1, TR=2, BL=4, BR=8) → 16 states. Identical input to marching squares; the difference is the *atlas* and the rotation-reuse strategy.

**Tile count:**
- **4 unique tiles** authored by user (Fill, Inner Corner, Border, Outer Corner)
- Plus 2-layer composition for the disconnected-diagonal masks 6 and 9 (one outer corner on the primary visual layer, one on the overlay layer).
- Effective coverage of all 16 corner states via Godot's `TRANSFORM_FLIP_H | TRANSFORM_FLIP_V | TRANSFORM_TRANSPOSE` flags.

**Atlas arrangement:**
- **Horizontal:** 4×1 strip. Order: Fill (mask 15), Inner Corner (one missing diagonal, e.g. mask 14), Border (one missing edge, e.g. mask 12), Outer Corner (only-one-on, e.g. mask 8).
- **Vertical:** 1×4 strip with the same ordering.
- Order is canonical and exposed via the `atlas_layout` enum (`HORIZONTAL` / `VERTICAL`).

**Where it's used:**
- TetraTile addon (this project), Godot 4.6.
- The 4-tile reduction is also documented as the BorisTheBrave "marching squares with rotation" reduction (which gives 6 tiles; tetra further reduces to 4 by treating "border" as one archetype with transforms applying to all four edge orientations and using the 2-layer overlay for the ambiguous diagonals).
- Comparable in spirit to the "5-tile dual-grid AutoTiler" Godot Asset Library entry (#4183) which exposes 5 tiles + transparent.

**Strengths:**
- Smallest authoring surface in any documented system. Artists draw four tiles total.
- Trivial onramp: 4×1 strip is a one-line atlas.
- Composes cleanly with Godot's native `TileSetAtlasSource` alternates for variation.

**Weaknesses:**
- Bakes 90° rotation symmetry into the atlas — a tile authored as "border" is the same tile rotated 4 ways. Breaks down the moment art demands directional asymmetry (top tiles, gravity-aware grass caps, isometric perspective).
- The 2-layer composition for masks 6/9 is unique to this addon. Other systems express those states with a fully-authored tile (blob/47) or treat them as visual artifacts (dual-grid 16).
- No multi-terrain story.

**Reference image:** `addons/tetra_tile/tetra_tile_template.png` (in this repo).

**Confidence:** HIGH — this is the source-of-truth code in the addon.

---

## Layout 2 — Dual-Grid 16 (Marching Squares on offset grid)

**Aliases:** "16-tile dual-grid", "TileMapDual full set", "jess-hammer's dual-grid", "Wang 2-corner on a dual grid", "marching-squares dual-grid."

**Mask system:** 4-bit corner mask sampled from the *logic* tilemap. Display tilemap is offset by half a tile in both axes so each display cell sits at the intersection of four logic cells. Each display tile reads `(NW, NE, SW, SE)` from the logic layer.

**Bit convention seen most often:** NW=1, NE=2, SW=4, SE=8 (matches BorisTheBrave's marching squares reference) — though jess-hammer's reference impl and TileMapDual each pick their own ordering. Convention is **not** standardized across the ecosystem; every implementation enumerates its own 16-row table.

**Tile count:**
- **16 fully-authored tiles** (no rotation assumed).
- Reduces to **6 tiles** with rotational symmetry per BorisTheBrave's marching squares reduction.
- Reduces further to **5 tiles + 1 transparent (= 6 total)** in Excalibur.js's variant: Filled, Edge, Inner Corner, Outer Corner, Opposite Corners (the diagonal). Transparent for the all-empty case.
- TileMapDual's README claims "**15 tiles** (yes fifteen!)" — this is 16 minus the all-empty state which is just transparent and not authored. Counting convention difference, not a real reduction.

**Atlas arrangement:**
- 4×4 canonical block (mask 0..15 reading left-to-right, top-to-bottom). Most clean.
- 16×1 strip (mask 0..15 in a single row) — alternative; allows mask-as-column-offset lookup.
- TileMapDual ships preset templates per grid type (square, isometric, hex vertical, hex horizontal). Square preset is essentially a 4×4 with transparent at index 0.

**Where it's used:**
- **TileMapDual** (Godot, pablogila) — direct competitor to TetraTile. Verified mask system, claims "only 15 tiles needed."
- **jess-hammer/dual-grid-tilemap-system-godot** (Godot 4.4 C# reference impl) — "set of 16 hard-coded rules… maximum of only 16 tiles required (you could cut that number down to 6 if your tiles have symmetry)."
- **Excalibur.js Dual Tilemap Autotiling Technique** — JS/web, the 5-tile + transparent variant.
- **5-Tile Dual-Grid AutoTiler** (Godot Asset Library #4183).
- Generic **Marching Squares** literature (e.g. BorisTheBrave's Sylves docs, Wikipedia). The dual-grid trick is "marching squares painted on an offset display layer."
- Numerous itch.io / OpenGameArt asset packs distributed as "16-tile dual-grid" or "minimal cornermask" templates.

**Strengths:**
- Half the authoring of blob/47 with comparable visual quality once corners gate properly.
- The half-tile offset trick produces "perfectly rounded corners" because every pixel of every tile sits at a known mask-state boundary.
- Conceptually clean for programmers — 4 corner bits, 16 entries, done.
- The 5/6-tile reduction is by far the most popular hand-author target.

**Weaknesses:**
- Visual layer is offset by half a tile, which can confuse collision authoring and Z-sort logic if not handled.
- "Disconnected diagonals" (masks 6 and 9 in TL/TR/BL/BR convention) are visually ambiguous: do you draw two outer corners meeting at a point, or a single weird diamond? Different implementations choose differently. (TetraTile composes with two layers; TileMapDual draws a dedicated diagonal tile.)
- 16 rules to enumerate; one bug in the lookup table corrupts every diagonal in the game.

**Reference image:**
- jess-hammer's reference: https://github.com/jess-hammer/dual-grid-tilemap-system-godot (README has the canonical 4×4 image)
- TileMapDual templates: https://github.com/pablogila/TileMapDual (sample tilesets in `examples/`)
- BorisTheBrave Sylves docs marching squares page: https://www.boristhebrave.com/docs/sylves/1/articles/tutorials/marching_squares.html

**Confidence:** HIGH — multiple independent reference implementations confirm the contract.

---

## Layout 3 — Marching Squares (16-tile, single-grid)

**Aliases:** "Vertex-mask 4-bit", "S-V2" (Boris notation), "binary vertex tileset."

**Mask system:** 4-bit *corner* (vertex) mask. Identical input to dual-grid 16, but the tile is *not* offset; it sits on the same grid as the logic and reads its own four corners.

**Bit convention (BorisTheBrave Sylves):**
- DownRight (BR) = bit 0 (value 1)
- UpRight (TR) = bit 1 (value 2)
- UpLeft (TL) = bit 2 (value 4)
- DownLeft (BL) = bit 3 (value 8)

**Bit convention (Excalibur.js):** TL=1, TR=2, BL=4, BR=8 — different! Ordering is per-implementation.

**Tile count:**
- **16 unique tiles** in full set.
- **6 tiles** with rotation reuse (BorisTheBrave's standard marching-squares-with-rotation reduction).
- Same options as dual-grid 16 since they consume the same mask.

**Atlas arrangement:**
- 4×4 grid is most common; 16×1 strip seen in some templates.
- No firmly canonical order — each implementation enumerates its own table.

**Where it's used:**
- Tiled editor (was the original "terrain" feature; now subsumed by Wang sets).
- tIDE editor.
- BorisTheBrave's reference articles use it as the entry-level autotiling explanation.
- Many Unity Rule Tile setups (the simplest pattern).

**Strengths:**
- Simplest possible autotiling formula: `index = TL + 2*TR + 4*BL + 8*BR`.
- 16 tiles is a small enough authoring set for solo devs.

**Weaknesses:**
- "Indirect influence" — placing a corner-painted tile changes 4 surrounding cells. Painting workflow is unfamiliar.
- No inner-corner concept distinct from blob's inner corner; visual results look blockier.
- Not used in modern engine native APIs (Godot 4 dropped 2x2 mode; Tiled deprecated terrain in favor of Wang sets).

**Reference image:** https://www.boristhebrave.com/docs/sylves/1/articles/tutorials/marching_squares.html (Sylves docs, standard marching-squares 16-tile illustration).

**Confidence:** HIGH.

---

## Layout 4 — Blob / 47-tile

**Aliases:** "Blob-47", "Wang Blob", "Brigador / Boris-the-Brave 47-tile", "8-neighbor blob", "S-V2E2-Blob" (Boris formal code), "Wang 2-edge 2-corner reduced", "3x3 full bitmask reduced", "47-tile Wang blob."

**Mask system:** 8-bit Moore-neighborhood mask (4 edges N/S/E/W + 4 corners NE/SE/SW/NW). Naively 2⁸ = 256 states. Reduced to **47 visually-meaningful** states by the *corner-gating rule*: "a corner only counts if both adjacent edges are filled." If either edge is empty, the corner is treated as not-filled regardless of its actual state, because that corner can never visibly meet anything.

**Bit conventions seen in the wild (THIS IS WHERE BUGS LIVE):**

| Source | TL | T | TR | L | R | BL | B | BR |
|---|---|---|---|---|---|---|---|---|
| **CR31 Stagecast (Boris mirror)** | 128 (NW) | 1 (N) | 2 (NE) | 64 (W) | 4 (E) | 32 (SW) | 16 (S) | 8 (SE) |
| **jaconir.online / Excalibur.js** | 1 | 2 | 4 | 8 | — | 32 | 64 | 128 |
| **Enichan/blobator** | 1 | 2 | 4 | — | 8 | 64 | 32 | 16 |

CR31's convention reads bits clockwise from N (N=1, NE=2, E=4, SE=8, S=16, SW=32, W=64, NW=128). The popular indie / Excalibur convention reads row-major top-to-bottom, left-to-right (TL=1, T=2, TR=4, L=8, R=16, BL=32, B=64, BR=128). Both are used roughly equally. **Always verify the bit map against the implementation, not against a generic "blob 47" reference.**

**Tile count:**
- **47** unique tiles minimum (the canonical reduction).
- Some implementations ship **48** = 47 + transparent/empty.
- Without the corner-gating rule, you'd need 256 — not done in practice.
- With rotation: BorisTheBrave reports the 47 set reduces by symmetry but the asymmetric tiles (e.g. T-shape variants) prevent collapsing to as few as marching squares does — still ~12-15 unique shapes.

**Atlas arrangement:**
- **CR31 / BorisTheBrave canonical pack:** 6×8 array with 1 duplicate of tile 255 (= the fully-filled tile painted twice to fill the rectangle), or 7×7 with 3 copies of tile 0 (transparent). Discovered by exhaustive computer search to be the minimal rectangular packings.
- **Excalibur.js / jaconir convention:** 12×4 = 48 frames. Frame 0 = empty/transparent, Frame 1 = solid, Frame 2..47 = configurations from "missing NW corner" through "isolated." Ordering is most-connected-to-least-connected.
- **Tiled "47-tile Wang Blob" helper layout:** Inherits the bjorn/tiled #1873 ordering — distinct from above.
- **GameMaker Studio 2 native:** A specific 47-tile arrangement matching the GMS2 Tile Set editor's template; OpenGameArt has `gms_47autotile_template.png` matching this. Distinct from CR31 / Excalibur.
- **Godot 3 "3x3 full bitmask"** mode: Authored peering bits per tile in any arrangement; engine builds the lookup at edit time. The user does not commit to one order.

**Where it's used:**
- Tilesetter — 47-tile Blob Sets are the default platformer/sidescroller export.
- GameMaker Studio 2 — native 47-tile auto-tile template.
- Tiled — 47-tile Wang Blob (issue #1873 helper request, eventually integrated).
- Godot 3 (legacy, "3x3" full bitmask).
- Aurora Studios "Blobator" tool — generates 47-tile blob templates from sub-blob (20-tile) or micro-blob (13-tile) inputs.
- Brigador (game; Boris-the-Brave shipped this engine).
- Hundreds of itch.io asset packs distributed as "47-tile blob template" or "3x3 minimal 47-tile."

**Strengths:**
- Most flexible single-grid autotiling. Every Moore neighborhood configuration that produces a visually distinct result has a tile.
- Industry standard for modern indie pixel-art platformers and top-down RPGs.
- Strong tooling support across editors.

**Weaknesses:**
- 47 tiles is a serious authoring commitment. Even pros use templates.
- Bit-numbering disagreements between implementations are a perennial source of bugs.
- No multi-terrain story (only handles 2-state: solid vs empty).
- The corner-gating rule is non-obvious and breaks if your art has an "L-shape" with edge-but-not-corner connectivity.

**Reference image URLs:**
- CR31 / BorisTheBrave: https://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/blob.html
- jaconir.online: https://jaconir.online/blogs/bitmask-autotile-guide
- OpenGameArt CC0: https://opengameart.org/content/basic-47-tile-autotile-template
- OpenGameArt GMS2: https://opengameart.org/content/gamemaker-autotile-templates (`gms_47autotile_template.png`)

**Confidence:** HIGH on existence and mask system. MEDIUM on which convention "wins" — the answer is ecosystem-dependent.

---

## Layout 5 — Sub-Blob (20-tile quarter-tile)

**Aliases:** "20-tile sub-blob", "RPG Maker A2 ground autotile" (BorisTheBrave's term), "quarter-tile blob with composition", "subtile blob."

**Mask system:** Each FULL tile is composed of 4 quarter-tile (24×24 px in RPG Maker) subtiles. Each subtile reads the 3 cells *adjacent or diagonal* to its quadrant of the parent cell. So the upper-left subtile reads (current cell, top neighbor, left neighbor, top-left neighbor) = 4 cells × 1 bit each = 4 states, but constrained: 5 valid subtile shapes per quadrant.

**Subtile shape enumeration (per quadrant):** Inner curve, Outer curve, Horizontal divide, Vertical divide, Solid. (5 shapes × 4 quadrants = 20 unique 24×24 subtiles.)

**Tile count:**
- **20 subtiles** + 1 empty for full coverage.
- When precomposed at edit-time into the full 47-tile blob, you get the 47-tile blob from 20 subtiles.

**Atlas arrangement:**
- Subtiles laid out in a small grid; precise arrangement varies by tool. Tilesetter, TileGen, and Blobator all consume sub-blob inputs and emit 47-tile composed outputs.
- The RPG Maker A2 atlas-of-record is a 768×576 PNG with a 16×12 grid of 48-px tiles, where each "auto-tile" is a 6-cell block (display tile + 4 subtiles + corner tiles). See Layout 13 for the full A2 layout.

**Where it's used:**
- RPG Maker VX / VX Ace / MV / MZ for the ground (A2) and ceiling (A4 ceiling) auto-tiles.
- Blobator (intermediate format).
- Tilesetter and TileGen (intermediate format).

**Strengths:**
- Fewer tiles to author than 47-tile blob.
- Composition is mathematically elegant (quarter-tile state machine).
- Battle-tested by RPG Maker for ~20 years.

**Weaknesses:**
- Subtile composition implies you are *drawing on the subgrid*, not the cell grid. Half-tile rendering throughout. Affects collision authoring.
- No diagonal-state ambiguity, but you give up some artistic flexibility (e.g. you cannot draw a corner that doesn't match the algorithm's expectations).
- Output looks "RPG-Maker-style" by default — recognizable visual signature.

**Reference image:** [BorisTheBrave's quarter-tile autotiling article](https://www.boristhebrave.com/2023/05/31/quarter-tile-autotiling/) explains the 20-tile reduction with diagrams.

**Confidence:** HIGH on mechanics. MEDIUM on exact subtile pixel layout (varies by tool).

---

## Layout 6 — Micro-Blob (13-tile quarter-tile)

**Aliases:** "13-tile micro-blob", "13-tile sub-blob", "ultra-reduced quarter-tile."

**Mask system:** Same quarter-tile composition as sub-blob, but exploits rotational symmetry across quadrants to deduplicate identical-shape subtiles. Inner curve top-left = outer curve bottom-right rotated 180°, etc.

**Tile count:**
- **13 subtiles** + 1 empty.
- Same quarter-tile composition expanded into 47-tile blob at runtime/edit-time.

**Atlas arrangement:**
- Tool-specific. Blobator's 13-tile micro-blob input has its own layout.

**Where it's used:**
- Blobator (https://github.com/Enichan/blobator) — accepts micro-blob input.
- BorisTheBrave noted in 2013 "no one is really using this tileset at the moment." Status today: still rare, but mentioned in modern auto-tiler tools as an extreme-reduction option.
- Unclear whether any shipped game uses micro-blob natively.

**Strengths:**
- Smallest documented authoring set for full blob coverage — 13 subtiles total.

**Weaknesses:**
- Requires runtime/edit-time rotation per subtile. Rotation in tilemap rendering has performance and pixel-snap costs.
- Even more visual signature lock-in than sub-blob.

**Reference image:** Blobator README diagrams.

**Confidence:** MEDIUM — exists in tooling, rarely used in finished games.

---

## Layout 7 — Wang 2-Edge

**Aliases:** "Wang edge tiles", "S-E2" (Boris notation), "Wang path tiles", "Wang 2-color edge."

**Mask system:** 4-bit *edge* mask (N/S/E/W). Each edge of a tile has one of 2 colors (binary). The tile is identified by the 4-bit pattern of its 4 edges.

**Bit convention (CR31 standard):** N=1, E=2, S=4, W=8.

**Tile count:**
- **16 unique tiles** for full set (2⁴ combinations).
- With rotational symmetry: ~6 unique shapes (paths-and-corners, comparable to marching squares with rotation).

**Atlas arrangement:**
- CR31 canonical: 4×4 grid in NESW-bit-order. Tiles arranged with matching edges and "blue" (background) borders.
- Tiled editor stores Wang sets with this convention as the underlying data; the visual atlas is whatever the artist chose. The layout convention is in the bitmask metadata, not the image.

**Where it's used:**
- Tiled editor — Wang Edge sets, used for roads, fences, paths, platforms.
- CR31 Stagecast tutorials (the definitive 2-edge reference).
- Wang's original mathematical paper (texture-synthesis literature).
- Path/road generators for procedural maps.

**Strengths:**
- Handles "linear connector" use cases (roads, fences) more cleanly than corner-mask systems.
- Conceptually intuitive for path-style art.
- Native to Tiled.

**Weaknesses:**
- Cannot represent terrain "blobs" naturally — each edge affects one neighbor only, so cohesive landmass shapes look wrong.
- Most asset packs labeled "Wang" are actually 2-corner (= marching squares), causing terminology confusion.

**Reference image:**
- CR31 / Boris mirror: https://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/2edge.html
- Tiled docs: https://doc.mapeditor.org/en/stable/manual/terrain/

**Confidence:** HIGH on concept. MEDIUM on canonical atlas (artist-chosen).

---

## Layout 8 — Wang 2-Corner

**Aliases:** "Wang corner tiles", "S-V2" (same code as marching squares!), "2-corner Wang", "corner-matched Wang."

**Mask system:** 4-bit *corner* mask (NE/SE/SW/NW). Each corner of a tile has one of 2 colors (binary). **Mathematically identical to marching squares** — just expressed in cardinal-corner notation rather than TL/TR/BL/BR.

**Bit convention (CR31 / dev.to/joestrout):** NE=1, SE=2, SW=4, NW=8. Note this is rotated 45° from typical marching-squares bit numbering.

**Tile count:**
- **16 tiles** for full set.
- 6 with rotation reuse (same as marching squares).

**Atlas arrangement:**
- CR31 canonical: 4×4 grid in NE/SE/SW/NW-bit-order.
- Tilesetter's "Wang Sets" use this — 16 tiles, typically arranged as 4×4 or 1×16 strip.

**Where it's used:**
- Tiled editor — Wang Corner sets, used for terrain transitions (grass-on-dirt, etc.).
- Tilesetter — "Wang Set" export = 16 tiles in 2-corner format.
- Most "Wang-tile generators" you find on GitHub default to 2-corner.
- Wangscape (https://github.com/Wangscape/Wangscape) — procedural Wang tile texture generation, multi-color corner Wang.

**Strengths:**
- Fewer tiles than blob/47 with similar terrain expressiveness when limited to 2 terrain types.
- Native to Tiled and Tilesetter — first-class authoring support.
- "An edge only affects one adjacent tile, while matching a corner affects three adjacent tiles" — cohesive terrain patches.

**Weaknesses:**
- Identical to marching squares but called by a different name; this terminology divergence is a recurring confusion.
- No inner-corner authoring — terrain transitions look blockier than 47-blob.

**Reference image:**
- CR31 / Boris mirror: https://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/2corn.html
- Tiled docs Wang sets: https://doc.mapeditor.org/en/stable/manual/terrain/

**Confidence:** HIGH.

---

## Layout 9 — Wang Multi-Color Corner (3-terrain, 4-terrain, …)

**Aliases:** "3-terrain Wang", "Wang N-corner", "multi-terrain corner Wang", "Tilesetter Wang 3-terrain", "S-VN" (Boris generalization).

**Mask system:** 4-bit-per-corner generalised to log₂(N) bits per corner, where N is the number of terrain types. Each corner stores which terrain occupies it.

**Tile count:**
- For N terrains: N⁴ tiles. So 3 terrains → 81 tiles, 4 terrains → 256 tiles.
- Tilesetter and Wangscape support up to 3-terrain natively (81 tiles) as a usability sweet spot.
- 4-terrain (256 tiles) is rare — usually decomposed into multiple pairwise-2-terrain layers instead.

**Atlas arrangement:**
- Tilesetter: arrangement matches "Wang 3-terrain templates from TilePipe2" — see TileBitTools docs.
- Wangscape: arbitrary; the tool computes corner colorings and emits arbitrary-grid output.

**Where it's used:**
- Tilesetter (3-terrain export) — compatibility with TileBitTools "Wang 3-terrain templates."
- Wangscape — texture-synthesis-style procedural Wang tile generation.
- Wang's original tile-set theory (multi-color edges or corners are the general case).

**Strengths:**
- True multi-terrain transitions in one atlas — grass / sand / water all in one tileset.
- Aligns with how artists think about layered terrain.

**Weaknesses:**
- Tile count explodes with terrain count (N⁴).
- Most engines don't support multi-terrain natively at the autotile level — Godot's terrain peering bits attempt it but require N-terrain × 16 peering combinations per terrain to be authored.
- Out of scope for TetraTile per project constraints (no multi-terrain story).

**Reference image:** Tilesetter docs has 3-terrain examples — https://www.tilesetter.org/docs/generating_tilesets

**Confidence:** MEDIUM — well-documented but heterogeneous tooling.

---

## Layout 10 — Tiled "Wang Sets" (Edge / Corner / Mixed)

**Aliases:** "Tiled Wang sets", "Mixed Wang", "Tiled Terrain (legacy name pre-1.5)."

**Mask system:** Tiled editor's first-class concept. Three subtypes:
- **Edge type:** 4-bit edge mask (N/S/E/W).
- **Corner type:** 4-bit corner mask (NE/SE/SW/NW).
- **Mixed type:** 8-bit mask (4 edges + 4 corners) = effectively the blob/47 mask before reduction.

**Tile count:**
- Edge type: 16 (binary) up to N⁴ (multi-color).
- Corner type: 16 up to N⁴.
- Mixed type: up to 256 (binary) or N⁸ (multi-color), with the same "47-tile reduction" possible via corner-gating.

**Atlas arrangement:**
- No fixed atlas. Tiled stores Wang IDs *per tile* as metadata in the TSX/TMX files. Artists can lay out the atlas however they like; the metadata maps tile-position → wang-id-tuple.
- Wang IDs are an 8-tuple of color indices in the order: top, top-right, right, bottom-right, bottom, bottom-left, left, top-left (Tiled 1.5+ syntax).

**Where it's used:**
- Tiled Map Editor — first-class authoring tool, the "Wang Brush" auto-selects matching tiles.
- TMX/TSX format — well-documented standard, multiple game engines consume Tiled output.

**Strengths:**
- Decouples the atlas from the mask. Artists arrange tiles freely.
- Multi-terrain native (Wang colors = terrain types).
- First-class editing with automatic match-selection brush.

**Weaknesses:**
- Game engines must implement Wang-set lookup; not all do.
- "Mixed" type is a 8-bit mask — same complexity as blob/47, less name recognition.
- Authoring metadata-per-tile is fiddly compared to a fixed-atlas template.

**Reference image:** https://doc.mapeditor.org/en/stable/manual/terrain/

**Confidence:** HIGH on Tiled's authoring model. MEDIUM on real-world adoption (depends on engine).

---

## Layout 11 — Godot 4 Terrain: "Match Corners and Sides"

**Aliases:** "MCS terrain mode", "Godot 4 full terrain mode", "Godot 3.x equivalent: 3×3 full bitmask."

**Mask system:** 8-bit Moore-neighborhood mask, but expressed as **peering bits** rather than a packed integer. A tile authors 8 peering bits (one per neighbor cardinal/corner direction) plus 1 center bit (= the tile's own terrain). Engine matches when *every* peering bit matches its neighbor's own terrain.

**Tile count:**
- **Up to 256 tiles** for full coverage of 8-bit binary mask.
- The 47-tile blob reduction applies — a 2-terrain MCS atlas needs 47 unique tiles minimum.
- Multi-terrain explodes by N⁸; impractical above 2 terrains except via category fallbacks.

**Atlas arrangement:**
- No fixed atlas. Tiles are authored with peering-bit metadata in the TileSet inspector. Engine builds lookup at TileSet load.
- Templates from TileBitTools and TilePipe2 ship "256-tile Corners and Sides" arrangements as a starting grid.

**Where it's used:**
- Godot 4.x stable (4.0 through 4.6) — first-class autotiling mode.
- Better Terrain (Portponky) — alternative terrain system that wraps the MCS concept with a more flexible matching algorithm.
- Terrain Autotiler (dandeliondino) — refined matching for Godot 4.

**Strengths:**
- Native to Godot 4. No addon required for basic autotiling.
- Peering-bits-per-tile authoring is more flexible than a fixed atlas template.

**Weaknesses:**
- Engine matching algorithm is non-deterministic when ties occur (per Godot proposal #7670). Same input can produce different output.
- Painting workflow is "set tile, engine modifies neighbors" — confusing for users coming from corner-painting.
- Documented as "the 3×3 mode" in 3→4 migration guides, but isn't *exactly* the same — see issue #79411 for documentation mismatch.

**Reference image:** TileBitTools templates — https://godotassetlibrary.com/asset/KPoNSj/tilebittools

**Confidence:** HIGH on existence and usage. MEDIUM on exact mask semantics (engine-internal; documentation gaps acknowledged in #79411).

---

## Layout 12 — Godot 4 Terrain: "Match Corners"

**Aliases:** "MC terrain mode", "Godot 4 corner-only terrain", "Godot 3.x equivalent: 2×2 bitmask (officially)."

**Mask system:** 4-bit corner peering. Tile authors 4 corner peering bits (NE/SE/SW/NW). Engine matches when corner peering bits match the corresponding cell-corner terrain.

**Tile count:**
- **Up to 16 unique tiles** per terrain pair.
- Identical mask topology to marching squares / 2-corner Wang.

**Atlas arrangement:**
- No fixed atlas. Per-tile peering-bit metadata.
- TileBitTools ships a 2×2 / 16-tile template as reference.

**Where it's used:**
- Godot 4 (stable through 4.6).
- Better Terrain's "Match Vertices" mode is Portponky's wrapper around the same concept.

**Strengths:**
- Equivalent to Wang 2-corner / marching squares — proven mask system.
- Native, fewer tiles to author.

**Weaknesses:**
- Issue #87929: "Match Corners can't draw a minimal path; should probably paint corners not centers" — UX gripe on this mode.
- Documentation (per #79411) calls this "2×2 equivalent" but the actual painting algorithm differs from 3.x 2×2.

**Reference image:** TileBitTools 2×2 template.

**Confidence:** HIGH on mask system. MEDIUM on engine-implementation details.

---

## Layout 13 — Godot 4 Terrain: "Match Sides"

**Aliases:** "MS terrain mode", "Godot 4 edge-only terrain", "Godot 3.x equivalent: 3×3 minimal (officially)."

**Mask system:** 4-bit edge peering. Tile authors 4 edge peering bits (N/S/E/W). Engine matches when edge peering bits match neighbor's own terrain.

**Tile count:**
- **Up to 16 unique tiles** per terrain pair.
- Identical mask topology to Wang 2-edge.

**Atlas arrangement:**
- Per-tile peering-bit metadata. No fixed atlas.

**Where it's used:**
- Godot 4 (stable through 4.6).

**Strengths:**
- Equivalent to Wang 2-edge — well-understood mask.
- Smallest authoring footprint of the three Godot 4 terrain modes.

**Weaknesses:**
- Issue #79411 explicitly disputes the documentation claim that "Match Sides corresponds to the previous 2×2 bitmap mode." Reporter argues it's a "completely new mode without ANY documentation whatsoever." There IS a real ambiguity about whether MS is 4-edge or something else internally.
- Best-fit/path-style use cases compete with MC for similar art.

**Reference image:** TileBitTools 3×3 minimal template (intended equivalent).

**Confidence:** MEDIUM — official docs and bug reports contradict on the precise mask semantics.

---

## Layout 14 — RPG Maker A1 (Animated Auto-Tiles)

**Aliases:** "A1 water/lava autotiles", "RPG Maker animated ground autotile", "A1 sub-blob with animation."

**Mask system:** Same quarter-tile sub-blob composition as Layout 5 (sub-blob), but each tile has 3 animation frames cycled side-by-side.

**Tile count:**
- **20 subtiles × 3 animation frames = 60 quarter-tile pieces** per autotile entry.
- A1 atlas holds multiple autotile entries (typically 4 water + 4 deep water + lava configurations).

**Atlas arrangement:**
- 768 × 576 px, 16 × 12 grid of 48-px tiles.
- Each autotile occupies a 6-tile-by-3-frame block: 3 horizontal frames × 6-tile (display + 4 corners + 1 reference) layout per frame.
- Frames cycle: animation = visual swap, no logic change.

**Where it's used:**
- RPG Maker MV / MZ (and equivalent in older XP / VX / VX Ace formats with different pixel scales).

**Strengths:**
- First-class animation support — water/lava without per-tile script.
- Battle-tested for ~20 years.

**Weaknesses:**
- Hard-coded 48-px tile size in MV/MZ.
- Sub-blob composition baked into engine.
- Out of scope for TetraTile (no animation requirement, no 48×48 hard size).

**Reference image:** RPG Maker official asset standards: https://rpgmakerofficial.com/product/MZ_help-en/01_11_01.html

**Confidence:** HIGH on existence. MEDIUM on TetraTile relevance (animation is out of scope).

---

## Layout 15 — RPG Maker A2 (Ground Auto-Tiles)

**Aliases:** "A2 ground autotile", "A2 floors", "A2 sub-blob (no animation)", "RPG Maker quarter-tile ground."

**Mask system:** Pure quarter-tile sub-blob (Layout 5) without animation.

**Tile count:**
- **20 subtiles** per autotile entry.
- Atlas holds multiple ground autotile entries (typically 8 per A2 file).

**Atlas arrangement:**
- 768 × 576 px, 16 × 12 grid of 48-px tiles in MV/MZ.
- Each autotile entry occupies a 6-tile block (display + 4 corner subtile composition + 1 reference) within a 4-tile-wide × 3-tile-tall layout.
- Subtile pixel positions within the 48×48 are fixed:
  - **Red** position (top-left 24×24) = always upper-left subtile.
  - **Green** position (top-right 24×24) = always upper-right subtile.
  - **Yellow** position (bottom-left 24×24) = always lower-left subtile.
  - **Blue** position (bottom-right 24×24) = always lower-right subtile.

**Where it's used:**
- RPG Maker XP (and older), VX, VX Ace, MV, MZ — A2 is in every version.
- One of the most-distributed autotile formats in the indie game world due to RPG Maker's reach.

**Strengths:**
- Familiar to thousands of RPG-Maker-trained artists.
- Smaller atlas than 47-tile blob.
- The quarter-tile structure is mathematically clean.

**Weaknesses:**
- Tightly coupled to 48×48 px convention (or the older 32×32 in XP).
- Subtile composition complicates non-RPG-Maker engines: you cannot just "paste the atlas in" — you must implement the composition logic.
- Visual signature locks games to a recognizable RPG-Maker look unless heavily reskinned.

**Reference image:** Invenblocker's RPG Maker MV templates (Tumblr): https://www.tumblr.com/l-conversion-fangame/162069029225 — A1/A2/A3/A4/A5 reference templates.

**Confidence:** HIGH.

---

## Layout 16 — RPG Maker A3 (Building / Wall Auto-Tiles)

**Aliases:** "A3 walls", "A3 buildings", "A3 wall autotile", "RPG Maker structural tiles."

**Mask system:** Different from A2's quarter-tile sub-blob. A3 uses 2×2-tile-block patterns that repeat for taller buildings. Each "wall" is a 2-tile-wide × 3-tile-tall set with:
- Top row: roof edges
- Middle rows: wall sides (repeats vertically for tall buildings)
- Bottom row: foundation
Each row's left/right tiles handle horizontal connectivity to adjacent wall blocks.

**Tile count:**
- **6 tiles per wall set** (2 × 3 grid). Walls repeat vertically by stretching the middle rows. Multiple wall sets per A3 file.
- Whole-tile authoring; no subtile composition like A2.

**Atlas arrangement:**
- 768 × 384 px, 16 × 8 grid of 48-px tiles in MV/MZ.
- 8 wall sets (2-wide × 3-tall) arranged in a 16×8 grid → 16 horizontal wall sets per row, 4 rows of wall sets per file (wait — 16/2 = 8 columns of sets × 8/3 rows ≈ ~21 sets, depending on row remainder).
- Specific arrangement varies; user templates on Tumblr / RPGMaker forums document the exact grid.

**Where it's used:**
- RPG Maker MV / MZ. Also XP / VX / VX Ace with different pixel sizes.

**Strengths:**
- Tall buildings author cleanly with vertical-stretch logic.
- Whole-tile authoring is simpler than A2's quarter-tile.

**Weaknesses:**
- Different mask-system from A2 — supporting both A2 and A3 in one autotiler doubles the codepaths.
- Tightly coupled to RPG Maker's 48×48 grid.

**Reference image:** Invenblocker's templates (above link).

**Confidence:** MEDIUM — confirmed structure but exact tile-set count per A3 file varies by docs.

---

## Layout 17 — RPG Maker A4 (Roofs + Walls)

**Aliases:** "A4 roof+wall combined", "A4 mixed autotile."

**Mask system:** Mixed. Top half of each A4 entry is a quarter-tile sub-blob like A2 (for roofs). Bottom half is whole-tile-block like A3 (for walls beneath the roof).

**Tile count:**
- 10 tiles per combined roof+wall set (per RPG Maker docs; the breakdown is roof = 6 sub-blob tiles + wall = 4-tile column).
- Multiple sets per file.

**Atlas arrangement:**
- 768 × 720 px, 16 × 15 grid of 48-px tiles in MV/MZ.
- Specific arrangement varies; documented in invenblocker's templates.

**Where it's used:**
- RPG Maker MV / MZ.

**Strengths:**
- One file handles both roofs and the walls beneath them — convenient for buildings that are usually drawn together.

**Weaknesses:**
- Combines two different mask systems in one file. To support A4 in a third-party autotiler, you implement BOTH A2-style and A3-style logic. This is the hardest RPG Maker format to support.

**Reference image:** Invenblocker's templates.

**Confidence:** MEDIUM — combined-format details require implementation against actual A4 files.

---

## Layout 18 — RPG Maker A5 (Normal Tiles, No Auto-Tiling)

**Aliases:** "A5 props", "A5 normal tiles", "A5 non-autotile."

**Mask system:** **None.** A5 tiles are placed 1:1 without any neighbor-aware behavior. Included for completeness because it's part of the RPG Maker A1-A5 pentad.

**Tile count:** Up to 128 tiles per A5 file (16 × 8 grid).

**Atlas arrangement:** 384 × 768 px, 16 × 8 grid of 48-px tiles in MV/MZ. Some rows are by convention treated as "floor" (1:1) and some as "wall" (with corner subdivisions, mimicking A4 logic). The mixed convention is documented but engine-enforced inconsistently.

**Where it's used:** RPG Maker MV / MZ; equivalent in older formats.

**Strengths:** Simple drop-in.

**Weaknesses:** Not actually an autotile format. Including it means "support normal tiles without autotiling," which TetraTile already does (the user can place a non-fill tile via standard `set_cell`).

**Reference image:** Invenblocker's templates.

**Confidence:** HIGH — A5 is by definition the "no autotile" case.

---

## Layout 19 — Platformer Top-Cap (Grass-on-Dirt)

**Aliases:** "platformer grass cap", "directional top tile", "asymmetric top edge", "9-slice platformer tileset", "top-tile pattern."

**Mask system:** Conceptually a 4-bit corner mask (like marching squares), but with a *vertical asymmetry* — the "up" direction is special. Tiles know whether they are on top of solid terrain (grass cap, snow cap) versus inside or below.

**Tile count:** Varies; common conventions:
- **9-slice (3×3) grid** = 9 tiles: TL corner cap, T cap, TR corner cap, L side, fill, R side, BL corner, B side, BR corner. Authors a "block" of solid terrain bordered by caps.
- **47-tile blob with directional grass** — same as Layout 4 but the artist paints the top-edge tiles with grass and the bottom-edge tiles with rock/dirt. The mask doesn't change; the *art convention* does.
- **Layered approach**: separate grass-layer tilemap on top of dirt-layer tilemap. No special mask required, but tile alignment is a concern.

**Atlas arrangement:** 3×3 standard, sometimes extended with slope tiles (3×3 + 4 slopes = 13). 47-blob with grass uses standard blob layout.

**Where it's used:**
- Platformer-game asset packs on Itch.io, OpenGameArt — most popular pattern by far for sidescrollers.
- Cave Story (referenced via Cave Story tribute site).
- Mapledev's "How to Design a Platformer Tileset" tutorial — 9-slice corner system is the canonical reference.
- Kenney's pico-8 platformer pack (used in TetraTile's demo!) — this is exactly why TetraTile needs top-tile support.

**Strengths:**
- Visually familiar — every platformer player recognizes "grass on top, dirt below" instantly.
- 9 tiles is small.
- Composes with marching-squares / dual-grid for the inner-fill region.

**Weaknesses:**
- Breaks pure rotation symmetry — TR ≠ TL flipped, because the top has grass.
- Requires a "which way is up" convention baked into the autotiler. TetraTile v0.1's rotation reuse fights this directly.
- No standard mask system — the grass-on-dirt pattern is an art convention overlaid on whatever mask system the engine uses.

**Reference image:** https://www.tumblr.com/mapledev/10406905135/howtotileset

**Confidence:** MEDIUM — concept is universally recognized but each artist authors their own variant.

---

## Layout 20 — Top-Down RPG 4-Direction Symmetric

**Aliases:** "top-down 4-direction tileset", "symmetric all-axes tileset", "RPG flat tileset."

**Mask system:** Either marching-squares 16-tile or blob 47-tile, but with the explicit assumption of *full 4-axis rotational + mirror symmetry*. No "up is special" axis.

**Tile count:** Whatever the underlying mask is (16 or 47), with maximum rotation/mirror reuse possible. Tetra is the extreme reduction.

**Atlas arrangement:** Standard for the underlying mask system.

**Where it's used:**
- Top-down RPGs: Stardew Valley, Zelda, classic JRPGs.
- All RPG Maker A2 floor tiles assume this symmetry.
- Most "top-down RPG asset pack" entries on Itch.io / CraftPix.

**Strengths:**
- Maximum tile reuse via transforms.
- TetraTile v0.1 is optimized for this case.
- Compatible with any underlying mask system.

**Weaknesses:**
- Not really a separate "layout" — it's a *constraint* that lets you pick a smaller mask system. Listing it here for completeness because community refers to it as if it were a distinct layout.
- Breaks if any tile has directional art (water flow, light source).

**Confidence:** HIGH on concept, but it's an axis of variation rather than a distinct layout.

---

## Layout 21 — Godot 3.x "3×3 Minimal" Bitmask (47 tiles)

**Aliases:** "Godot 3 3×3 minimal", "G3 47-tile autotile", "3×3 reduced bitmask."

**Mask system:** 8-bit Moore-mask peering bits per tile, with the corner-gating reduction baked into the engine algorithm. Effectively the 47-tile blob expressed as Godot 3.x peering metadata.

**Tile count:** 47 fully-authored tiles (with the engine internally building the mask-state-to-tile lookup from peering bits).

**Atlas arrangement:** No fixed atlas; per-tile peering bits. Templates exist (HeartoLazor/autotile_generator, GATT, ShatteredReality's "3x3 Minimal Autotile TileSet Generator" Asset Library #1056).

**Where it's used:**
- Godot 3.x (legacy) — was THE autotile mode for the engine 3.0 → 3.6.
- Godot 4 dropped this in favor of "Match Corners and Sides" terrain mode.
- Many Godot 3 asset packs in this format still exist on Itch.io.

**Strengths:**
- Godot 3 native; no addon required.
- Battle-tested for 5+ years.

**Weaknesses:**
- Migration to Godot 4 was famously broken (issue #71188).
- Per-tile peering-bit authoring is fiddly.

**Reference image:** GATT or HeartoLazor's autotile_generator templates.

**Confidence:** HIGH (well-documented legacy).

---

## Layout 22 — Godot 3.x "3×3 Full" Bitmask (256 / 47)

**Aliases:** "Godot 3 3×3 full", "G3 full bitmask", "full Moore peering."

**Mask system:** 8-bit Moore mask without corner-gating. Naively 256 states; in practice user authors 47 unique tiles + "ignore" bits to map multiple states to one tile.

**Tile count:** Up to 256, typically 47 with skip/ignore bits.

**Atlas arrangement:** Per-tile peering bits.

**Where it's used:** Godot 3.x (legacy).

**Strengths:** Most flexible Godot 3 mode.

**Weaknesses:** Same as 3×3 minimal; harder to set up.

**Confidence:** HIGH.

---

## Layout 23 — Godot 3.x "2×2" Bitmask (16 tiles)

**Aliases:** "Godot 3 2×2", "G3 corner bitmask."

**Mask system:** 4-bit corner peering. Equivalent to Wang 2-corner / marching squares.

**Tile count:** 16.

**Atlas arrangement:** Per-tile peering bits, typically a 4×4 atlas.

**Where it's used:** Godot 3.x (legacy).

**Strengths:** Simplest Godot 3 mode.

**Weaknesses:** Replaced by "Match Corners" in Godot 4 with a different (officially-disputed) mask semantics.

**Confidence:** HIGH.

---

## Layout 24 — Brigador-Style Quarter-Tile (sub-blob composed)

**Aliases:** "Brigador autotile", "BorisTheBrave's marching-squares-with-quarter-tile-composition."

**Mask system:** Marching squares with each cell precomposed at edit-time from quarter-tile pieces. Conceptually a sub-blob (Layout 5) but only authored for the 16-state corner mask, not the 47-state blob.

**Tile count:** Same as sub-blob (20 subtiles), but you only generate the 16 marching-squares outputs not the 47 blob outputs.

**Atlas arrangement:** Tool-specific (Tilesetter, TileGen).

**Where it's used:**
- Brigador (game shipped by Stellar Jockeys / Hugh Monahan with engine work by Boris-the-Brave).
- TileGen tool.

**Strengths:** Smallest authoring set for marching-squares output.

**Weaknesses:** Subtile composition cost.

**Confidence:** MEDIUM — well-documented in BorisTheBrave's articles but rarely seen by name in the wild.

---

## Mask System Summary Table

The single most load-bearing question for the v0.2.x layout-library architecture is "what mask shape does each layout consume?" because that determines whether one `_update_cells()` pipeline can serve all of them.

| Layout | Mask shape | Bits | States | States after reduction | Tiles min | Tiles w/ rotation | Subtile? | Atlas fixed? |
|---|---|---|---|---|---|---|---|---|
| 1. Tetra (this addon) | 4-bit corner | 4 | 16 | 16 | 4 + 2-layer composition | 4 | No | Yes (4×1 / 1×4) |
| 2. Dual-grid 16 | 4-bit corner (offset) | 4 | 16 | 16 | 16 | 6 | No | No (4×4 typical) |
| 3. Marching squares | 4-bit corner | 4 | 16 | 16 | 16 | 6 | No | No (4×4 typical) |
| 4. Blob / 47-tile | 8-bit Moore | 8 | 256 | 47 | 47 | ~12-15 | No | Yes (CR31 / GMS2 / Tilesetter variants) |
| 5. Sub-blob | quarter-tile composition | n/a | 47 | 47 | 20 subtiles | n/a | Yes | Tool-specific |
| 6. Micro-blob | quarter-tile w/ rotation | n/a | 47 | 47 | 13 subtiles | n/a | Yes | Tool-specific |
| 7. Wang 2-edge | 4-bit edge | 4 | 16 | 16 | 16 | 6 | No | No (per-tile) |
| 8. Wang 2-corner | 4-bit corner | 4 | 16 | 16 | 16 | 6 | No | No (per-tile) |
| 9. Wang multi-color corner | log₂N-bit/corner | 4·log₂N | N⁴ | N⁴ | N⁴ | varies | No | No |
| 10. Tiled Wang sets | 4-bit edge / 4-bit corner / 8-bit | 4 or 8 | up to 256 | up to 47 | up to 47 | varies | No | No |
| 11. Godot 4 MCS | 8-bit peering | 8 | up to 256 | up to 47 (per terrain pair) | up to 47 | varies | No | No |
| 12. Godot 4 MC | 4-bit corner peering | 4 | 16 | 16 | up to 16 | up to 6 | No | No |
| 13. Godot 4 MS | 4-bit edge peering (disputed) | 4 | 16 | 16 | up to 16 | up to 6 | No | No |
| 14. RPG Maker A1 | quarter-tile + animation | n/a | 47 × 3 frames | 47 × 3 | 60 quarter-tiles per autotile | n/a | Yes | Yes (768×576 16×12) |
| 15. RPG Maker A2 | quarter-tile sub-blob | n/a | 47 | 47 | 20 quarter-tiles per autotile | n/a | Yes | Yes (768×576 16×12) |
| 16. RPG Maker A3 | 2×3 wall blocks | n/a | n/a (whole-tile) | n/a | 6 tiles per wall set | n/a | No | Yes (768×384 16×8) |
| 17. RPG Maker A4 | A2 + A3 hybrid | n/a | n/a | n/a | 10 tiles per combined set | n/a | Yes (top half) | Yes (768×720 16×15) |
| 18. RPG Maker A5 | none (1:1) | 0 | n/a | n/a | n/a | n/a | No | Yes (384×768 16×8) |
| 19. Platformer top-cap | art convention over 4-bit corner | 4 | 16 | 16 | 9 (3×3) or 47 | 9 or varies | No | Yes (3×3) |
| 20. Top-down RPG 4-dir symmetric | constraint not layout | n/a | n/a | n/a | n/a | n/a | No | n/a |
| 21. Godot 3 3×3 minimal | 8-bit peering | 8 | up to 256 | 47 | up to 47 | varies | No | No |
| 22. Godot 3 3×3 full | 8-bit peering | 8 | up to 256 | up to 47 | up to 47 | varies | No | No |
| 23. Godot 3 2×2 | 4-bit corner peering | 4 | 16 | 16 | up to 16 | up to 6 | No | No |
| 24. Brigador quarter-tile | marching-squares + sub-blob | n/a | 16 | 16 | 16 quarter-tile-composed | n/a | Yes | Tool-specific |

### Mask-System Clusters

If you collapse the table by mask-system family, the architectural truth becomes clear:

**Cluster A — 4-bit corner (or its offset twin):**
Layouts 1, 2, 3, 8, 12, 19 (in its 4-bit reading), 20 (sometimes), 23.
**Same mask, different atlas/symmetry assumptions.** A polymorphic Resource-driven `_update_cells()` can serve ALL of these via "what's the atlas for state X?" lookup.

**Cluster B — 4-bit edge:**
Layouts 7, 13.
**Same mask, different atlas.** Also expressible via Resource lookup, but the bit ordering is different from Cluster A so the atlas-resolution code branches earlier (which 4 cells are sampled).

**Cluster C — 8-bit Moore (with optional corner-gating):**
Layouts 4, 10 (mixed), 11, 21, 22.
**Bigger mask, same shape across layouts.** Polymorphic Resource works, but the contract carries 47 (or up to 256) atlas slots instead of 16.

**Cluster D — Quarter-tile / subtile composition:**
Layouts 5, 6, 14, 15, 17 (top half), 24.
**Different render model.** The autotiler doesn't pick "a tile" per cell — it picks 4 quarter-tiles per cell and composes them. This is fundamentally a different `_update_cells()` pipeline from clusters A/B/C.

**Cluster E — Whole-tile non-mask layouts:**
Layouts 16 (A3 walls), 18 (A5 normal).
**Not really autotiling.** A3 has structural-block logic (multi-cell stretching) that's tangential to mask-driven autotiling. A5 is "no autotile."

**Cluster F — N-color multi-terrain:**
Layout 9.
**Mask scales with terrain count.** Out of TetraTile scope per project constraints, but architecturally fits Cluster B/C with wider per-corner/per-edge state.

### Architectural Implication

A single polymorphic `_update_cells()` Resource-dispatch pipeline can plausibly cover **Clusters A, B, and C**. That's roughly 14 of the 24 documented layouts (Tetra, Dual-grid 16, Marching squares, Wang 2-edge, Wang 2-corner, Tiled Wang sets in their corner/edge/mixed forms, Godot 4 MCS / MC / MS, Godot 3 2×2 / 3×3 minimal / 3×3 full, Platformer top-cap, Top-down RPG, Brigador). All of them are "given a mask, look up an atlas slot, transform if applicable."

**Cluster D (subtile composition) requires a different pipeline.** Quarter-tile composition draws 4 sub-tiles per cell, not 1 tile per cell. This breaks the v0.1 assumption that `_update_cells()` writes "one visual tile per logic cell." Supporting RPG Maker A2/A4 means EITHER:
- Add a precomposition step that emits a 47-tile blob from sub-blob inputs at TileSet-load time (turning Cluster D into Cluster C), OR
- Add a parallel render path that writes 4 quarter-tile cells per logic cell.

Either is significantly more code than supporting Cluster A/B/C.

**Cluster E (A3 walls, A5 normal) is out of scope** — A3 is a totally different layout concept (multi-cell building blocks), A5 is not autotiling at all.

**Cluster F (multi-terrain) is explicitly out of scope** per PROJECT.md.

This argues strongly for **two separate architectural decisions** for the milestone:
1. **v0.2 layout library = Clusters A, B, C only.** ~14 layouts covered with one pipeline. Defer subtile composition.
2. **v0.3+ subtile pipeline = Cluster D.** Treat RPG Maker A1/A2/A4 as a separate roadmap track, possibly with a precomposition utility (turn A2 → 47-blob at edit time) rather than runtime composition.

This fits the orchestrator's hint: "the count and difficulty of layouts will determine whether v0.2 absorbs all of them or splits across v0.2 + v0.3." The split runs along Cluster D's boundary.

---

## Open Questions / Honest Unknowns

These could not be pinned down with high confidence in this research pass. Phase planning should treat them as "validate before relying on."

1. **Godot 4 "Match Sides" exact mask semantics.** Issue #79411 disputes whether MS is really 4-edge or something else. Documentation contradicts reporter. Need to read engine source to verify.

2. **Canonical bit ordering for 47-tile blob.** Three different conventions (CR31, Excalibur/jaconir, Enichan). Picking one for TetraTile is a *decision*, not a *discovery*. Recommend: support all three via a `bit_layout` enum on the contract, defaulting to CR31 because that's the literature standard.

3. **Tilesetter "per-edge Sources" property.** The Tilesetter docs reference a "Sources" system for choosing per-edge atlases. Could not find a complete spec. Relevant if TetraTile wants compatibility with Tilesetter exports; not relevant for v0.2 scope.

4. **CR31's 3-edge / 3-corner / 4-order tiles.** Boris's mirror references these but the linked pages were 404 / unreachable in this research pass. Probably 81 / 81 / 256 tiles respectively (3³ and 4⁴ generalizations). Not relevant for v0.2; relevant if multi-terrain is ever scoped in.

5. **Exact RPG Maker A3 / A4 grid breakdown.** Atlas dimensions confirmed (768×384 / 768×720) but the exact tile-per-set arithmetic varies per docs. Implementing A3/A4 requires reading actual RPG Maker MV/MZ files to verify, not just blog posts.

6. **Stardew Valley / Terraria autotile internals.** Both are reportedly some flavor of blob/47 with custom variations, but neither publishes formal docs. Not relevant for TetraTile compatibility goals.

7. **Platformer top-cap convention's relationship to mask 4/8/12.** ARCHITECTURE.md flagged 4/8/12 as the "top edge" mask states. This document does not validate that against actual platformer art — must be done in Phase 4 with the Kenney pico-8 demo asset.

8. **Sub-blob exact subtile pixel layout.** "20 subtiles" is the count but the canonical pixel arrangement varies between Tilesetter, Blobator, RPG Maker, and Tilegen. Implementing Cluster D would require picking one arrangement.

9. **Tiled "Wang IDs" 8-tuple format and how engines consume it.** Tiled docs describe the metadata format but the rendering engines (Godot, Unity, custom) each implement Wang lookup differently. Compatibility with Tiled exports is layout-tooling work, not v0.2 scope.

10. **Whether "Match Sides" Godot 4 mode is genuinely useful or vestigial.** Bug tracker chatter suggests few users adopt it. If TetraTile only supports two of the three Godot 4 terrain modes, MS is the safest to skip.

---

## Sources

### Primary (HIGH confidence)
- [BorisTheBrave: Classification of Tilesets (2021)](https://www.boristhebrave.com/2021/11/14/classification-of-tilesets/) — primary disambiguation source for Wang vs blob vs marching squares.
- [BorisTheBrave: Tileset Roundup (2013)](https://www.boristhebrave.com/2013/07/14/tileset-roundup/) — original 4-method comparison (marching squares, blob, sub-blob, micro-blob).
- [BorisTheBrave: Quarter-Tile Autotiling (2023)](https://www.boristhebrave.com/2023/05/31/quarter-tile-autotiling/) — sub-blob and micro-blob mechanics.
- [BorisTheBrave Sylves docs: Marching Squares](https://www.boristhebrave.com/docs/sylves/1/articles/tutorials/marching_squares.html) — bit conventions.
- [CR31 Stagecast (Boris mirror): Wang Tiles intro](https://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/intro.html) — taxonomy of Wang variants.
- [CR31: 2-Corner Wang Tiles](https://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/2corn.html) — 16-tile corner mask.
- [CR31: Blob 47-Tile](https://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/blob.html) — canonical 47-tile reduction.
- [Tiled documentation: Using Terrains (Wang Sets)](https://doc.mapeditor.org/en/stable/manual/terrain/) — Edge / Corner / Mixed sets.
- [Godot 4.6 Using TileSets](https://docs.godotengine.org/en/4.6/tutorials/2d/using_tilesets.html) — terrain mode names (MCS / MC / MS).
- [TileMapDual GitHub (pablogila)](https://github.com/pablogila/TileMapDual) — 15-tile dual-grid claim.
- [jess-hammer/dual-grid-tilemap-system-godot](https://github.com/jess-hammer/dual-grid-tilemap-system-godot) — 16-rule reference impl.
- [Tilesetter docs: Generating Tilesets](https://www.tilesetter.org/docs/generating_tilesets) — Blob 47 + Wang 16 conventions.
- [RPG Maker MZ asset standards](https://rpgmakerofficial.com/product/MZ_help-en/01_11_01.html) — A1-A5 dimensions.

### Secondary (MEDIUM confidence)
- [Excalibur.js: Autotiling Technique](https://excaliburjs.com/blog/Autotiling%20Technique/) — bit conventions.
- [Excalibur.js: Dual Tilemap Autotiling Technique](https://excaliburjs.com/blog/Dual%20Tilemap%20Autotiling%20Technique/) — 5-tile dual-grid.
- [jaconir.online: Bitmask Autotiling 47-Tile Reference](https://jaconir.online/blogs/bitmask-autotile-guide) — alternate bit convention.
- [Enichan/blobator GitHub](https://github.com/Enichan/blobator) — micro-blob (13-tile) and sub-blob (20-tile) tooling.
- [GameMaker Studio Auto Tiles manual](https://manual.gamemaker.io/lts/en/The_Asset_Editors/Tile_Set_Editors/Auto_Tiles.htm) — GMS2 native templates.
- [TileBitTools (Godot Asset Library)](https://godotassetlibrary.com/asset/KPoNSj/tilebittools) — supports all 3 Godot 4 terrain modes + Wang + Blob templates.
- [Better Terrain GitHub (Portponky)](https://github.com/Portponky/better-terrain) — alternative Godot 4 terrain plugin.
- [Mapledev: How to Design a Platformer Tileset](https://www.tumblr.com/mapledev/10406905135/howtotileset) — 9-slice platformer convention.
- [dev.to/joestrout: Wang 2-Corner Tiles](https://dev.to/joestrout/wang-2-corner-tiles-544k) — 2-corner explanation with bit values.
- [Invenblocker RPG Maker MV templates](https://www.tumblr.com/l-conversion-fangame/162069029225) — A1-A5 reference templates (atlas pixel dimensions).
- [Robotsweater: Bot's Guide to Custom Art in RPG Maker MV (Medium)](https://robotsweater.medium.com/bots-guide-to-custom-art-in-rpgmaker-mv-understanding-tilesets-9178fe09e475) — A1-A5 specs.
- [Issue #79411 (godotengine/godot)](https://github.com/godotengine/godot/issues/79411) — "Match Sides" mode docs dispute.
- [Issue #87929 (godotengine/godot)](https://github.com/godotengine/godot/issues/87929) — "Match Corners" minimal-path issue.
- [OpenGameArt: GameMaker autotile templates](https://opengameart.org/content/gamemaker-autotile-templates) — CC0 47-tile and 16-tile GMS2 reference PNGs.
- [OpenGameArt: Basic 47-Tile Autotile Template](https://opengameart.org/content/basic-47-tile-autotile-template) — CC0 reference.

### Tertiary (LOW confidence — needs validation if relied on)
- [Tiled issue #1873: 47-tile Wang Blob helper](https://github.com/bjorn/tiled/issues/1873) — feature request, not docs.
- [Forum discussions on 3×3 minimum tile count](https://forum.godotengine.org/t/tile-placement-to-test-all-47-tiles-for-a-tileset-with-autotile-bitmask-3x3-minimum/15367) — community estimate of 27 distinct shapes.
- [PracticalMedia: Simplify Tile Creation with the Dual-Grid System](https://practicalmedia.io/article/SimplifyTileCreationwiththeDual-GridSystem) — popular-press intro.
- [HeartoLazor/autotile_generator](https://github.com/HeartoLazor/autotile_generator) — 3×3 bitmask template tool.
- [GitHub: sesopenko/gatt](https://github.com/sesopenko/gatt) — Godot Autotile Texture Templater (2×2, 3×3 minimal).
- [Wangscape](https://github.com/Wangscape/Wangscape) — multi-color Wang corner texture generation.
- [Cave Story tileset reference](https://www.cavestory.org/game-info/tilesets.php) — historical example only.

---

*Layouts taxonomy completed: 2026-04-25*
*Total layouts documented: 24 (target was ≥12)*
*Mask-system clusters identified: 6 (A-F)*
*Architectural recommendation: split v0.2 (Clusters A/B/C ≈ 14 layouts, one pipeline) from v0.3+ (Cluster D RPG Maker subtile composition, separate pipeline)*
