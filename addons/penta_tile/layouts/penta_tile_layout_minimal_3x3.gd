@tool
## Minimal3x3 layout — 3×3 atlas, 9 unique tiles, 4-bit edge mask.
##
## Mask convention: T=1, E=2, B=4, W=8 (cardinal-edge mask, matching Wang2Edge naming).
## Single-grid: yes.
##
## This layout covers the 9-tile minimum for cardinal-edge autotiling: a 3×3 grid
## where the center tile is the "fully connected" interior, the corners are the
## four outer-corner tiles, and the edges are the four cardinal-edge tiles.
## With only 9 unique tiles, several mask states must reuse tiles — the "open-side"
## rule collapses all 16 mask states onto the 9-tile palette:
##
##   A tile lives at the atlas column matching open-W/open-E and atlas row matching
##   open-T/open-B. "Open" means that cardinal neighbor is absent (bit NOT set).
##   When both sides on an axis are open (or both closed), col/row = 1 (center).
##   Diagonal-only collisions (e.g. both T and B absent → col/row both forced to 1)
##   collapse to the center tile — accepted visual loss inherent to the 9-tile minimum.
##
## Atlas layout (3 columns × 3 rows, row-major):
##   Row 0 (open-T):  NW corner  | N edge      | NE corner
##   Row 1 (center):  W edge     | center fill | E edge
##   Row 2 (open-B):  SW corner  | S edge      | SE corner
##
## Column assignment:  open-W only → col 0 | neither/both → col 1 | open-E only → col 2
## Row assignment:     open-T only → row 0 | neither/both → row 1 | open-B only → row 2
class_name PentaTileLayoutMinimal3x3
extends PentaTileLayout

const _T := Vector2i(0, -1)
const _E := Vector2i(1, 0)
const _B := Vector2i(0, 1)
const _W := Vector2i(-1, 0)


func is_dual_grid() -> bool:
	return false


func compute_mask(coord: Vector2i, sample_fn: Callable) -> int:
	var mask := 0
	if sample_fn.call(coord + _T): mask |= 1
	if sample_fn.call(coord + _E): mask |= 2
	if sample_fn.call(coord + _B): mask |= 4
	if sample_fn.call(coord + _W): mask |= 8
	return mask


# 9-tile minimum mapping via the "open-side" rule. Several mask states share tiles
# (the inherent loss of the minimum-3x3 layout). An open side (no neighbor on that
# cardinal direction) means the tile shows that side's exposed edge.
#
# Open-side collisions (both open or both closed on one axis) resolve to col/row 1
# (the center column/row). This means mask 0 (all-open) → (1,1), but mask 0 returns
# null below (isolated cell). Masks 5 (T+B) and 10 (E+W) collapse to center (1,1).
func mask_to_atlas(mask: int) -> PentaTileAtlasSlot:
	if mask == 0:
		return null
	# Open sides: bit NOT set means that neighbor is absent.
	var open_t := (mask & 1) == 0
	var open_e := (mask & 2) == 0
	var open_b := (mask & 4) == 0
	var open_w := (mask & 8) == 0
	# Column: open-W only → 0, open-E only → 2, else → 1.
	var col := 1
	if open_w and not open_e:
		col = 0
	elif open_e and not open_w:
		col = 2
	# Row: open-T only → 0, open-B only → 2, else → 1.
	var row := 1
	if open_t and not open_b:
		row = 0
	elif open_b and not open_t:
		row = 2
	var slot := PentaTileAtlasSlot.new()
	slot.atlas_coords = Vector2i(col, row)
	slot.transform_flags = 0
	slot.alternative_tile = 0
	return slot


func get_fallback_tile_set() -> TileSet:
	var tex := load("res://addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.png") as Texture2D
	if tex == null:
		return null
	var ts := TileSet.new()
	var src := TileSetAtlasSource.new()
	src.texture = tex
	var tile_size := Vector2i(tex.get_width() / 3, tex.get_height() / 3)
	src.texture_region_size = tile_size
	for y in range(3):
		for x in range(3):
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	ts.tile_size = tile_size
	return ts
