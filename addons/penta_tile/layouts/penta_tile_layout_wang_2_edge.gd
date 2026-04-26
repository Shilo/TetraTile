@tool
## Wang2Edge layout — 4×4 atlas, 16 unique tiles, 4-bit edge mask.
##
## Mask convention: CR31 N=1, E=2, S=4, W=8 (cardinal-edge mask).
## Single-grid: yes — paints directly at the logic cell (no half-tile offset).
## NO rotation reuse — every one of the 16 mask states has a dedicated authored tile.
##
## Also known as 'Marching Squares' in algorithm-centric writeups (e.g., the
## Excalibur.js dual-grid article); same atlas, different vocabulary. Helps users
## arriving via marching-squares search terms find the right layout.
##
## Atlas layout (mask = column + row * 4):
##   Row 0:  mask 0 | mask 1 | mask 2 | mask 3
##   Row 1:  mask 4 | mask 5 | mask 6 | mask 7
##   Row 2:  mask 8 | mask 9 | mask 10| mask 11
##   Row 3:  mask 12| mask 13| mask 14| mask 15
class_name PentaTileLayoutWang2Edge
extends PentaTileLayout

const _N := Vector2i(0, -1)
const _E := Vector2i(1, 0)
const _S := Vector2i(0, 1)
const _W := Vector2i(-1, 0)


func is_dual_grid() -> bool:
	return false


func compute_mask(coord: Vector2i, sample_fn: Callable) -> int:
	var mask := 0
	if sample_fn.call(coord + _N): mask |= 1
	if sample_fn.call(coord + _E): mask |= 2
	if sample_fn.call(coord + _S): mask |= 4
	if sample_fn.call(coord + _W): mask |= 8
	return mask


func mask_to_atlas(mask: int) -> PentaTileAtlasSlot:
	if mask == 0:
		return null
	var slot := PentaTileAtlasSlot.new()
	slot.atlas_coords = Vector2i(mask % 4, mask / 4)
	slot.transform_flags = 0
	slot.alternative_tile = 0
	return slot


func get_fallback_tile_set() -> TileSet:
	var tex := load("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.png") as Texture2D
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
