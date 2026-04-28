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

    print("Generated 14 bitmask PNGs at:", OUT_LAYOUTS)


if __name__ == "__main__":
    main()
