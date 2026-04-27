@tool
## Wang2Corner layout — 4×4 atlas, 16 unique tiles, 4-bit corner mask in CR31 cardinal naming.
##
## Mask convention: CR31 NE=1, SE=2, SW=4, NW=8 (corner mask in compass terms).
## Single-grid: yes — paints directly at the logic cell.
## NO rotation reuse.
##
## Visually identical to PentaTileLayoutDualGrid16 on the same atlas data — same
## silhouettes, different bit-naming convention. Use this layout if your atlas
## was authored against CR31 corner-naming docs; use DualGrid16 if your atlas
## was authored against Godot's TL/TR/BL/BR convention. Both will paint
## correctly; the difference is which mask bit semantically corresponds to
## which logic-cell quadrant in the artist's head.
##
## NE corresponds to TR neighbor (i.e. coord + Vector2i(1, -1)).
## SE → BR neighbor (Vector2i(1, 1)).
## SW → BL neighbor (Vector2i(-1, 1)).
## NW → TL neighbor (Vector2i(-1, -1)).
##
## (Note: Wang2Corner samples DIAGONAL neighbors — NE/SE/SW/NW corner cells —
## NOT the 2×2 corner-quadrant scheme that Penta's dual-grid uses. This is
## single-grid: we want to know "is the diagonal neighbor present" to decide
## the corner appearance.)
class_name PentaTileLayoutWang2Corner
extends PentaTileLayout

const _NE := Vector2i(1, -1)
const _SE := Vector2i(1, 1)
const _SW := Vector2i(-1, 1)
const _NW := Vector2i(-1, -1)


func is_dual_grid() -> bool:
	return false


func compute_mask(coord: Vector2i, sample_fn: Callable) -> int:
	var mask := 0
	if sample_fn.call(coord + _NE): mask |= 1
	if sample_fn.call(coord + _SE): mask |= 2
	if sample_fn.call(coord + _SW): mask |= 4
	if sample_fn.call(coord + _NW): mask |= 8
	return mask


func mask_to_atlas(mask: int, _strip_index: int = 0) -> PentaTileAtlasSlot:
	if mask == 0:
		return null
	var slot := PentaTileAtlasSlot.new()
	slot.atlas_coords = Vector2i(mask % 4, mask / 4)
	slot.transform_flags = 0
	slot.alternative_tile = 0
	return slot


func _default_bitmask_template_path() -> String:
	return "res://addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.png"


func get_fallback_tile_set() -> TileSet:
	var tex := load("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.png") as Texture2D
	if tex == null:
		return null
	var ts := TileSet.new()
	var src := TileSetAtlasSource.new()
	src.texture = tex
	var tile_size := Vector2i(tex.get_width() / 4, tex.get_height() / 4)
	src.texture_region_size = tile_size
	for y in range(4):
		for x in range(4):
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	ts.tile_size = tile_size
	return ts
