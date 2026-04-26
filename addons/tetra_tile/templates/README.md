# TetraTile Atlas Templates

Blank reference templates for every layout TetraTile supports. Open one in your art tool, paint the slots in order, save the result as your tileset image.

> Not yet implemented — this folder ships as part of the v0.2.0 milestone. The current v0.1.0 reference template lives at [`addons/tetra_tile/tetra_tile_template.png`](../tetra_tile_template.png) and will move here as `tetra_horizontal.png` when v0.2.0 lands.

For the *why* and *when to pick what*, see [`.planning/research/layouts/COMPARISON.md`](../../../.planning/research/layouts/COMPARISON.md). This file is the artist-facing reference: dimensions, slot grid, what each cell represents.

## Folder Layout

```text
addons/tetra_tile/templates/
  README.md                       # this file
  tetra_horizontal.png            # 4×1, the v0.1 default
  tetra_vertical.png              # 1×4
  dual_grid_16.png                # 4×4, 16 unique
  wang_2edge.png                  # 4×4, edge mask (NESW)
  wang_2corner.png                # 4×4, corner mask (NE/SE/SW/NW)
  blob_47_tilesetter.png          # 7×8 with 9 unused cells, Tilesetter slot order
  blob_47_excalibur.png           # 12×4 with 1 unused cell, Excalibur/jaconir slot order
```

Future (deferred to v0.3+):

```text
  sub_blob_20.png                 # 20-tile quarter-tile sub-blob
  micro_blob_13.png               # 13-tile quarter-tile micro-blob
  rpg_maker_a2.png                # 768×576 RPG Maker A2 ground
  rpg_maker_a4.png                # 768×720 RPG Maker A4 walls
```

## Tile Size Guidance

Pick a base tile size that matches your art. The blank templates ship at three reference sizes — choose the one closest to your target and scale the others up or down with nearest-neighbor:

