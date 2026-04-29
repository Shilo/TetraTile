## Strict bounds test for every bundled bitmask greybox PNG.
##
## For each layout's bundled bitmask greybox, defines the EXPECTED silhouette
## per atlas slot — a set of pixel rectangles inside the slot that MUST be
## fully opaque, with everything else inside the slot MUST be fully transparent.
## Catches two failure modes the user reported:
##
##   1. "transparent segments inside a tile" — a slot has opaque pixels but
##      not the full silhouette. (E.g. Min3x3/Wang2Edge slots that are
##      supposed to be solid 32x32 but have corner cuts.)
##
##   2. "drawing outside of the bounds" — a slot has opaque pixels in regions
##      that should be transparent (bleed into neighbouring atlas slots, or
##      a Penta archetype painting past its expected sub-region).
##
## Layouts covered:
##   - Wang2Edge (4×4): every slot = full 32x32 solid.
##   - Min3x3 (3×3): every slot = full 32x32 solid.
##   - DualGrid16 (4×4): each slot = union of corner quadrants per its corner
##     mask (TL=1, TR=2, BL=4, BR=8). mask=0 has nothing; mask=15 is solid.
##   - Wang2Corner (4×4): visually identical to DualGrid16 (gen_wang_2_corner
##     in the python generator returns gen_dual_grid_16's image).
##   - Penta (1..5 tiles per axis): per-archetype expected silhouette.
##     Slot 0 = BL quadrant 16x16. Slot 1 = full 32x32. Slot 2 = bottom half
##     32x16. Slot 3 = L-shape (TL+BL+BR quadrants). Slot 4 = TL+BR quadrants.
##   - Blob47Godot (7×7): 47 used + 2 unused cells (BorisTheBrave canonical
##     packing — D-74). Used cells = full 32x32 solid; cells (5,6)/(6,6) are
##     intentional transparent gaps (passed via `gap_cells` whitelist).
##
## Run headless:
##   Godot --headless --path . --script addons/penta_tile/tests/bitmask_bounds_test.gd
extends SceneTree

const _TILE := 32
const _HALF := 16

var _failures: Array = []


func _initialize() -> void:
	print("=== bitmask_bounds_test ===")

	_check_atlas("Wang2Edge",
		"res://addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.png",
		Vector2i(4, 4),
		_wang_2_edge_silhouette)

	_check_atlas("Min3x3",
		"res://addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.png",
		Vector2i(3, 3),
		_min_3x3_silhouette)

	_check_atlas("DualGrid16",
		"res://addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.png",
		Vector2i(4, 4),
		_corner_mask_silhouette)

	_check_atlas("Wang2Corner",
		"res://addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.png",
		Vector2i(4, 4),
		_wang_2_corner_silhouette)

	# Penta variants: 5 modes × 2 axes. Each mode has N tiles (slot 0..N-1).
	var mode_names: Array = ["one", "two", "three", "four", "five"]
	for mode_int in range(1, 6):
		var mode_name: String = mode_names[mode_int - 1]
		for axis: String in ["horizontal", "vertical"]:
			var grid: Vector2i = Vector2i(mode_int, 1) if axis == "horizontal" else Vector2i(1, mode_int)
			var label := "Penta_%s_%s" % [mode_name, axis]
			_check_atlas(label,
				"res://addons/penta_tile/layouts/penta_tile_layout_penta/%s_%s.png" % [mode_name, axis],
				grid,
				_penta_silhouette)

	# Blob47Godot (Phase 3 Plan 04) — 7×7 atlas, 47 used + 2 unused cells.
	# Cells (5,6) and (6,6) are intentional transparent gaps (BorisTheBrave
	# canonical packing — D-74). Every other cell MUST be a fully solid 32×32
	# silhouette (mirrors gen_wang_2_corner — the mask differentiator is atlas
	# position, not pixel composition).
	var blob_47_godot_gaps: Array[Vector2i] = [Vector2i(5, 6), Vector2i(6, 6)]
	_check_atlas("Blob47Godot",
		"res://addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.png",
		Vector2i(7, 7),
		_solid_silhouette,
		blob_47_godot_gaps)

	# PixelLab Top-Down + Side-Scroller (Phase 3.5 Plan 04) — 8×8 atlas with
	# solid 32×32 silhouettes per slot (D-101 option B fallback — switched
	# from option A after comprehensive_bitmask_test exposed the single-grid
	# solidity violation: partial-quadrant silhouettes left isolated cells
	# rendering at 25-75% coverage instead of 100%). Same convention as
	# Wang2Corner + Blob47Godot — single-grid layouts encode mask via atlas
	# POSITION (which cell first-cell-pick selected), not silhouette shape.
	_check_atlas("PixelLabTopDown",
		"res://addons/penta_tile/layouts/penta_tile_layout_pixel_lab_top_down.png",
		Vector2i(8, 8),
		_solid_silhouette)

	_check_atlas("PixelLabSideScroller",
		"res://addons/penta_tile/layouts/penta_tile_layout_pixel_lab_side_scroller.png",
		Vector2i(8, 8),
		_solid_silhouette)

	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		quit(1)


