@tool
## DualGrid16 layout — 4×4 atlas, 16 unique tiles, 4-bit corner mask.
##
## Mask convention: TL=1, TR=2, BL=4, BR=8 (corner mask matching Godot's stock
## dual-grid template + the dandeliondino addon's `tile_map_dual` convention).
## NO rotation reuse — every one of the 16 mask states has a dedicated authored
## tile in a 4-column × 4-row grid. Use this layout when your atlas already
## ships all 16 corner-mask variants and you want pixel-perfect control.
##
## Atlas layout (mask = column + row * 4):
##   Row 0:  mask 0 | mask 1 | mask 2 | mask 3
##   Row 1:  mask 4 | mask 5 | mask 6 | mask 7
##   Row 2:  mask 8 | mask 9 | mask 10| mask 11
##   Row 3:  mask 12| mask 13| mask 14| mask 15
##
## Dual-grid: yes — paints at the half-tile-offset display cell.
class_name PentaTileLayoutDualGrid16
extends PentaTileLayout

const _TL := Vector2i(-1, -1)
const _TR := Vector2i(0, -1)
const _BL := Vector2i(-1, 0)
const _BR := Vector2i(0, 0)


func is_dual_grid() -> bool:
	return true


func compute_mask(coord: Vector2i, sample_fn: Callable) -> int:
	var mask := 0
	if sample_fn.call(coord + _TL): mask |= 1
	if sample_fn.call(coord + _TR): mask |= 2
	if sample_fn.call(coord + _BL): mask |= 4
	if sample_fn.call(coord + _BR): mask |= 8
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
	var tex := load("res://addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.png") as Texture2D
	if tex == null:
		return null
	var ts := TileSet.new()
	var src := TileSetAtlasSource.new()
	src.texture = tex
	# 4×4 atlas; tile_size derived from texture / 4 (assumes square atlas, square tiles).
	var tile_size := Vector2i(tex.get_width() / 4, tex.get_height() / 4)
	src.texture_region_size = tile_size
	for y in range(4):
		for x in range(4):
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	ts.tile_size = tile_size
	return ts
