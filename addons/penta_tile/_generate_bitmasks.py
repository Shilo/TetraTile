"""Generate greyboxed silhouette bitmask PNGs for each PentaTile layout.

Run with: python addons/penta_tile/_generate_bitmasks.py

Produces transparent-background PNGs where each slot is filled with a grey
silhouette indicating which logic-cell quadrants (corner masks) or edge
connections (edge masks) the slot represents. Slot boundaries are marked
with a 1-px dark grey outline. Artists paint over these silhouettes; the
shapes are purely a visual hint for "what does this slot need to look like."

Mask conventions LOCKED (also documented in each layout's class doc-comment):
- Penta corner masks (slots 0-4 across 1..5 modes): TL=1, TR=2, BL=4, BR=8 with
  the new slot ordering 0=IsolatedCell, 1=Fill, 2=Border, 3=InnerCorner, 4=OppositeCorners
- DualGrid16 / Wang2Corner: TL=1, TR=2, BL=4, BR=8 (corner mask, 4x4 atlas)
- Wang2Edge: CR31 N=1, E=2, S=4, W=8 (edge mask, 4x4 atlas)
- Min3x3: T=1, E=2, B=4, W=8 (edge mask, 3x3 atlas)
- Blob47Godot (Phase 3): 8-bit Moore mask (D-76) N=1, E=2, S=4, W=8, NE=16, SE=32,
  SW=64, NW=128. 7x7 atlas, 47 used cells + 2 transparent. Mask encoded by atlas
  position only — solid 32x32 silhouettes (per Phase 2 UAT bug class #5 lessons).

This script is committed alongside the generated PNGs so anyone can
regenerate / tweak the greyboxes without reverse-engineering pixel data.
"""
from PIL import Image, ImageDraw
from pathlib import Path

TILE = 32  # pixels per tile (Phase 2 doubles Phase 1's 16-px reference for finer detail)
GREY = (136, 136, 136, 255)        # #888 mid-grey fill
OUTLINE = (68, 68, 68, 255)        # #444 dark grey outline
HINT = (170, 170, 170, 255)        # #aaa light grey for the always-on center hint
TRANSPARENT = (0, 0, 0, 0)

OUT_LAYOUTS = Path(__file__).parent / "layouts"
OUT_PENTA = OUT_LAYOUTS / "penta_tile_layout_penta"

# ---- Helpers ----
# These produce 32-px tiles with `draw_slot_outline` outlining each slot in dark grey.
# `draw_corner_mask(col, row, mask)` and `draw_edge_mask(col, row, mask)` cover
# DualGrid16 / Wang2Corner (corner) + Wang2Edge / Min3x3 (edge).


def new_atlas(cols: int, rows: int) -> Image.Image:
    """Blank transparent atlas of the requested tile dimensions."""
    return Image.new("RGBA", (cols * TILE, rows * TILE), TRANSPARENT)


def draw_slot_outline(draw: ImageDraw.ImageDraw, col: int, row: int) -> None:
    """No-op. Tile boundaries are NOT outlined in the bundled greyboxes.

    Earlier revisions drew a 1-px dark perimeter around each tile to help
    artists see tile boundaries in the inspector preview. That decoration
    becomes visible cross-shaped gridlines when 4 rotated tiles meet at a
    painted cell's center under autotile rendering — adjacent cells'
    perimeter outlines stack into 2-px dark seams that break the silhouette.

    Removing the outline keeps autotile output seamless. The inspector still
    shows tile grids via Godot's stock editor overlay (TileSet edit mode);
    we don't need to bake them into the texture."""
    pass


def draw_corner_mask(draw: ImageDraw.ImageDraw, col: int, row: int, mask: int) -> None:
    """Fill quadrants of slot (col, row) per a corner mask.

    Bits: TL=1, TR=2, BL=4, BR=8.
    """
    x0, y0 = col * TILE, row * TILE
    half = TILE // 2
    # quadrant rectangles: (bit, x0, y0, x1, y1)
    quads = [
        (1, x0, y0, x0 + half - 1, y0 + half - 1),               # TL
        (2, x0 + half, y0, x0 + TILE - 1, y0 + half - 1),         # TR
        (4, x0, y0 + half, x0 + half - 1, y0 + TILE - 1),         # BL
        (8, x0 + half, y0 + half, x0 + TILE - 1, y0 + TILE - 1),  # BR
    ]
    for bit, qx0, qy0, qx1, qy1 in quads:
        if mask & bit:
            draw.rectangle((qx0, qy0, qx1, qy1), fill=GREY)