# Verify every slot of an atlas matches its expected silhouette.
# `silhouette_fn(grid, slot_index_x, slot_index_y) -> Array[Rect2i]`
# returns a list of EXPECTED-OPAQUE rectangles (in slot-local pixel coords).
#
# `gap_cells` — whitelist of intentional transparent atlas slots (e.g.
# Blob47Godot's (5,6)/(6,6) unused cells in BorisTheBrave's canonical 7×7
# packing). Cells listed in `gap_cells` are SKIPPED entirely during opacity
# inspection; ALL other cells in the grid MUST be inspected. Per Phase 3
# Plan 06 W-3 fix: the per-slot inspection loop is REQUIRED — there is NO
# universal `Callable()` skip option. Skipping all per-slot inspection
# would miss atlas-occupancy mismatches (a slot the silhouette_fn expects
# opaque but ships transparent in the PNG, or vice-versa).
func _check_atlas(label: String, path: String, grid: Vector2i, silhouette_fn: Callable, gap_cells: Array[Vector2i] = []) -> void:
	print("\n--- " + label + " ---")
	var tex: Texture2D = load(path)
	if tex == null:
		_record(label, "could not load " + path)
		return
	var img: Image = tex.get_image()
	if img == null:
		_record(label, "texture has no image data")
		return
	var expected_w: int = grid.x * _TILE
	var expected_h: int = grid.y * _TILE
	if img.get_width() != expected_w or img.get_height() != expected_h:
		_record(label, "atlas size %dx%d != expected %dx%d for grid %s" % [img.get_width(), img.get_height(), expected_w, expected_h, str(grid)])
		return

	# 1. Out-of-bounds atlas check: the atlas's total pixel count is exactly
	#    grid.x * grid.y * tile_size pixels. Anything beyond that is OOB.
	#    (Trivially satisfied by the size check above — pixels beyond
	#    img.get_width()/get_height() can't exist. Recorded for clarity.)

	# Build a fast-lookup set of gap cells (skipped during inspection).
	var gap_set: Dictionary = {}
	for g: Vector2i in gap_cells:
		gap_set[g] = true

	var bounds_failures := 0
	var fullness_failures := 0
	var first_bounds_fail: Variant = null
	var first_fullness_fail: Variant = null

	for sy in range(grid.y):
		for sx in range(grid.x):
			# Skip whitelisted intentional-gap cells entirely. EVERY other
			# cell is inspected (per W-3: no universal Callable() skip).
			if gap_set.has(Vector2i(sx, sy)):
				continue
			var x0: int = sx * _TILE
			var y0: int = sy * _TILE
			var expected_rects: Array = silhouette_fn.call(grid, sx, sy)
			# Verify every pixel in the slot.
			for py in range(_TILE):
				for px in range(_TILE):
					var alpha := img.get_pixel(x0 + px, y0 + py).a
					var expected_opaque := _is_in_any_rect(px, py, expected_rects)
					var actual_opaque := alpha > 0.01
					if expected_opaque and not actual_opaque:
						# Pixel inside expected silhouette is transparent.
						fullness_failures += 1
						if first_fullness_fail == null:
							first_fullness_fail = "slot (%d,%d) px (%d,%d) expected opaque (in rect) but alpha=%.2f" % [sx, sy, px, py, alpha]
					elif not expected_opaque and actual_opaque:
						# Pixel outside expected silhouette is opaque (bleed).
						bounds_failures += 1
						if first_bounds_fail == null:
							first_bounds_fail = "slot (%d,%d) px (%d,%d) opaque (alpha=%.2f) but outside expected silhouette" % [sx, sy, px, py, alpha]

	if bounds_failures > 0:
		_record(label, "%d pixels are opaque OUTSIDE the expected silhouette (bleed/over-draw) — first: %s" % [bounds_failures, first_bounds_fail])
	if fullness_failures > 0:
		_record(label, "%d pixels are TRANSPARENT inside the expected silhouette (incomplete fill) — first: %s" % [fullness_failures, first_fullness_fail])

	var inspected: int = grid.x * grid.y - gap_set.size()
	print("  %s grid=%s slots=%d (inspected=%d gaps=%d) bounds_fails=%d fullness_fails=%d" % [label, str(grid), grid.x * grid.y, inspected, gap_set.size(), bounds_failures, fullness_failures])


