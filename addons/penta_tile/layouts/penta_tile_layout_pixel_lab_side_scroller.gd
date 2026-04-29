@tool
## PixelLabSideScroller — 8x8 atlas, single-grid, 4-bit corner mask.
##
## Mask convention (D-93): TL=1, TR=2, BL=4, BR=8 — same as top-down.
## Single-grid: yes. NO rotation reuse (D-90).
##
## Atlas: 8 cols × 8 rows = 64 cells. Cell-to-role table comes from
## tileset_transform.lua's tileset_output_side variant; the role-to-mask
## bijection is IDENTICAL to top-down (D-94 — locked by spike 003).
## Both PIXLAB layouts duplicate _ROLE_TO_MASK per D-98 (GDScript 2 cannot
## parse cross-class const references).
##
## Variation banks: NOT supported in v0.2 — first-cell row-major pick (D-89).
## Bank pick deferred to v2 backlog VAR-PIXEL-01.
##
## Mask=0 dispatch (D-104, Pitfall #9): mask=0 → role 12 → cell (0, 0).
## Top-down has role 12 first appearing at (2, 2); side-scroller has it at
## (0, 0) (top-left corner of the side-scroller table). The cache returns
## the correct entry for each subclass without special-casing.
##
## No `pixellab_version: int` field (D-92): per CLAUDE.md no-forward-compat
## rule, future PixelLab plugin updates trigger a new release + CHANGELOG.
##
## Source provenance:
##   - cell-to-role table: tileset_transform.lua:28-36 `tileset_output_side`
##   - role-to-mask bijection: spike 003 README + decode.py
class_name PentaTileLayoutPixelLabSideScroller
extends PentaTileLayout

const _TL := Vector2i(-1, -1)
const _TR := Vector2i(0, -1)
const _BL := Vector2i(-1, 0)
const _BR := Vector2i(0, 0)

# 64 ints, row-major (row * 8 + col). Verbatim from
# tileset_transform.lua:28-36 `tileset_output_side`. Each int is a role ID 0..15.
const _CELL_TO_ROLE := [
	12, 12, 12, 12, 13,  3,  3,  3,
	 0, 13,  3,  3, 14,  9, 10,  6,
	11,  8,  9,  9, 15, 12,  1,  6,
	11, 12, 12, 12, 12, 12,  8,  9,
	 2,  3,  3,  3,  0, 12, 12, 12,
	 6,  6,  6,  7, 15, 12, 12, 12,
	 6,  6,  6, 11, 13,  3,  3,  3,
	 6,  6,  7,  4,  5,  6,  6,  6,
]

# role index → 4-bit corner mask. LOCKED by spike 003. Same bijection as
# PentaTileLayoutPixelLabTopDown; D-98 duplicates per-subclass.
const _ROLE_TO_MASK := [4, 10, 13, 12, 9, 14, 15, 7, 2, 3, 11, 5, 0, 8, 6, 1]

# Cached at _init: row-major-first cell for each of 16 masks.
var _first_cell_by_mask: Array[Vector2i]


func _init() -> void:
	super()
	_init_cache()


func _init_cache() -> void:
	_first_cell_by_mask = []
	_first_cell_by_mask.resize(16)
	for i in 16:
		_first_cell_by_mask[i] = Vector2i(-1, -1)
	for row in 8:
		for col in 8:
			var role: int = _CELL_TO_ROLE[row * 8 + col]
			var mask: int = _ROLE_TO_MASK[role]
			if _first_cell_by_mask[mask] == Vector2i(-1, -1):
				_first_cell_by_mask[mask] = Vector2i(col, row)


func is_dual_grid() -> bool:
	return false


func compute_mask(coord: Vector2i, sample_fn: Callable) -> int:
	var mask := 0
	if sample_fn.call(coord + _TL): mask |= 1
	if sample_fn.call(coord + _TR): mask |= 2
	if sample_fn.call(coord + _BL): mask |= 4
	if sample_fn.call(coord + _BR): mask |= 8
	return mask


func mask_to_atlas(mask: int, _strip_index: int = 0) -> PentaTileAtlasSlot:
	# D-104 / Pitfall #9: mask=0 dispatches to role 12's first cell (0, 0)
	# for side-scroller; single-grid mask=0 is NOT erase.
	var slot := PentaTileAtlasSlot.new()
	slot.atlas_coords = _first_cell_by_mask[mask]
	slot.transform_flags = 0
	slot.alternative_tile = 0
	return slot


func _default_bitmask_template_path() -> String:
	return "res://addons/penta_tile/layouts/penta_tile_layout_pixel_lab_side_scroller.png"


func _fallback_atlas_grid_size() -> Vector2i:
	return Vector2i(8, 8)