def draw_edge_mask(draw: ImageDraw.ImageDraw, col: int, row: int, mask: int) -> None:
    """Solid 32x32 silhouette per atlas slot — every edge-mask tile renders
    as a fully opaque square. The mask is encoded by atlas POSITION only.

    Background extension is suppressed at the LAYER (not the silhouette):
    penta_tile_map_layer._paint_via_layout skips non-logic-painted cells
    in single-grid layouts, so background "extension" cells (cells outside
    the painted region whose only painted neighbor is one cardinal away)
    don't get painted at all. That keeps painted regions exactly aligned
    to the user's painted cells — visually matching Penta's clean
    rectangle (Penta's perimeter display cells fill INNER quadrants that
    fall inside the painted logic bounds, so its painted region is also
    a clean rectangle with no outward extension).

    mask is unused; kept for callsite symmetry.
    """
    x0, y0 = col * TILE, row * TILE
    draw.rectangle((x0, y0, x0 + TILE - 1, y0 + TILE - 1), fill=GREY)


def draw_47_blob_silhouette(draw: ImageDraw.ImageDraw, col: int, row: int, mask: int) -> None:
    """Solid 32x32 grey silhouette per atlas slot for 47-blob layouts.

    The mask is encoded by atlas POSITION only (per the layout's
    _MASK_TO_ATLAS dict — see PentaTileLayoutBlob47Godot's 7×7 row-major
    packing). The silhouette is solid grey so single-grid rendering
    composes correctly without transparent-quadrant edge artifacts.

    Phase 2 UAT bug class #5 lessons-learned: single-grid layouts
    cannot compose partial-fill silhouettes; gen_wang_2_corner solved
    this by going solid-32×32 across all 16 slots. Same applies to
    47-blob: the mask differentiator is the atlas slot's POSITION,
    not the silhouette shape.

    mask is unused by the silhouette but kept for callsite symmetry
    (matches draw_corner_mask / draw_edge_mask conventions).
    """
    x0, y0 = col * TILE, row * TILE
    draw.rectangle((x0, y0, x0 + TILE - 1, y0 + TILE - 1), fill=GREY)


# ---- Penta archetype drawers (NEW in Phase 2; pixel coords spelled out above) ----

def draw_penta_isolated_cell(draw, col, row):
    """Slot 0 -- IsolatedCell as a single BL-quadrant outer-corner piece.

    Used in ALL Penta modes (ONE/TWO/THREE/FOUR/FIVE). Draws a 16x16 solid
    grey BL quadrant at pixels (0..15, 16..31) of the 32x32 tile; the other
    3 quadrants stay transparent.

    Why single quadrant + WHY this works for synthesis:
    - OuterCorner-via-rotation (masks 1/2/4/8 → slot 0 + ROTATE_*) places the
      BL quadrant art at each of the 4 corners of a painted cell's display
      cells (one per rotation). The 4 rotated copies compose into ONE
      coherent silhouette at the painted cell, not 4 mini-silhouettes
      around it. (Earlier revisions had slot 0 = full silhouette which
      tiled into the "4 silhouettes around the painted area" visual the
      user reported.)
    - Synthesizer composes Fill / Border / InnerCorner / OppositeCorners
      from rotated copies of this BL quadrant placed at the appropriate
      output quadrants (see PentaTileSynthesis._synthesize_slot_image).
      No more sub-rectangle stretching — every synthesized slot is built
      from the same source shape, just placed differently."""
    ox, oy = col * TILE, row * TILE
    # BL quadrant only — pixels x:0-15, y:16-31. PIL draw.rectangle endpoints
    # are inclusive on both ends, so (0, 16) → (15, 31) fills exactly 16x16.
    draw.rectangle((ox, oy + 16, ox + 15, oy + TILE - 1), fill=GREY)


def draw_penta_fill(draw, col, row):
    """Slot 1 -- Fill silhouette: solid 32x32 grey square."""
    ox, oy = col * TILE, row * TILE
    draw.rectangle((ox, oy, ox + TILE - 1, oy + TILE - 1), fill=GREY)


def draw_penta_border(draw, col, row):
    """Slot 2 -- Border silhouette: bottom-half slab (rows 16..31 filled)."""
    ox, oy = col * TILE, row * TILE
    draw.rectangle((ox, oy + 16, ox + TILE - 1, oy + TILE - 1), fill=GREY)


