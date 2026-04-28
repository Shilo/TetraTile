"""Regenerate addons/penta_tile/demo/penta_tile_ground.png as a FIVE-mode
Penta atlas (5 hand-authored archetype tiles, no synthesis required).

Phase 2 slot ordering (locked):
  0 = IsolatedCell    — single BL-quadrant outer-corner art (transparent
                        elsewhere) so OuterCorner-via-rotation reads as a
                        single corner, not a full silhouette
  1 = Fill            — solid stippled stone
  2 = Border          — bottom-half slab (canonical ROTATE_0 = mask 12)
  3 = InnerCorner     — L-shape minus TR quadrant (canonical ROTATE_0 = mask 13)
  4 = OppositeCorners — TL + BR quadrants stippled (canonical ROTATE_0 = mask 9
                        "\\" diagonal)

Why FIVE-mode for the demo (not FOUR with synthesis): in FOUR mode the
synthesizer reads slot 0's TL+BR quadrants for OppositeCorners (slot 4) and
its center 50% / bottom half / L-shape regions for Fill / Border /
InnerCorner. That requires slot 0 to be a full silhouette covering all those
regions. But OuterCorner-via-rotation also reads slot 0 verbatim with
rotation, so a full silhouette renders as 4 overlapping silhouettes around a
painted cell — the documented Gate 1 visual tradeoff.

Going FIVE-mode lets slot 0 be a clean single-quadrant outer-corner piece
(rotates correctly into 4 corners of a coherent silhouette) AND each of the
other 4 archetypes is hand-authored — no synthesis, no tradeoff. The user's
locked design (session a69c3ba5) keeps load-time synthesis for ONE/TWO/THREE
mode; FOUR is also synthesis-capable; FIVE is pure-authored for users who
want pixel-perfect output. The demo opts into FIVE for clean visuals.

Each tile is 16x16. Output strip is 80x16 (5 tiles horizontal).

Run:
  python addons/penta_tile/demo/_regen_demo_ground.py
"""

from PIL import Image, ImageDraw
from pathlib import Path

TILE = 16
COLS = 5
ROWS = 1

# Demo aesthetic palette (eyeballed from the user's screenshot — dark teal stone
# with orange highlights).
TRANSPARENT = (0, 0, 0, 0)
STONE_DARK  = (60, 75, 80, 255)
STONE_MID   = (90, 105, 110, 255)
STONE_LIGHT = (130, 140, 145, 255)
ORANGE      = (240, 165, 60, 255)
ORANGE_DARK = (200, 130, 30, 255)


def _stippled_fill(draw: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int) -> None:
    """Fill rect with mid stone + light dots + orange specks (matches user's screenshot
    aesthetic). Reproducible — uses position parity, not random."""
    for y in range(y0, y1):
        for x in range(x0, x1):
            # Stippled stone base
            base = STONE_DARK if (x + y) % 3 == 0 else STONE_MID
            if (x * 7 + y * 11) % 13 == 0:
                base = STONE_LIGHT
            # Sparse orange specks
            if (x * 5 + y * 3) % 19 == 0:
                base = ORANGE_DARK
            draw.point((x, y), fill=base)


def _orange_border(draw: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int, sides: str) -> None:
    """Draw an orange wire on selected sides (subset of 'TBLR'). Inset by 1px so the
    wire reads as inside-edge highlight, not outer outline."""
    if "T" in sides:
        for x in range(x0 + 1, x1 - 1):
            draw.point((x, y0 + 1), fill=ORANGE)
    if "B" in sides:
        for x in range(x0 + 1, x1 - 1):
            draw.point((x, y1 - 2), fill=ORANGE)
    if "L" in sides:
        for y in range(y0 + 1, y1 - 1):
            draw.point((x0 + 1, y), fill=ORANGE)
    if "R" in sides:
        for y in range(y0 + 1, y1 - 1):
            draw.point((x1 - 2, y), fill=ORANGE)


