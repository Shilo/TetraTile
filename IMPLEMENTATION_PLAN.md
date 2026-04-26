# PentaTile MVP Implementation Plan

## Public Contract

- `PentaTileMapLayer` extends `TileMapLayer` and is the only public runtime class.
- Users paint logic cells with Godot's native TileMap tools or call normal `set_cell()`/`erase_cell()`.
- The class overrides `_update_cells(coords, forced_cleanup)` and updates managed internal visual layers.
- The atlas is strict four-tile order: Fill, Inner Corner, Border, Outer Corner.
- Horizontal atlas layout is `(0,0)..(3,0)`. Vertical layout is `(0,0)..(0,3)`.

## Dual Grid Sampling

The visual layers are offset by `-tile_set.tile_size / 2`, so visual cell `D` is centered on a logic-grid corner.

Mask bits:

| Bit | Quadrant | Logic cell sampled from visual cell `D` |
| --- | --- | --- |
| `1` | TL | `D + (-1, -1)` |
| `2` | TR | `D + (0, -1)` |
| `4` | BL | `D + (-1, 0)` |
| `8` | BR | `D + (0, 0)` |

A changed logic cell affects four display cells: `C`, `C + RIGHT`, `C + DOWN`, and `C + (1, 1)`.

## Transform Constants

Godot 4.6 atlas transform flags:

| Name | Flags |
| --- | --- |
| `ROTATE_0` | `0` |
| `ROTATE_90` | `TRANSFORM_TRANSPOSE | TRANSFORM_FLIP_H` |
| `ROTATE_180` | `TRANSFORM_FLIP_H | TRANSFORM_FLIP_V` |
| `ROTATE_270` | `TRANSFORM_TRANSPOSE | TRANSFORM_FLIP_V` |

Base tile assumptions:

- Inner corner, tile `1`: filled except top-right.
- Border, tile `2`: filled bottom half.
- Outer corner, tile `3`: filled bottom-left quadrant.

## 16-State Mapping

| Mask | Meaning | Primary visual | Overlay visual |
| --- | --- | --- | --- |
| `0` | Empty | Erase | Erase |
| `1` | TL only | Outer, `ROTATE_90` | Erase |
| `2` | TR only | Outer, `ROTATE_180` | Erase |
| `3` | Top edge | Border, `ROTATE_180` | Erase |
| `4` | BL only | Outer, `ROTATE_0` | Erase |
| `5` | Left edge | Border, `ROTATE_90` | Erase |
| `6` | TR + BL diagonal | Outer, `ROTATE_180` | Outer, `ROTATE_0` |
| `7` | Missing BR | Inner, `ROTATE_90` | Erase |
| `8` | BR only | Outer, `ROTATE_270` | Erase |
| `9` | TL + BR diagonal | Outer, `ROTATE_90` | Outer, `ROTATE_270` |
| `10` | Right edge | Border, `ROTATE_270` | Erase |
| `11` | Missing BL | Inner, `ROTATE_180` | Erase |
| `12` | Bottom edge | Border, `ROTATE_0` | Erase |
| `13` | Missing TR | Inner, `ROTATE_0` | Erase |
| `14` | Missing TL | Inner, `ROTATE_270` | Erase |
| `15` | Fill | Fill, `ROTATE_0` | Erase |

## Diagonal Bridge Decision

The diagonal bridge problem is solved by composition, not approximation. Masks `6` and `9` contain two separated occupied quadrants. Mapping either one to a border creates a false connection; mapping either one to a single outer corner drops half the terrain. The overlay layer preserves both quadrants with the original four source tiles.

This keeps the public architecture single-class. The extra layer is internal implementation detail, equivalent to a renderer pass.
