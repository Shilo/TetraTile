@tool
## Blob47Godot — 47-tile blob layout, 8-bit Moore mask, single-grid.
##
## Mask convention (D-76): N=1, E=2, S=4, W=8, NE=16, SE=32, SW=64, NW=128.
## NOT the canonical CR31 clockwise ordering — see _collapse_8bit_moore for
## the algorithm. The 256→47 collapse rule (D-78) per BorisTheBrave's reference
## (https://www.boristhebrave.com/permanent/24/06/cr31/stagecast/wang/blob.html):
## "A corner bit only matters if both adjacent edges are set."
##
## Atlas: 7×7 (Caeles-canonical packing — 47 used cells + 2 unused; the
## unused cells stay transparent in the bundled bitmask PNG. Atlas slot
## coords are computed by sorting the 47 reachable masks ascending and
## packing row-major: index → (col=index%7, row=index/7).)
## Single-grid: yes — paints directly at the logic cell.
##
## Slot table sourced from: BorisTheBrave's published 47-blob reference (D-74).
##                          The 47-mask list is what the collapse rule
##                          emits when fed all 256 raw inputs (verified
##                          via blob_47_collapse_test).
##
## Variation banks: not supported — this is a 1-cell-per-mask layout.
## (Variation deferred to v2 backlog VAR-PIXEL-01.)
class_name PentaTileLayoutBlob47Godot
extends PentaTileLayout

const _N := Vector2i(0, -1)
const _E := Vector2i(1, 0)
const _S := Vector2i(0, 1)
const _W := Vector2i(-1, 0)
const _NE := Vector2i(1, -1)
const _SE := Vector2i(1, 1)
const _SW := Vector2i(-1, 1)
const _NW := Vector2i(-1, -1)

# 47 entries keyed on D-76-ordered, COLLAPSED masks → atlas (col, row) coords
# in the 7×7 canonical packing. Mask values listed in ASCENDING ORDER, row-
# major (index 0 → (0,0); index 6 → (6,0); index 7 → (0,1); ...; index 46
# → (4,6)). Cells (5,6) and (6,6) are unused and stay transparent.
#
# The 47-mask list is exactly the set of values reachable via _collapse_8bit_moore
# on raw input range [0, 256). Verified by tests/blob_47_collapse_test.gd.
const _MASK_TO_ATLAS: Dictionary = {
	  0: Vector2i(0, 0),    1: Vector2i(1, 0),    2: Vector2i(2, 0),    3: Vector2i(3, 0),
	  4: Vector2i(4, 0),    5: Vector2i(5, 0),    6: Vector2i(6, 0),
	  7: Vector2i(0, 1),    8: Vector2i(1, 1),    9: Vector2i(2, 1),   10: Vector2i(3, 1),
	 11: Vector2i(4, 1),   12: Vector2i(5, 1),   13: Vector2i(6, 1),
	 14: Vector2i(0, 2),   15: Vector2i(1, 2),   19: Vector2i(2, 2),   23: Vector2i(3, 2),
	 27: Vector2i(4, 2),   31: Vector2i(5, 2),   38: Vector2i(6, 2),
	 39: Vector2i(0, 3),   46: Vector2i(1, 3),   47: Vector2i(2, 3),   55: Vector2i(3, 3),
	 63: Vector2i(4, 3),   76: Vector2i(5, 3),   77: Vector2i(6, 3),
	 78: Vector2i(0, 4),   79: Vector2i(1, 4),   95: Vector2i(2, 4),  110: Vector2i(3, 4),
	111: Vector2i(4, 4),  127: Vector2i(5, 4),  137: Vector2i(6, 4),
	139: Vector2i(0, 5),  141: Vector2i(1, 5),  143: Vector2i(2, 5),  155: Vector2i(3, 5),
	159: Vector2i(4, 5),  175: Vector2i(5, 5),  191: Vector2i(6, 5),
	205: Vector2i(0, 6),  207: Vector2i(1, 6),  223: Vector2i(2, 6),  239: Vector2i(3, 6),
	255: Vector2i(4, 6),
}


## Blob47Godot is single-grid: it paints directly on logic-painted cells.
func is_dual_grid() -> bool:
	return false


## Compute the raw 8-bit Moore-neighborhood mask for [param coord].
##
## [param sample_fn] reports painted logic cells for N/E/S/W and diagonals; the
## raw mask is collapsed by [method _collapse_8bit_moore] before atlas dispatch.
func compute_mask(coord: Vector2i, sample_fn: Callable) -> int:
	var mask := 0
	if sample_fn.call(coord + _N):  mask |= 1
	if sample_fn.call(coord + _E):  mask |= 2
	if sample_fn.call(coord + _S):  mask |= 4
	if sample_fn.call(coord + _W):  mask |= 8
	if sample_fn.call(coord + _NE): mask |= 16
	if sample_fn.call(coord + _SE): mask |= 32
	if sample_fn.call(coord + _SW): mask |= 64
	if sample_fn.call(coord + _NW): mask |= 128
	return mask


## Look up [param mask] in the 47-entry BorisTheBrave atlas convention.
##
## The raw 8-bit mask collapses first; unmapped masks defensively fall through
## to slot (0, 0). Mask 0 is a valid single-grid isolated-cell dispatch per
## [b]Critical Pitfall #9[/b].
func mask_to_atlas(mask: int, _strip_index: int = 0) -> PentaTileAtlasSlot:
	# D-78 collapse first, then dict lookup. The collapse rule is total
	# (every raw mask in [0, 256) collapses to one of the 47 keys), so the
	# .get(...) fallback to (0, 0) is defensive only — Pitfall #9 + D-80:
	# mask=0 dispatches to (0, 0) which IS the "lonely tile" entry, so
	# isolated cells render correctly.
	var collapsed := _collapse_8bit_moore(mask)
	assert(_MASK_TO_ATLAS.has(collapsed), "Blob47Godot: collapse produced unmapped mask %d (raw %d) — _MASK_TO_ATLAS transcription error" % [collapsed, mask])
	var slot := PentaTileAtlasSlot.new()
	slot.atlas_coords = _MASK_TO_ATLAS.get(collapsed, Vector2i(0, 0))
	slot.transform_flags = 0
	slot.alternative_tile = 0
	return slot


# D-78: 256→47 collapse via BorisTheBrave's algorithmic rule.
# A corner bit only survives if both adjacent edges are also set.
# The function is total and idempotent — verified by blob_47_collapse_test.
## Collapse an 8-bit Moore mask into BorisTheBrave's 47-entry blob convention.
##
## Compass-corner bits survive only when both adjacent cardinal bits are set.
## [code]blob_47_collapse_test[/code] contains the canonical assertions.
static func _collapse_8bit_moore(raw: int) -> int:
	var n := raw & 1
	var e := raw & 2
	var s := raw & 4
	var w := raw & 8
	var collapsed := raw & 15
	if n != 0 and e != 0 and (raw & 16)  != 0: collapsed |= 16
	if s != 0 and e != 0 and (raw & 32)  != 0: collapsed |= 32
	if s != 0 and w != 0 and (raw & 64)  != 0: collapsed |= 64
	if n != 0 and w != 0 and (raw & 128) != 0: collapsed |= 128
	return collapsed


func _default_bitmask_template_path() -> String:
	return "uid://mmls24qo7tlb"


func _fallback_atlas_grid_size() -> Vector2i:
	return Vector2i(7, 7)