# Generic solid 32×32 silhouette — used by single-grid layouts whose mask
# differentiator is atlas POSITION rather than pixel composition (e.g.
# Wang2Corner, Blob47Godot). Mirrors the gen_wang_2_corner generator's
# convention.
func _solid_silhouette(_grid: Vector2i, _sx: int, _sy: int) -> Array:
	return [Rect2i(0, 0, _TILE, _TILE)]


# Wang2Edge / Min3x3 silhouette: every atlas slot is a fully solid 32x32 fill.
# Background extension is suppressed at the LAYER level (single-grid cells
# only render if they're logic-painted), so the source greybox doesn't need
# corner cuts to encode "this is at an outer corner" — painted regions
# render as clean rectangles aligned to user-painted cells.
func _wang_2_edge_silhouette(_grid: Vector2i, _sx: int, _sy: int) -> Array:
	return [Rect2i(0, 0, _TILE, _TILE)]


func _min_3x3_silhouette(_grid: Vector2i, _sx: int, _sy: int) -> Array:
	return [Rect2i(0, 0, _TILE, _TILE)]


# Wang2Corner is single-grid (each painted logic cell renders one solid 32x32
# tile selected by its corner mask). Same expected silhouette as Wang2Edge /
# Min3x3 — fully solid 32x32 per slot.
func _wang_2_corner_silhouette(_grid: Vector2i, _sx: int, _sy: int) -> Array:
	return [Rect2i(0, 0, _TILE, _TILE)]


# Corner-mask silhouette: the slot's mask = sx + sy * 4. Each set bit fills
# one quadrant. Bit 1=TL, bit 2=TR, bit 4=BL, bit 8=BR (matches the python
# generator's draw_corner_mask).
func _corner_mask_silhouette(grid: Vector2i, sx: int, sy: int) -> Array:
	var mask: int = sx + sy * grid.x
	var rects: Array = []
	if mask & 1:
		rects.append(Rect2i(0, 0, _HALF, _HALF))                # TL
	if mask & 2:
		rects.append(Rect2i(_HALF, 0, _HALF, _HALF))            # TR
	if mask & 4:
		rects.append(Rect2i(0, _HALF, _HALF, _HALF))            # BL
	if mask & 8:
		rects.append(Rect2i(_HALF, _HALF, _HALF, _HALF))        # BR
	return rects


# Penta archetype silhouette: the slot index along the strip determines the
# archetype. 0=IsolatedCell (BL 16x16), 1=Fill (full 32x32), 2=Border (bottom
# half 32x16), 3=InnerCorner (TL+BL+BR quadrants), 4=OppositeCorners (TL+BR).
# Strip orientation (horizontal vs vertical) affects which grid axis carries
# the slot index — we infer from grid shape.
func _penta_silhouette(grid: Vector2i, sx: int, sy: int) -> Array:
	var slot: int = sx if grid.y == 1 else sy
	match slot:
		0:
			# IsolatedCell: BL quadrant only.
			return [Rect2i(0, _HALF, _HALF, _HALF)]
		1:
			# Fill: full 32x32.
			return [Rect2i(0, 0, _TILE, _TILE)]
		2:
			# Border: bottom half 32x16.
			return [Rect2i(0, _HALF, _TILE, _HALF)]
		3:
			# InnerCorner: left half (TL+BL = 16x32) + BR quadrant.
			return [
				Rect2i(0, 0, _HALF, _TILE),
				Rect2i(_HALF, _HALF, _HALF, _HALF),
			]
		4:
			# OppositeCorners: TL + BR quadrants.
			return [
				Rect2i(0, 0, _HALF, _HALF),
				Rect2i(_HALF, _HALF, _HALF, _HALF),
			]
		_:
			return []


func _is_in_any_rect(px: int, py: int, rects: Array) -> bool:
	for r: Rect2i in rects:
		if px >= r.position.x and px < r.position.x + r.size.x and py >= r.position.y and py < r.position.y + r.size.y:
			return true
	return false


func _record(label: String, msg: String) -> void:
	_failures.append("[" + label + "] " + msg)
	printerr("  FAIL " + label + ": " + msg)
