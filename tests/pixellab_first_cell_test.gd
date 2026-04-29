## D-89 first-cell row-major pick contract test for both PIXLAB layouts.
##
## For each of the 16 4-bit corner masks, asserts that
## PentaTileLayoutPixelLabTopDown.mask_to_atlas(m).atlas_coords matches the
## hand-derived row-major-first cell whose role maps to m. Same for
## PentaTileLayoutPixelLabSideScroller.
##
## Hand-derived expected tables are in this file as constants. They are the
## authoritative source for the cache contract — if Plans 02/03's
## _CELL_TO_ROLE or _ROLE_TO_MASK ever drift, this test goes red.
##
## Also asserts:
##   - transform_flags == 0 for every dispatch (D-90: no rotation reuse)
##   - alternative_tile == 0 for every dispatch
##   - mask=0 specifically: top-down → (2, 2), side-scroller → (0, 0) (D-104,
##     Pitfall #9 single-grid mask=0 is NOT erase)
##
## Verify-the-regression cycle (CLAUDE.md Test Methodology #5):
## stash the body of _init_cache in either layout (replace with `pass`),
## rerun, confirm 16 failures (one per mask) for that layout. Restore.
##
## Run headless:
##   Godot --headless --path . --script addons/penta_tile/tests/pixellab_first_cell_test.gd
extends SceneTree

const _TopDownSc      = preload("res://addons/penta_tile/layouts/penta_tile_layout_pixel_lab_top_down.gd")
const _SideScrollerSc = preload("res://addons/penta_tile/layouts/penta_tile_layout_pixel_lab_side_scroller.gd")

# Hand-derived from row-major scan of _CELL_TO_ROLE × _ROLE_TO_MASK.
# See planning/phases/03.5-.../03.5-02-PLAN.md and 03.5-03-PLAN.md for derivations.
const _EXPECTED_TOP_DOWN := {
	 0: Vector2i(2, 2),  1: Vector2i(4, 2),  2: Vector2i(3, 2),  3: Vector2i(2, 1),
	 4: Vector2i(2, 4),  5: Vector2i(1, 2),  6: Vector2i(4, 4),  7: Vector2i(1, 1),
	 8: Vector2i(4, 3),  9: Vector2i(2, 5), 10: Vector2i(6, 2), 11: Vector2i(3, 1),
	12: Vector2i(5, 3), 13: Vector2i(1, 4), 14: Vector2i(6, 3), 15: Vector2i(0, 0),
}

const _EXPECTED_SIDE_SCROLLER := {
	 0: Vector2i(0, 0),  1: Vector2i(4, 2),  2: Vector2i(1, 2),  3: Vector2i(5, 1),
	 4: Vector2i(0, 1),  5: Vector2i(0, 2),  6: Vector2i(4, 1),  7: Vector2i(3, 5),
	 8: Vector2i(4, 0),  9: Vector2i(3, 7), 10: Vector2i(6, 2), 11: Vector2i(6, 1),
	12: Vector2i(5, 0), 13: Vector2i(0, 4), 14: Vector2i(4, 7), 15: Vector2i(7, 1),
}

var _failures: Array = []


func _initialize() -> void:
	print("=== pixellab_first_cell_test ===")

	_check_layout("PixelLabTopDown", _TopDownSc.new(), _EXPECTED_TOP_DOWN, Vector2i(2, 2))
	_check_layout("PixelLabSideScroller", _SideScrollerSc.new(), _EXPECTED_SIDE_SCROLLER, Vector2i(0, 0))

	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d):" % _failures.size())
		for f: String in _failures:
			printerr("  - " + f)
		quit(1)


func _check_layout(label: String, layout: PentaTileLayout, expected: Dictionary, mask0_expected: Vector2i) -> void:
	# is_dual_grid invariant (D-96)
	if layout.is_dual_grid():
		_failures.append("%s: is_dual_grid()=true; expected false (D-96)" % label)

	# 16-mask coverage — every mask returns the locked first-cell coord.
	for mask in range(16):
		var slot: PentaTileAtlasSlot = layout.mask_to_atlas(mask)
		if slot == null:
			_failures.append("%s: mask=%d returned null (Pitfall #9 violation: single-grid mask=0 must dispatch)" % [label, mask])
			continue
		var got: Vector2i = slot.atlas_coords
		var want: Vector2i = expected[mask]
		if got != want:
			_failures.append("%s: mask=%d atlas_coords=%s; expected %s" % [label, mask, got, want])
		if slot.transform_flags != 0:
			_failures.append("%s: mask=%d transform_flags=%d; expected 0 (D-90 forbids rotation reuse for PIXLAB)" % [label, mask, slot.transform_flags])
		if slot.alternative_tile != 0:
			_failures.append("%s: mask=%d alternative_tile=%d; expected 0" % [label, mask, slot.alternative_tile])

	# mask=0 specific (D-104). Redundant with the loop above but kept explicit
	# so a regression reads loud in the failure list.
	var slot0: PentaTileAtlasSlot = layout.mask_to_atlas(0)
	if slot0 == null:
		_failures.append("%s: mask_to_atlas(0) returned null — D-104 + Pitfall #9 violation" % label)
	elif slot0.atlas_coords != mask0_expected:
		_failures.append("%s: mask_to_atlas(0).atlas_coords=%s; expected %s (D-104)" % [label, slot0.atlas_coords, mask0_expected])