def draw_penta_inner_corner(draw, col, row):
    """Slot 3 -- InnerCorner silhouette: L-shape (TR quadrant cut out)."""
    ox, oy = col * TILE, row * TILE
    draw.rectangle((ox,      oy,      ox + 15,        oy + TILE - 1), fill=GREY)   # left half (TL+BL)
    draw.rectangle((ox + 16, oy + 16, ox + TILE - 1,  oy + TILE - 1), fill=GREY)   # BR quadrant


def draw_penta_opposite_corners(draw, col, row):
    """Slot 4 -- OppositeCorners silhouette: TL + BR quadrants filled (mask 9 anchor "\\")."""
    ox, oy = col * TILE, row * TILE
    draw.rectangle((ox,      oy,      ox + 15,        oy + 15),       fill=GREY)   # TL
    draw.rectangle((ox + 16, oy + 16, ox + TILE - 1,  oy + TILE - 1), fill=GREY)   # BR


# ---- Per-mode Penta strip generators ----

def gen_penta(mode: int, axis: str) -> Image.Image:
    """Generate a Penta strip for the given mode (1-5) along the given axis ('horizontal' or 'vertical').

    Mode determines tile count: ONE=1, TWO=2, THREE=3, FOUR=4, FIVE=5.
    Axis determines strip direction: 'horizontal' = N tiles in a row, 'vertical' = N tiles in a column.
    Slot indices increase along the strip.
    """
    cols, rows = (mode, 1) if axis == "horizontal" else (1, mode)
    img = new_atlas(cols, rows)
    draw = ImageDraw.Draw(img)
    archetype_drawers = [
        draw_penta_isolated_cell,    # slot 0
        draw_penta_fill,             # slot 1
        draw_penta_border,           # slot 2
        draw_penta_inner_corner,     # slot 3
        draw_penta_opposite_corners, # slot 4
    ]
    # All modes use the same single-quadrant slot 0 art. The synthesizer
    # composes Fill / Border / InnerCorner / OppositeCorners by placing
    # rotated copies of slot 0's BL quadrant at output quadrants.
    for slot in range(mode):
        col, row = (slot, 0) if axis == "horizontal" else (0, slot)
        archetype_drawers[slot](draw, col, row)
        draw_slot_outline(draw, col, row)
    return img


def gen_dual_grid_16() -> Image.Image:
    """4x4 corner-mask greybox; mask 0..15 mapped to (col, row) = (mask % 4, mask / 4).

    Uses Phase 1's draw_corner_mask UNCHANGED -- the DualGrid16 mask convention
    (TL=1, TR=2, BL=4, BR=8) and the slot positions match Phase 1 exactly.
    """
    img = new_atlas(4, 4)
    draw = ImageDraw.Draw(img)
    for mask in range(16):
        col, row = mask % 4, mask // 4
        draw_corner_mask(draw, col, row, mask)
        draw_slot_outline(draw, col, row)
    return img


def gen_wang_2_edge() -> Image.Image:
    """4x4 edge-mask greybox; same atlas layout as dual_grid_16 but with edge silhouettes.

    Uses Phase 1's draw_edge_mask UNCHANGED.
    """
    img = new_atlas(4, 4)
    draw = ImageDraw.Draw(img)
    for mask in range(16):
        col, row = mask % 4, mask // 4
        draw_edge_mask(draw, col, row, mask)
        draw_slot_outline(draw, col, row)
    return img


def gen_wang_2_corner() -> Image.Image:
    """4x4 atlas greybox for the SINGLE-GRID Wang2Corner layout.

    Wang2Corner is single-grid: each painted logic cell IS a display cell
    rendered with one fully-opaque 32x32 tile from this atlas. The corner
    mask (NE/SE/SW/NW = bits 1/2/4/8) selects WHICH of the 16 tiles the
    cell uses; the tile silhouette itself is always a solid 32x32 (the
    artist's per-tile artwork shows the corner transitions internally).

    Earlier revisions reused gen_dual_grid_16's output (partial-quadrant
    fills via draw_corner_mask). That works for DualGrid16's dual-grid
    composition (4 display cells per painted logic cell, with quadrants
    summing to a clean rectangle), but for SINGLE-GRID Wang2Corner each
    cell renders one tile alone — partial-quadrant fills leave perimeter
    cells with visible gaps where the unfilled quadrants don't connect
    to anything (UAT screenshot: alternating-square stripe along the
    painted region's outer edge).
    """
    img = new_atlas(4, 4)
    draw = ImageDraw.Draw(img)
    for col in range(4):
        for row in range(4):
            x0, y0 = col * TILE, row * TILE
            draw.rectangle((x0, y0, x0 + TILE - 1, y0 + TILE - 1), fill=GREY)
            draw_slot_outline(draw, col, row)
    return img


