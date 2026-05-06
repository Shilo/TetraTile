@tool
## PixelLabTopDown — 8x8 atlas, single-grid, 4-bit corner mask.
##
## Mask convention (D-93): TL=1, TR=2, BL=4, BR=8 (same corner-mask convention
## as PentaTileLayoutDualGrid16 and PentaTileLayoutWang2Corner).
## Single-grid: yes — paints directly at the logic cell.
## NO rotation reuse (D-90): every dispatched slot uses transform_flags=0.
##
## Atlas: 8 cols × 8 rows = 64 cells. Cells map to 16 "roles" via
## tileset_transform.lua's tileset_output table; roles map to 4-bit corner
## masks via the locked role-to-mask bijection (D-94, spike 003).
##
## Variation banks: NOT supported in v0.2 — when multiple cells map to the
## same mask (e.g. mask 15 / role 6 has 28 cells), mask_to_atlas returns the
## row-major FIRST cell (D-89). Bank pick deferred to v2 backlog
## VAR-PIXEL-01 — design-coupled with VAR-01 + MULTITERR-01.
##
## Mask=0 dispatch (D-104, Pitfall #9): mask=0 → role 12 → cell (2, 2).
## Single-grid mask=0 is NOT erase; the cached first-cell entry returns a
## valid render target so isolated cells render.
##
## No `pixellab_version: int` field (D-92): per CLAUDE.md no-forward-compat
## rule, future PixelLab plugin updates trigger a new release + CHANGELOG.
##
## Source provenance:
##   - cell-to-role table: tileset_transform.lua:17-26 `tileset_output`
##   - role-to-mask bijection: spike 003 README + decode.py (12/16 PASS)
class_name PentaTileLayoutPixelLabTopDown
extends PentaTileLayout

const _TL := Vector2i(-1, -1)
const _TR := Vector2i(0, -1)
const _BL := Vector2i(-1, 0)
const _BR := Vector2i(0, 0)

# 64 ints, row-major (row * 8 + col). Verbatim from
# tileset_transform.lua:17-26 `tileset_output`. Each int is a role ID 0..15.
## D-94 locked cell-to-role table from PixelLab's top-down tileset output.
const _CELL_TO_ROLE := [
	6, 6, 6, 6, 6, 6, 6, 6,
	6, 7, 9, 10, 7, 9, 10, 6,
	6, 11, 12, 8, 15, 12, 1, 6,
	6, 11, 12, 12, 13, 3, 5, 6,
	6, 2, 0, 13, 14, 9, 10, 6,
	6, 7, 4, 5, 11, 12, 1, 6,
	6, 2, 5, 12, 2, 3, 5, 6,
	6, 6, 6, 6, 6, 6, 6, 6,
]

# role index → 4-bit corner mask. LOCKED by spike 003. Same bijection in
# both PIXLAB layouts; D-98 duplicates per-subclass (GDScript 2 cannot
# parse cross-class const references).
## D-94 role-to-mask bijection, duplicated per subclass by D-98.
const _ROLE_TO_MASK := [4, 10, 13, 12, 9, 14, 15, 7, 2, 3, 11, 5, 0, 8, 6, 1]

# Cached at _init: row-major-first cell for each of 16 masks.
var _first_cell_by_mask: Array[Vector2i]


func _init() -> void:
	super()
	_init_cache()


## Build the row-major-first cache from mask to atlas cell.
##
## This locks D-89 first-cell selection and keeps [method mask_to_atlas] O(1).
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


## PixelLabTopDown is single-grid: it paints directly on logic-painted cells.
func is_dual_grid() -> bool:
	return false


## Compute the 4-bit corner mask for [param coord] using TL=1, TR=2, BL=4, BR=8.
##
## [param sample_fn] reports which neighboring logic cells are painted.
func compute_mask(coord: Vector2i, sample_fn: Callable) -> int:
	var mask := 0
	if sample_fn.call(coord + _TL): mask |= 1
	if sample_fn.call(coord + _TR): mask |= 2
	if sample_fn.call(coord + _BL): mask |= 4
	if sample_fn.call(coord + _BR): mask |= 8
	return mask


## Return the cached row-major-first cell for [param mask] (D-89).
##
## For [code]mask = 0[/code] (isolated cell), dispatches to role 12 -> cell
## [code](2, 2)[/code] per D-104 for the top-down variant.
func mask_to_atlas(mask: int, _strip_index: int = 0) -> PentaTileAtlasSlot:
	# D-104 / Pitfall #9: mask=0 dispatches to role 12's first cell (2, 2);
	# single-grid mask=0 is NOT erase. Cache returns a valid Vector2i for
	# every mask in [0..15] — no special-casing needed.
	var slot := PentaTileAtlasSlot.new()
	slot.atlas_coords = _first_cell_by_mask[mask]
	slot.transform_flags = 0
	slot.alternative_tile = 0
	return slot


func _default_bitmask_template_path() -> String:
	return "uid://crhotgtg4lij6"


func _fallback_atlas_grid_size() -> Vector2i:
	return Vector2i(8, 8)
