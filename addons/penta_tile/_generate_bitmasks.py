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
    """1-px dark outline around a slot."""
    x0, y0 = col * TILE, row * TILE
    x1, y1 = x0 + TILE - 1, y0 + TILE - 1
    draw.rectangle((x0, y0, x1, y1), outline=OUTLINE, width=1)


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
    """Plus-sign silhouette per an edge mask: center hint + arms.

    Bits: N=1, E=2, S=4, W=8.
    """
    x0, y0 = col * TILE, row * TILE
    # Scale the center hint and arms relative to TILE=32
    # Phase 1 used 16px tile with center at 6..9; for 32px we scale by 2: center at 12..19
    cx0, cy0 = x0 + 12, y0 + 12
    cx1, cy1 = x0 + 19, y0 + 19
    # always-on center hint so empty masks still show something
    draw.rectangle((cx0, cy0, cx1, cy1), fill=HINT)
    # arms -- 8x12 stubs from center to each edge (scaled from Phase 1's 4x6)
    if mask & 1:  # N
        draw.rectangle((cx0, y0, cx1, cy1), fill=GREY)
    if mask & 2:  # E
        draw.rectangle((cx0, cy0, x0 + TILE - 1, cy1), fill=GREY)
    if mask & 4:  # S
        draw.rectangle((cx0, cy0, cx1, y0 + TILE - 1), fill=GREY)
    if mask & 8:  # W
        draw.rectangle((x0, cy0, cx1, cy1), fill=GREY)


# ---- Penta archetype drawers (NEW in Phase 2; pixel coords spelled out above) ----

def draw_penta_isolated_cell(draw, col, row, bl_only=False):
    """Slot 0 -- IsolatedCell silhouette.

    Two shapes depending on `bl_only`:

    `bl_only = False` (default, used by ONE/TWO/THREE/FOUR mode greyboxes):
      Full silhouette = 4 corners + 4 edges + center fill packed into one tile.
      Synthesis recipes for ONE/TWO/THREE/FOUR mode read slot 0's regions to
      generate Fill (center 50%), Border (bottom half), InnerCorner (full
      minus TR), OppositeCorners (TL+BR composite). The full silhouette
      makes those recipes produce real art. Tradeoff (Gate 1): under
      OuterCorner-via-rotation (masks 1/2/4/8), each rotated copy renders
      the full silhouette so 4 surrounding cells around a painted block
      show 4 mini silhouettes instead of 4 corner pieces. Documented; the
      synthesis-driven modes accept this.

    `bl_only = True` (used by FIVE mode greybox only):
      Just the BL quadrant filled — single outer-corner piece. FIVE mode
      doesn't use synthesis (slots 1-4 are hand-authored), so slot 0 is
      free to be optimized for the OuterCorner-via-rotation visual: each
      of the 4 rotations places the BL quadrant at a different corner of
      the rendered cell, and 4 such cells around a painted block compose
      into a clean outer-corner-only silhouette without overlap noise."""
    ox, oy = col * TILE, row * TILE
    if bl_only:
        # BL quadrant only — pixels x:0-15, y:16-31 in 32x32 tile coords.
        draw.rectangle((ox, oy + 16, ox + 16, oy + TILE), fill=GREY)
        return
    # Full silhouette
    draw.rectangle((ox + 8, oy + 8, ox + 24, oy + 24), fill=GREY)
    # 4 edge slabs (between corner caps)
    draw.rectangle((ox + 10, oy + 0,  ox + 22, oy + 4),  fill=GREY)   # top
    draw.rectangle((ox + 10, oy + 28, ox + 22, oy + 32), fill=GREY)   # bottom
    draw.rectangle((ox + 0,  oy + 10, ox + 4,  oy + 22), fill=GREY)   # left
    draw.rectangle((ox + 28, oy + 10, ox + 32, oy + 22), fill=GREY)   # right
    # 4 corner caps
    draw.rectangle((ox + 0,  oy + 0,  ox + 4,  oy + 4),  fill=GREY)   # TL
    draw.rectangle((ox + 28, oy + 0,  ox + 32, oy + 4),  fill=GREY)   # TR
    draw.rectangle((ox + 0,  oy + 28, ox + 4,  oy + 32), fill=GREY)   # BL
    draw.rectangle((ox + 28, oy + 28, ox + 32, oy + 32), fill=GREY)   # BR


def draw_penta_fill(draw, col, row):
    """Slot 1 -- Fill silhouette: solid 32x32 grey square."""
    ox, oy = col * TILE, row * TILE
    draw.rectangle((ox, oy, ox + TILE, oy + TILE), fill=GREY)


def draw_penta_border(draw, col, row):
    """Slot 2 -- Border silhouette: bottom-half slab (rows 16..32 filled)."""
    ox, oy = col * TILE, row * TILE
    draw.rectangle((ox, oy + 16, ox + TILE, oy + TILE), fill=GREY)


def draw_penta_inner_corner(draw, col, row):
    """Slot 3 -- InnerCorner silhouette: L-shape (TR quadrant cut out)."""
    ox, oy = col * TILE, row * TILE
    draw.rectangle((ox,      oy,      ox + 16, oy + TILE), fill=GREY)   # left half
    draw.rectangle((ox + 16, oy + 16, ox + TILE, oy + TILE), fill=GREY) # BR quadrant


def draw_penta_opposite_corners(draw, col, row):
    """Slot 4 -- OppositeCorners silhouette: TL + BR quadrants filled (mask 9 anchor "\\")."""
    ox, oy = col * TILE, row * TILE
    draw.rectangle((ox,      oy,      ox + 16, oy + 16),      fill=GREY)   # TL
    draw.rectangle((ox + 16, oy + 16, ox + TILE, oy + TILE), fill=GREY)    # BR


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
    # FIVE mode is pure-authored (no synthesis). Slot 0 can be a clean
    # BL-quadrant outer-corner piece that rotates into 4 corners forming a
    # coherent silhouette around a painted block. ONE/TWO/THREE/FOUR mode
    # use synthesis recipes off slot 0 (Fill from center 50%, Border from
    # bottom half, InnerCorner from L-shape, OppositeCorners from TL+BR);
    # those recipes need a full-silhouette slot 0 to produce real art.
    bl_only = (mode == 5)
    for slot in range(mode):
        col, row = (slot, 0) if axis == "horizontal" else (0, slot)
        if slot == 0:
            draw_penta_isolated_cell(draw, col, row, bl_only=bl_only)
        else:
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
    """4x4 corner-mask greybox in CR31 cardinal naming (NE/SE/SW/NW).

    Visually identical to dual_grid_16 (same silhouettes); per NATIVE-03's
    "different bit-naming, same silhouettes" wording, output the same image data.
    """
    return gen_dual_grid_16()


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
