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


## Wang2Edge is single-grid: it paints directly on logic-painted cells.
func is_dual_grid() -> bool:
	return false


## Compute the 4-bit cardinal-edge mask for [param coord] using N=1, E=2, S=4, W=8.
##
## [param sample_fn] reports which neighboring logic cells are painted.
func compute_mask(coord: Vector2i, sample_fn: Callable) -> int:
	var mask := 0
	if sample_fn.call(coord + _N): mask |= 1
	if sample_fn.call(coord + _E): mask |= 2
	if sample_fn.call(coord + _S): mask |= 4
	if sample_fn.call(coord + _W): mask |= 8
	return mask


## Convert [param mask] to its dedicated 4x4 atlas slot.
##
## Mask 0 is a valid single-grid isolated-cell dispatch to atlas (0, 0), not an
## erase; see [b]Critical Pitfall #9[/b].
func mask_to_atlas(mask: int, _strip_index: int = 0) -> PentaTileAtlasSlot:
	# mask=0 (isolated cell with no cardinal neighbors): dispatch to atlas (0, 0).
	# A logic-painted cell must always render — single-grid Wang2Edge can't fall
	# back to "neighbor will fill it in" the way dual-grid layouts do. The
	# greybox at (0, 0) is solid 32x32; artists may overwrite with an "isolated
	# rock" tile. (mask % 4, mask / 4) covers mask=0 → (0, 0) naturally.
	var slot := PentaTileAtlasSlot.new()
	slot.atlas_coords = Vector2i(mask % 4, mask / 4)
	slot.transform_flags = 0
	slot.alternative_tile = 0
	return slot


func _default_bitmask_template_path() -> String:
	return "uid://btyhym2k72oql"


func _fallback_atlas_grid_size() -> Vector2i:
	return Vector2i(4, 4)