def draw_isolated_cell(img: Image.Image, col: int) -> None:
    """Slot 0 — IsolatedCell. ONLY the BL quadrant is filled; the other 3
    quadrants are fully transparent. Under the OuterCorner-via-rotation
    dispatch (masks 1/2/4/8 → slot 0 + ROTATE_0/90/180/270), the BL quadrant
    rotates to land at the correct corner of each of the 4 display cells
    around a painted logic cell — and the 4 corner pieces meet at the painted
    cell's center to form ONE coherent outer-corner silhouette.

    BL quadrant = pixels x:0-7, y:8-15.
      ROTATE_0   (mask 4): BL stays at BL of cell south of painted cell.
      ROTATE_90  (mask 1): BL → TL of cell SE of painted cell.
      ROTATE_180 (mask 2): BL → TR of cell SW of painted cell.
      ROTATE_270 (mask 8): BL → BR of cell NW of painted cell.

    Single-quadrant slot 0 is only safe in FIVE mode where the OTHER 4
    archetypes (Fill/Border/InnerCorner/OppositeCorners) are authored
    explicitly. In ONE/TWO/THREE/FOUR mode the synthesizer would read slot 0's
    transparent quadrants for those archetypes and produce empty art."""
    draw = ImageDraw.Draw(img)
    x0, y0 = col * TILE, 0
    mid_x, mid_y = x0 + TILE // 2, y0 + TILE // 2
    bl_x1, bl_y1 = mid_x, y0 + TILE
    # BL quadrant only — TL/TR/BR stay transparent.
    _stippled_fill(draw, x0, mid_y, bl_x1, bl_y1)
    # Orange wires on the L and B sides of the BL quadrant — these become the
    # outer perimeter of the composed silhouette under rotation+tiling.
    _orange_border(draw, x0, mid_y, bl_x1, bl_y1, "LB")


def draw_fill(img: Image.Image, col: int) -> None:
    """Slot 1 — Fill. Solid stippled rect, no edges (fully surrounded)."""
    draw = ImageDraw.Draw(img)
    x0, y0 = col * TILE, 0
    x1, y1 = x0 + TILE, y0 + TILE
    _stippled_fill(draw, x0, y0, x1, y1)


def draw_border(img: Image.Image, col: int) -> None:
    """Slot 2 — Border. Canonical orientation = ROTATE_0 = mask 12 (BL+BR)
    (per penta_tile_layout_penta.gd: mask 12 → SLOT_BORDER, ROTATE_0).
    That means the BOTTOM half is filled stone with the TOP transparent —
    a horizontal edge facing up."""
    draw = ImageDraw.Draw(img)
    x0, y0 = col * TILE, 0
    x1, y1 = x0 + TILE, y0 + TILE
    mid_y = y0 + TILE // 2
    _stippled_fill(draw, x0, mid_y, x1, y1)
    _orange_border(draw, x0, mid_y, x1, y1, "T")


def draw_inner_corner(img: Image.Image, col: int) -> None:
    """Slot 3 — InnerCorner. Canonical orientation = ROTATE_0 = mask 13 (TL+BL+BR)
    (per penta_tile_layout_penta.gd: mask 13 → SLOT_INNER_CORNER, ROTATE_0).
    That means the TOP-RIGHT quadrant is empty; the L-shape (TL + BL + BR) is filled."""
    draw = ImageDraw.Draw(img)
    x0, y0 = col * TILE, 0
    x1, y1 = x0 + TILE, y0 + TILE
    mid_x, mid_y = x0 + TILE // 2, y0 + TILE // 2
    # TL quadrant
    _stippled_fill(draw, x0, y0, mid_x, mid_y)
    # BL quadrant
    _stippled_fill(draw, x0, mid_y, mid_x, y1)
    # BR quadrant
    _stippled_fill(draw, mid_x, mid_y, x1, y1)
    # Orange wire around the inner corner (top-right cutout)
    for x in range(mid_x, x1 - 1):
        draw.point((x, mid_y), fill=ORANGE)
    for y in range(y0 + 1, mid_y):
        draw.point((mid_x, y), fill=ORANGE)


def draw_opposite_corners(img: Image.Image, col: int) -> None:
    """Slot 4 — OppositeCorners. Canonical orientation = ROTATE_0 = mask 9
    (TL+BR, "\\" diagonal — per penta_tile_layout_penta.gd anchoring note:
    PentaTile picks mask 9 = _ROTATE_0 for the diagonal anchor). TL and BR
    quadrants are filled; TR and BL stay transparent."""
    draw = ImageDraw.Draw(img)
    x0, y0 = col * TILE, 0
    x1, y1 = x0 + TILE, y0 + TILE
    mid_x, mid_y = x0 + TILE // 2, y0 + TILE // 2
    # TL quadrant
    _stippled_fill(draw, x0, y0, mid_x, mid_y)
    # BR quadrant
    _stippled_fill(draw, mid_x, mid_y, x1, y1)
    # Orange wires on the outer edges of each filled quadrant
    _orange_border(draw, x0, y0, mid_x, mid_y, "TL")
    _orange_border(draw, mid_x, mid_y, x1, y1, "BR")


def main() -> None:
    out_path = Path(__file__).parent / "penta_tile_ground.png"
    img = Image.new("RGBA", (COLS * TILE, ROWS * TILE), TRANSPARENT)

    draw_isolated_cell(img, 0)
    draw_fill(img, 1)
    draw_border(img, 2)
    draw_inner_corner(img, 3)
    draw_opposite_corners(img, 4)

    img.save(out_path)
    print(f"wrote {out_path} ({img.size[0]}x{img.size[1]})")


if __name__ == "__main__":
    main()