- **8×8 px** — pixel-art platformer / topdown (matches the v0.1 demo's `tetra_tile_ground.png`)
- **16×16 px** — most common indie pixel-art size
- **32×32 px** — chunky pixel art, RPG-style topdown

Each template's *atlas dimension* in pixels is `tile_size × cols` wide by `tile_size × rows` tall. Examples below assume **16×16** unless noted.

## Naming & Color Convention

Every blank template follows the same labeling rules so they're visually consistent:

- **Background:** transparent (alpha 0)
- **Slot border:** 1-px gray rectangle at slot edges
- **Slot index:** large grey numeral centered (the *atlas slot number*, not the mask value)
- **Mask hint:** small grey text in the corner showing the mask value the slot maps to (e.g., `m=15`)
- **Diagonals (where applicable):** dashed lines indicating where adjacent logic cells are filled

This way one PNG is both reference (numbered grid) and starter (artist paints over the labels with their art).

---

## Template Specs

### `tetra_horizontal.png` — 4×1 horizontal strip

**Dimensions (16×16):** 64 × 16 px
**Slots:** 4
**Mask system:** 4-bit corner with rotation symmetry
**Use:** v0.1 default, minimal authoring.

```text
slot 0    slot 1    slot 2    slot 3
┌──────┬──────┬──────┬──────┐
│      │      │      │      │
│ Fill │ Inn. │ Bord │ Out. │
│      │ Corn │  er  │ Corn │
│ m=15 │ m=14 │ m=12 │ m=8  │
└──────┴──────┴──────┴──────┘
```

Mask coverage of remaining 12 states is via Godot `TRANSFORM_FLIP_*` rotations + the addon's overlay layer for masks 6 and 9.

### `tetra_vertical.png` — 1×4 vertical strip

**Dimensions (16×16):** 16 × 64 px
**Slots:** 4
**Mask system:** same as horizontal.
**Use:** vertical-strip variant; same tiles, different image orientation.

```text
slot 0  ┌──────┐
        │ Fill │ m=15
        ├──────┤
slot 1  │ Inn. │ m=14
        │ Corn │
        ├──────┤
slot 2  │ Bord │ m=12
        │  er  │
        ├──────┤
slot 3  │ Out. │ m=8
        │ Corn │
        └──────┘
```

### `dual_grid_16.png` — 4×4 grid

**Dimensions (16×16):** 64 × 64 px
**Slots:** 16
**Mask system:** 4-bit corner (no rotation reuse)
**Use:** asymmetric art (top tiles, hand-drawn pixel work).

```text
slot:  0    1    2    3        mask:  0   1   2   3
       4    5    6    7               4   5   6   7
       8    9    10   11              8   9   10  11
       12   13   14   15              12  13  14  15
```

Mask numbering convention TetraTile commits to (LOCKED in the layout Resource): **TL=1, TR=2, BL=4, BR=8** (matches the v0.1 mask convention in `tetra_tile_map_layer.gd`). So:

- slot 15 = all four corners filled (solid)
- slot 0 = no corners filled (this slot is unused at runtime; included for completeness — you can leave it transparent)
- slot 6 = TR + BL filled (one of the two "disconnected diagonals")
- slot 9 = TL + BR filled (the other disconnected diagonal)

### `wang_2edge.png` — 4×4 edge-mask grid

**Dimensions (16×16):** 64 × 64 px
**Slots:** 16
**Mask system:** 4-bit edge (N/S/E/W neighbors)
**Use:** roads, fences, paths, platforms — anything where the *line* of connection matters.

```text
slot:  0    1    2    3        bits:  -    N    E    NE
       4    5    6    7               S    NS   ES   NES
       8    9    10   11              W    NW   EW   NEW
       12   13   14   15              SW   NSW  ESW  all
```

Bit convention TetraTile commits to (CR31 standard): **N=1, E=2, S=4, W=8.**

### `wang_2corner.png` — 4×4 corner-mask grid

**Dimensions (16×16):** 64 × 64 px
**Slots:** 16
**Mask system:** 4-bit corner (NE/SE/SW/NW neighbors)
**Use:** terrain transitions where corner alignment matters more than edge alignment. Mathematically equivalent to Dual-Grid 16 — different name and bit numbering.

```text
slot:  0    1    2    3        bits:  -    NE   SE   NESE
       4    5    6    7               SW   NESW SESW NESESW
       8    9    10   11              NW   NENW SENW NESEnw
       12   13   14   15              SWNW ...  ...  all
```

Bit convention TetraTile commits to (CR31 standard): **NE=1, SE=2, SW=4, NW=8.**

> If you'd rather author Dual-Grid 16, use `dual_grid_16.png` — they hold the same 16 shapes, but `wang_2corner.png` numbers bits cardinally and `dual_grid_16.png` numbers them by quadrant. Pick the one whose bit names you prefer; the underlying tiles are interchangeable if you remap.

### `blob_47_tilesetter.png` — 7×8 grid, Tilesetter slot order

**Dimensions (16×16):** 112 × 128 px (7 cols × 16 px wide; 8 rows × 16 px tall)
**Slots:** 47 used + 9 unused (last 1.5 rows)
**Mask system:** 8-bit Moore (4 edges + 4 corners) with corner-gating reduction
**Use:** Tilesetter's "Blob Set" export. If you authored your atlas in Tilesetter, this is the matching template.

```text
slot:  1   2   3   4   5   6   7        masks ordered most-connected to least
       8   9   10  11  12  13  14
       15  16  17  18  19  20  21
       22  23  24  25  26  27  28
       29  30  31  32  33  34  35
       36  37  38  39  40  41  42
       43  44  45  46  47  ✗   ✗
       ✗   ✗   ✗   ✗   ✗   ✗   ✗
```

> **Slot-to-mask mapping is empirical.** The exact mapping for each of the 47 slots requires painting a fingerprint atlas in Tilesetter and observing which mask lands where. This is captured in the layout Resource's lookup table, NOT painted on the template — so the template just labels slots 1..47 and leaves "✗" cells transparent. Bit convention used by Tilesetter's Godot export: row-major top-to-bottom, left-to-right (TL=1, T=2, TR=4, L=8, R=16, BL=32, B=64, BR=128).

### `blob_47_excalibur.png` — 12×4 grid, Excalibur/jaconir slot order

**Dimensions (16×16):** 192 × 64 px
**Slots:** 47 used + 1 unused
**Mask system:** same as Tilesetter Blob 47 (8-bit Moore + corner-gating)
**Use:** Excalibur.js / jaconir convention. Common in indie web-game asset packs.

```text
slot:  0   1   2   3   4   5   6   7   8   9   10  11
       12  13  14  15  16  17  18  19  20  21  22  23
       24  25  26  27  28  29  30  31  32  33  34  35
       36  37  38  39  40  41  42  43  44  45  46  ✗
```

> **Slot-to-mask mapping** uses the [jaconir.online bitmask reference](https://jaconir.online/blogs/bitmask-autotile-guide). Same empirical-lookup-table pattern as the Tilesetter blob template.

---

## Authoring Workflow

1. **Pick a layout** by reading [COMPARISON.md](../../../.planning/research/layouts/COMPARISON.md) — find the row in the decision table that matches your use case.
2. **Open the matching template PNG** from this folder.
3. **Paint each slot** with your art. Slot numbers and mask hints are reference — replace them.
4. **Save your image** somewhere in your project (e.g. `addons/my_game/tilesets/grass.png`).
5. **In Godot**, create a `TileSet` resource with a `TileSetAtlasSource` pointing at your saved image.
6. **In your scene**, on the `TetraTileMapLayer` node:
   - Set `tile_set` to your TileSet.
   - Set `atlas_contract` to a `TetraTileAtlasContract` Resource.
   - On the contract, set `layout` to the matching `TetraTileLayoutXxx` (e.g., `TetraTileLayoutDualGrid16`).
7. **Paint** with the standard `set_cell()` API or the editor brush. TetraTile picks the right tile from your atlas based on the layout Resource's slot-to-mask mapping.

No bitmask authoring per tile. No peering bits. Drop the atlas in, attach the layout, paint.

---

## Adding Your Own Layout

Custom layouts are supported by subclassing `TetraTileLayout` and implementing `compute_mask()` + `mask_to_atlas()`. See the v0.2 architecture doc at [`.planning/research/layouts/MASK_UNIFICATION.md`](../../../.planning/research/layouts/MASK_UNIFICATION.md).

This is an experimental API — the built-in layouts in this folder are the supported surface. Custom layouts work but are user-maintained.

---

*Templates spec: 2026-04-25. Built-in layouts ship with v0.2.0; deferred layouts noted in `MASK_UNIFICATION.md`.*