def gen_minimal_3x3() -> Image.Image:
    """3x3 edge-mask greybox (Min3x3-01). Each tile is a fixed silhouette per its
    position in the 3x3 grid (NW/N/NE/W/center/E/SW/S/SE).

    Uses Phase 1's draw_edge_mask UNCHANGED with mask derivation from grid position.
    """
    img = new_atlas(3, 3)
    draw = ImageDraw.Draw(img)
    # Each cell shows a silhouette matching the "open-side" rule from Wave 4 mask_to_atlas.
    for col in range(3):
        for row in range(3):
            # Open-side derivation -- matches PentaTileLayoutMinimal3x3.mask_to_atlas inverse:
            #   col 0 = open W, col 2 = open E, col 1 = neither/both
            #   row 0 = open T, row 2 = open B, row 1 = neither/both
            # Edge mask: T=1, E=2, B=4, W=8 (set bits = closed sides; unset = open sides).
            mask = 15  # start fully closed
            if col == 0: mask &= ~8           # open W
            elif col == 2: mask &= ~2          # open E
            if row == 0: mask &= ~1            # open T
            elif row == 2: mask &= ~4          # open B
            draw_edge_mask(draw, col, row, mask)
            draw_slot_outline(draw, col, row)
    return img


# 47 D-76-ordered, COLLAPSED masks reachable via _collapse_8bit_moore on
# raw input range [0, 256). Sorted ascending; mirror of _MASK_TO_ATLAS keys
# in penta_tile_layout_blob_47_godot.gd.
BLOB_47_GODOT_MASKS = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 19, 23, 27, 31,
    38, 39, 46, 47, 55, 63, 76, 77, 78, 79, 95, 110, 111, 127, 137, 139,
    141, 143, 155, 159, 175, 191, 205, 207, 223, 239, 255,
]


# ---- Phase 3.5: PixelLab cell-to-role tables ----
# Mirrors penta_tile_layout_pixel_lab_*.gd consts. Verbatim from
# tileset_transform.lua:17-26 (top-down) and :28-36 (side-scroller).
PIXELLAB_TOP_DOWN_CELL_TO_ROLE = [
    6, 6, 6, 6, 6, 6, 6, 6,
    6, 7, 9, 10, 7, 9, 10, 6,
    6, 11, 12, 8, 15, 12, 1, 6,
    6, 11, 12, 12, 13, 3, 5, 6,
    6, 2, 0, 13, 14, 9, 10, 6,
    6, 7, 4, 5, 11, 12, 1, 6,
    6, 2, 5, 12, 2, 3, 5, 6,
    6, 6, 6, 6, 6, 6, 6, 6,
]
PIXELLAB_SIDE_SCROLLER_CELL_TO_ROLE = [
    12, 12, 12, 12, 13,  3,  3,  3,
     0, 13,  3,  3, 14,  9, 10,  6,
    11,  8,  9,  9, 15, 12,  1,  6,
    11, 12, 12, 12, 12, 12,  8,  9,
     2,  3,  3,  3,  0, 12, 12, 12,
     6,  6,  6,  7, 15, 12, 12, 12,
     6,  6,  6, 11, 13,  3,  3,  3,
     6,  6,  7,  4,  5,  6,  6,  6,
]
# role index -> 4-bit corner mask (TL=1, TR=2, BL=4, BR=8). Locked by spike 003.
PIXELLAB_ROLE_TO_MASK = [4, 10, 13, 12, 9, 14, 15, 7, 2, 3, 11, 5, 0, 8, 6, 1]


def draw_pixel_lab_cell(draw: ImageDraw.ImageDraw, col: int, row: int, role: int) -> None:
    """Solid 32x32 silhouette for PixelLab atlases (D-101 option B fallback).

    Phase 3.5 Plan 04 found that option A (role-coded corner-mask silhouettes)
    failed `comprehensive_bitmask_test`'s single-grid solidity assertion: an
    isolated painted cell renders one 32x32 tile from the atlas, and partial-
    quadrant fills produced 25-75% pixel coverage instead of the required
    100%. Same UAT lesson Wang2Corner learned in Phase 2 (gen_wang_2_corner
    line 234 docstring). Single-grid layouts encode the mask via atlas
    POSITION, not via per-tile silhouette composition.

    PIXLAB layouts are single-grid (D-96), so the mask differentiator is
    "which atlas cell did first-cell pick select" — not the silhouette
    pixels. Solid 32x32 gives clean rendering across all 16 mask states,
    matching the Wang2Corner / Blob47Godot convention.

    `role` is unused but kept for callsite symmetry with other Phase 3.5
    helper signatures.
    """
    x0, y0 = col * TILE, row * TILE
    draw.rectangle((x0, y0, x0 + TILE - 1, y0 + TILE - 1), fill=GREY)


