"""Simulate the 4-display-cell composition of a single painted logic cell.

When 1 logic cell is painted, 4 display cells around it each render slot 0
with one of 4 rotations (per mask 1/2/4/8). The 4 quadrants must tile into a
coherent silhouette. This script:

  1. Loads slot 0 from penta_tile_ground.png (16x16).
  2. Applies the 4 rotations (matching Godot's TRANSFORM flag combinations).
  3. Composes them at the 4 display cell positions in a 32x32 canvas.
  4. Saves the result to addons/penta_tile/tests/composed_silhouette.png
  5. Counts opacity — a coherent silhouette should be ~100% opaque in its
     16x16 inner region (the painted cell area).

Godot transform flags (from TileSetAtlasSource):
  TRANSFORM_FLIP_H    = 4096
  TRANSFORM_FLIP_V    = 8192
  TRANSFORM_TRANSPOSE = 16384

  _ROTATE_0   = 0                                 (no transform)
  _ROTATE_90  = TRANSPOSE | FLIP_H = 20480       (90° CCW)
  _ROTATE_180 = FLIP_H | FLIP_V = 12288          (180°)
  _ROTATE_270 = TRANSPOSE | FLIP_V = 24576       (90° CW)
"""

from PIL import Image, ImageDraw

SLOT_PATH = "addons/penta_tile/layouts/penta_tile_layout_penta/four_horizontal.png"
TILE = 32  # bundled preset is 32px tiles
OUT_PATH = "addons/penta_tile/tests/composed_silhouette.png"


def godot_transform(img: Image.Image, flags: int) -> Image.Image:
    """Apply Godot's TRANSFORM flags in canonical order: TRANSPOSE → FLIP_H → FLIP_V."""
    out = img.copy()
    if flags & 16384:  # TRANSPOSE
        out = out.transpose(Image.Transpose.TRANSPOSE)
    if flags & 4096:   # FLIP_H
        out = out.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    if flags & 8192:   # FLIP_V
        out = out.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    return out


def synthesize_outer_corner_piece(slot0: Image.Image) -> Image.Image:
    """Mirror of penta_tile_synthesis.gd::_synthesize_outer_corner_piece.
    Extract source TR quadrant, place at a transparent canvas's BL position.
    Source T+R perimeter wires land at synth's BL-quadrant inner edges → silhouette
    outer T+R perimeter under rotation+tiling."""
    half = TILE // 2
    canvas = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    tr = slot0.crop((half, 0, TILE, half))
    canvas.paste(tr, (0, half), tr)
    return canvas


def main() -> None:
    src = Image.open(SLOT_PATH).convert("RGBA")
    full_silhouette = src.crop((0, 0, TILE, TILE))
    # Apply synth: extract OuterCorner piece from full silhouette
    slot0 = synthesize_outer_corner_piece(full_silhouette)

    # Per the dispatcher mappings (verified by paint_test.gd):
    #   mask=4 (display at TR of painted cell)  → _ROTATE_0
    #   mask=1 (display at BR of painted cell)  → _ROTATE_90
    #   mask=2 (display at BL of painted cell)  → _ROTATE_180
    #   mask=8 (display at TL of painted cell)  → _ROTATE_270
    #
    # Mapping from mask → display position relative to painted cell:
    #   mask=8: display TL → world top-left of silhouette
    #   mask=4: display TR → world top-right
    #   mask=2: display BL → world bottom-left
    #   mask=1: display BR → world bottom-right
    #
    # Each display cell's tile-local content occupies ITS quadrant of the silhouette.
    # The display cells tile into a 32x32 area (2x2 of 16x16 cells).

    # Compose:
    canvas = Image.new("RGBA", (TILE * 2, TILE * 2), (60, 60, 60, 255))  # grey bg
    draw = ImageDraw.Draw(canvas)

    # mask=8 → _ROTATE_270 → display TL of silhouette → canvas position (0, 0)
    img_mask8 = godot_transform(slot0, 24576)
    canvas.paste(img_mask8, (0, 0), img_mask8)

    # mask=4 → _ROTATE_0 → display TR of silhouette → canvas position (TILE, 0)
    img_mask4 = godot_transform(slot0, 0)
    canvas.paste(img_mask4, (TILE, 0), img_mask4)

    # mask=2 → _ROTATE_180 → display BL of silhouette → canvas position (0, TILE)
    img_mask2 = godot_transform(slot0, 12288)
    canvas.paste(img_mask2, (0, TILE), img_mask2)

    # mask=1 → _ROTATE_90 → display BR of silhouette → canvas position (TILE, TILE)
    img_mask1 = godot_transform(slot0, 20480)
    canvas.paste(img_mask1, (TILE, TILE), img_mask1)

    canvas.save(OUT_PATH)

    # Count opacity in the inner 16x16 region (the actual painted cell silhouette area).
    # This region spans canvas pixels (TILE/2, TILE/2) to (3*TILE/2, 3*TILE/2)
    # because the display cells are offset by -tile_size/2 (dual-grid).
    inner_x0 = TILE // 2
    inner_y0 = TILE // 2
    inner_size = TILE  # 16x16 inner = the painted logic cell area
    inner = canvas.crop((inner_x0, inner_y0, inner_x0 + inner_size, inner_y0 + inner_size))

    # Count alpha-bearing (non-grey-bg) pixels in inner region. The grey bg has
    # alpha=255 too, so we test for non-bg-color pixels (any pixel different from
    # (60,60,60) is "filled silhouette content").
    bg = (60, 60, 60, 255)
    inner_pixels = inner.getdata()
    silhouette_count = sum(1 for p in inner_pixels if p != bg)
    total = inner.size[0] * inner.size[1]
    pct = 100.0 * silhouette_count / total
    print(f"composed silhouette inner-region: {silhouette_count}/{total} pixels filled ({pct:.1f}%)")
    print(f"saved to {OUT_PATH}")
    if pct < 95.0:
        print(f"WARN: inner silhouette is not nearly-fully-filled ({pct:.1f}% < 95%) — composition has gaps")


if __name__ == "__main__":
    main()