def gen_pixel_lab_top_down() -> Image.Image:
    """8x8 PixelLab top-down atlas (256x256 at TILE=32). Each cell renders
    a corner-mask silhouette derived from its role. Cells sharing a role
    are visually identical (D-101)."""
    img = new_atlas(8, 8)
    draw = ImageDraw.Draw(img)
    for row in range(8):
        for col in range(8):
            role = PIXELLAB_TOP_DOWN_CELL_TO_ROLE[row * 8 + col]
            draw_pixel_lab_cell(draw, col, row, role)
            draw_slot_outline(draw, col, row)
    return img


def gen_pixel_lab_side_scroller() -> Image.Image:
    """8x8 PixelLab side-scroller atlas (256x256 at TILE=32). Same shape as
    top-down with the side-scroller cell-to-role table (D-95)."""
    img = new_atlas(8, 8)
    draw = ImageDraw.Draw(img)
    for row in range(8):
        for col in range(8):
            role = PIXELLAB_SIDE_SCROLLER_CELL_TO_ROLE[row * 8 + col]
            draw_pixel_lab_cell(draw, col, row, role)
            draw_slot_outline(draw, col, row)
    return img


def gen_blob_47_godot() -> Image.Image:
    """7x7 atlas (Caeles canonical packing). 47 used cells + 2 unused
    (the unused cells stay transparent). Solid 32x32 silhouettes per
    slot; mask encoded by atlas POSITION via the layout's _MASK_TO_ATLAS
    dict. Slot order matches penta_tile_layout_blob_47_godot.gd:
    index → (col=index%7, row=index/7) over BLOB_47_GODOT_MASKS sorted ascending.
    """
    assert len(BLOB_47_GODOT_MASKS) == 47, "BLOB_47_GODOT_MASKS must hold exactly 47 entries"
    img = new_atlas(7, 7)
    draw = ImageDraw.Draw(img)
    for index, mask in enumerate(BLOB_47_GODOT_MASKS):
        col = index % 7
        row = index // 7
        draw_47_blob_silhouette(draw, col, row, mask)
        draw_slot_outline(draw, col, row)
    # Cells (5, 6) and (6, 6) are intentionally left transparent.
    return img


def main() -> None:
    OUT_LAYOUTS.mkdir(parents=True, exist_ok=True)
    OUT_PENTA.mkdir(parents=True, exist_ok=True)

    # 10 Penta variants
    for mode_int, mode_name in [(1, "one"), (2, "two"), (3, "three"), (4, "four"), (5, "five")]:
        for axis in ("horizontal", "vertical"):
            img = gen_penta(mode_int, axis)
            img.save(OUT_PENTA / f"{mode_name}_{axis}.png")

    # 4 flat siblings
    gen_dual_grid_16().save(OUT_LAYOUTS / "penta_tile_layout_dual_grid_16.png")
    gen_wang_2_edge().save(OUT_LAYOUTS / "penta_tile_layout_wang_2_edge.png")
    gen_wang_2_corner().save(OUT_LAYOUTS / "penta_tile_layout_wang_2_corner.png")
    gen_minimal_3x3().save(OUT_LAYOUTS / "penta_tile_layout_minimal_3x3.png")

    # Phase 3 — Blob47Godot (7x7 atlas, 47 used + 2 transparent slots)
    gen_blob_47_godot().save(OUT_LAYOUTS / "penta_tile_layout_blob_47_godot.png")

    # Phase 3.5 — PixelLab Top-Down + Side-Scroller (8x8 atlas, role-coded silhouettes)
    gen_pixel_lab_top_down().save(OUT_LAYOUTS / "penta_tile_layout_pixel_lab_top_down.png")
    gen_pixel_lab_side_scroller().save(OUT_LAYOUTS / "penta_tile_layout_pixel_lab_side_scroller.png")

    print("Generated 17 bitmask PNGs at:", OUT_LAYOUTS)


if __name__ == "__main__":
    main()
