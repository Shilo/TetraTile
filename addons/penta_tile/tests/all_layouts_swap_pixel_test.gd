## End-to-end pixel verification of layout swaps across ALL 5 layouts.
##
## Catches bugs that the simpler layout_swap_test missed: per-cell pixel
## opacity, visual_layer offset correctness, dispatch-coord-in-atlas
## verification, AND multi-cell coherence (painted region renders as a
## continuous shape, not disconnected mini-tiles).
##
## Strategy: paint a deterministic 12×8 logic-cell rectangle. For each
## (from, to) layout pair (25 combos for 5 layouts):
##   1. Build layer with `from` layout
##   2. Paint the rectangle, capture initial state
##   3. Swap to `to` layout
##   4. Trigger rebuild
##   5. Assert per-cell:
##      a. Atlas coord exists in the new layout's tile_set source
##      b. Source pixel content at that atlas coord is non-zero (won't
##         render as transparent)
##      c. Visual layer position matches the new layout's is_dual_grid
##         (offset -tile_size/2 if dual_grid, else Vector2.ZERO)
##   6. Assert per-region (5+ painted display cells in interior):
##      a. Interior cells (cells with all 4 mask bits set in dual-grid,
##         or all 4 cardinal in single-grid) must dispatch to coords
##         representing the "fully surrounded" tile for that layout.
##      b. The rendered atlas tiles for adjacent interior cells must
##         tile coherently — no isolated mini-tile artifact in the
##         middle of a filled region.
##
## Run headless:
##   Godot --headless --path . --script addons/penta_tile/tests/all_layouts_swap_pixel_test.gd
extends SceneTree

const _LayerScript     = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _PentaScript     = preload("res://addons/penta_tile/layouts/penta_tile_layout_penta.gd")
const _DualGrid16Sc    = preload("res://addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd")
const _Wang2EdgeSc     = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd")
const _Wang2CornerSc   = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd")
const _Min3x3Sc        = preload("res://addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd")

var _failures: Array = []

# 12×8 rectangle (matches user's UAT pattern).
var _PAINT_CELLS: Array = _build_paint_pattern()


func _build_paint_pattern() -> Array:
	var out: Array = []
	for x in range(-1, 11):
		for y in range(-1, 7):
			out.append(Vector2i(x, y))
	return out


func _initialize() -> void:
	print("=== all_layouts_swap_pixel_test ===")

	var layouts := [
		["Penta",       _PentaScript],
		["DualGrid16",  _DualGrid16Sc],
		["Wang2Edge",   _Wang2EdgeSc],
		["Wang2Corner", _Wang2CornerSc],
		["Min3x3",      _Min3x3Sc],
	]

	# 1. Sanity: each layout PAINTED FRESH (no swap) must render correctly.
	#    This catches regressions BEFORE testing swaps.
	for entry: Array in layouts:
		await _test_fresh(entry[0], entry[1])

	# 2. Swap matrix: every from->to pair (25 total).
	for from_entry: Array in layouts:
		for to_entry: Array in layouts:
			if from_entry[0] == to_entry[0]:
				continue                                                                # skip identity swap
			await _test_swap(from_entry[0], from_entry[1], to_entry[0], to_entry[1])

	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		quit(1)


func _test_fresh(name: String, layout_script) -> void:
	print("\n--- fresh: " + name + " ---")
	var layer = _LayerScript.new()
	layer.layout = layout_script.new()
	get_root().add_child(layer)
	await process_frame
	await process_frame
	for c: Vector2i in _PAINT_CELLS:
		layer.set_cell(c, 0, Vector2i(0, 0))
	await process_frame
	await process_frame
	if layer.has_method("rebuild"):
		layer.rebuild()
	await process_frame
	_verify_layer(layer, "fresh: " + name)
	layer.queue_free()


func _test_swap(from_name: String, from_script, to_name: String, to_script) -> void:
	var label := from_name + " -> " + to_name
	var layer = _LayerScript.new()
	layer.layout = from_script.new()
	get_root().add_child(layer)
	await process_frame
	await process_frame
	for c: Vector2i in _PAINT_CELLS:
		layer.set_cell(c, 0, Vector2i(0, 0))
	await process_frame
	await process_frame
	if layer.has_method("rebuild"):
		layer.rebuild()
	await process_frame

	# Swap layout.
	layer.layout = to_script.new()
	await process_frame
	await process_frame
	if layer.has_method("rebuild"):
		layer.rebuild()
	await process_frame

	_verify_layer(layer, label)
	layer.queue_free()


# Pixel-level verification of every painted display cell.
func _verify_layer(layer: Node, label: String) -> void:
	var primary = layer.get("_primary_layer")
	if primary == null:
		_record(label, "_primary_layer is null")
		return

	var painted: Array = primary.get_used_cells()
	if painted.size() == 0:
		_record(label, "0 visual cells painted (entire region disappeared)")
		return

	# Effective tile_set the visual layer renders from.
	var eff_ts: TileSet = primary.tile_set
	if eff_ts == null or eff_ts.get_source_count() == 0:
		_record(label, "visual layer has no tile_set / no atlas source")
		return
	var eff_src := eff_ts.get_source(0) as TileSetAtlasSource
	if eff_src == null:
		_record(label, "visual layer source 0 not a TileSetAtlasSource")
		return
	var atlas_img: Image = eff_src.texture.get_image() if eff_src.texture else null
	var tile_size: Vector2i = eff_src.texture_region_size

	# Verify visual_layer position matches is_dual_grid expectation.
	var is_dual_grid: bool = layer.layout.is_dual_grid()
	var expected_pos: Vector2 = (Vector2(layer.tile_set.tile_size) * -0.5) if is_dual_grid else Vector2.ZERO
	if primary.position != expected_pos:
		_record(label, "visual layer position %s != expected %s for is_dual_grid=%s" % [primary.position, expected_pos, str(is_dual_grid)])

	# Strict bbox assertion. For SINGLE-GRID layouts the visual layer must NOT
	# render any cell outside the user-painted logic region — the layer-level
	# fix in penta_tile_map_layer._paint_via_layout skips non-logic-painted
	# single-grid cells, so single-bit-mask "background extension" cells stay
	# unrendered and the painted region's bbox matches the user's painted
	# bounds exactly. (Dual-grid layouts paint a 13x9 display grid for a 12x8
	# logic region by design — their perimeter display cells fill INNER
	# quadrants that fall inside the painted logic bounds, net effect a clean
	# rectangle.)
	if not is_dual_grid:
		var min_painted := Vector2i(-1, -1)
		var max_painted := Vector2i(10, 6)
		var bbox_failures := 0
		var first_bbox_fail: Variant = null
		for cell: Vector2i in painted:
			if cell.x < min_painted.x or cell.x > max_painted.x or cell.y < min_painted.y or cell.y > max_painted.y:
				bbox_failures += 1
				if first_bbox_fail == null:
					first_bbox_fail = "cell %s outside user-painted bounds %s..%s" % [cell, min_painted, max_painted]
		if bbox_failures > 0:
			_record(label, "%d visual cells rendered OUTSIDE the user-painted region — single-grid layouts must only render logic-painted cells (first: %s)" % [bbox_failures, first_bbox_fail])

	# Per-cell SOLIDITY assertion (single-grid layouts only).
	#
	# In single-grid layouts every painted logic cell IS a display cell, so its
	# dispatched tile must be fully opaque (100% coverage) — partial-quadrant
	# fills leave visible gaps where the unfilled quadrants don't connect to
	# adjacent cells (UAT screenshot of Wang2Corner: alternating-square stripe
	# along the painted region's outer edge).
	#
	# Dual-grid layouts intentionally use partial-quadrant fills (4 display cells
	# per painted logic cell, with quadrants summing to a clean rectangle); the
	# interior coverage check (mask=15 = 100%) covers them.
	if not is_dual_grid and atlas_img != null:
		var solidity_fails := 0
		var first_solidity_fail: Variant = null
		for cell: Vector2i in painted:
			var ac4: Vector2i = primary.get_cell_atlas_coords(cell)
			if not eff_src.has_tile(ac4):
				continue
			var ax4: int = ac4.x * tile_size.x
			var ay4: int = ac4.y * tile_size.y
			var op := 0
			var total: int = tile_size.x * tile_size.y
			for py in range(tile_size.y):
				for px in range(tile_size.x):
					if atlas_img.get_pixel(ax4 + px, ay4 + py).a > 0.01:
						op += 1
			if op < total:
				solidity_fails += 1
				if first_solidity_fail == null:
					var pct: float = 100.0 * float(op) / float(max(1, total))
					first_solidity_fail = "cell %s atlas %s coverage %.1f%% (must be 100%%)" % [cell, ac4, pct]
		if solidity_fails > 0:
			_record(label, "%d painted cells dispatch to non-solid atlas tiles — single-grid layouts need full-32x32 fills, not partial quadrants (first: %s)" % [solidity_fails, first_solidity_fail])

	# Per-cell verification.
	var unrenderable_atlas := 0
	var transparent_atlas := 0
	var first_unrenderable: Variant = null
	var first_transparent: Variant = null

	for cell: Vector2i in painted:
		var ac: Vector2i = primary.get_cell_atlas_coords(cell)
		if not eff_src.has_tile(ac):
			unrenderable_atlas += 1
			if first_unrenderable == null:
				first_unrenderable = "cell %s atlas %s" % [cell, ac]
			continue                                                                  # skip pixel check if atlas missing

		# Pixel-opacity check on the dispatched tile region.
		if atlas_img != null:
			var x0: int = ac.x * tile_size.x
			var y0: int = ac.y * tile_size.y
			var any_opaque := false
			for py in range(tile_size.y):
				for px in range(tile_size.x):
					if atlas_img.get_pixel(x0 + px, y0 + py).a > 0.01:
						any_opaque = true
						break
				if any_opaque:
					break
			if not any_opaque:
				transparent_atlas += 1
				if first_transparent == null:
					first_transparent = "cell %s atlas %s" % [cell, ac]

	if unrenderable_atlas > 0:
		_record(label, "%d cells dispatch to non-registered atlas coords (first: %s)" % [unrenderable_atlas, first_unrenderable])
	if transparent_atlas > 0:
		_record(label, "%d cells dispatch to fully-transparent atlas tiles (first: %s)" % [transparent_atlas, first_transparent])

	# Coherence sanity: for a 12x8 painted block, interior cells should ALL
	# dispatch to the SAME atlas coord (the "fully surrounded" tile for the
	# layout). Find an interior cell (one whose mask = "all 4 bits set") and
	# verify >= 5 painted cells share that atlas coord.
	#
	# For dual-grid layouts: interior mask = 15. For Wang2Edge / Min3x3: same.
	# For Wang2Corner: interior mask = 15 (corner-mask, 4 bits all set when
	#                  all 4 diagonal neighbors painted).
	var sample_fn := Callable(layer, "_has_logic_cell")
	var interior_atlas_counts: Dictionary = {}
	for cell: Vector2i in painted:
		var mask: int = layer.layout.compute_mask(cell, sample_fn)
		if mask == 15:
			var ac: Vector2i = primary.get_cell_atlas_coords(cell)
			interior_atlas_counts[ac] = interior_atlas_counts.get(ac, 0) + 1
	# Expect at least 5 interior cells dispatching to the same atlas coord.
	var max_interior_count := 0
	for k: Vector2i in interior_atlas_counts.keys():
		if interior_atlas_counts[k] > max_interior_count:
			max_interior_count = interior_atlas_counts[k]
	if max_interior_count < 5 and painted.size() > 50:
		_record(label, "interior cells (mask=15) don't share a single atlas coord — %s — suggests dispatch fragmentation" % str(interior_atlas_counts))

	# Interior-tile coverage assertion: for a fully-surrounded cell (mask=15),
	# the dispatched tile should be MOSTLY OPAQUE so adjacent interior cells
	# tile into a continuous filled region. Anything below ~80% leaves
	# transparent gaps between cells (e.g. plus-pattern tiles with transparent
	# corners → visible dark squares between adjacent fills, breaking the
	# illusion of a coherent painted region). This is the visual artifact the
	# user reports for Min3x3 / Wang2Edge.
	var interior_atlas: Vector2i = Vector2i(-1, -1)
	for k: Vector2i in interior_atlas_counts.keys():
		if interior_atlas_counts[k] == max_interior_count:
			interior_atlas = k
			break
	var interior_coverage_pct := 0.0
	if interior_atlas != Vector2i(-1, -1) and atlas_img != null:
		var ix0: int = interior_atlas.x * tile_size.x
		var iy0: int = interior_atlas.y * tile_size.y
		var op := 0
		var total: int = tile_size.x * tile_size.y
		for py in range(tile_size.y):
			for px in range(tile_size.x):
				if atlas_img.get_pixel(ix0 + px, iy0 + py).a > 0.01:
					op += 1
		interior_coverage_pct = 100.0 * op / max(1, total)
		if interior_coverage_pct < 80.0 and max_interior_count >= 5:
			_record(label, "interior tile %s coverage %.0f%% < 80%% — adjacent cells will leave visible transparent gaps when tiled (plus-pattern with hollow corners)" % [interior_atlas, interior_coverage_pct])

	# Per-cell EDGE-CONTINUITY assertion (cardinal-edge mask layouts only).
	#
	# For every painted cell, check the 4 edges of its dispatched tile against
	# its mask: any edge facing a painted neighbor (mask bit set on that side)
	# MUST be mostly opaque, otherwise the seam between this cell and that
	# neighbor leaves a visible transparent gap (the dark squares between
	# adjacent cells in the user's screenshot).
	#
	# Gated to Min3x3 + Wang2Edge — the layouts whose compute_mask uses
	# CARDINAL neighbors with bit convention N/T=1, E=2, S/B=4, W=8. Other
	# layouts use corner masks (TL/TR/BL/BR or NE/SE/SW/NW diagonals) where
	# bits don't map to cell edges:
	#   - DualGrid16, Penta: dual-grid corner mask → interior coverage check
	#     (mask=15 ≥ 80%) covers continuity instead.
	#   - Wang2Corner: single-grid but DIAGONAL-neighbor mask. Has its own
	#     unrelated coherence concern (cardinal seams not encoded in mask)
	#     that needs a separate test design.
	var script_path: String = layer.layout.get_script().resource_path
	var is_cardinal_edge_layout: bool = (
		script_path.ends_with("penta_tile_layout_minimal_3x3.gd") or
		script_path.ends_with("penta_tile_layout_wang_2_edge.gd")
	)
	var edge_failures := 0
	var first_edge_fail: Variant = null
	if is_cardinal_edge_layout and atlas_img != null:
		var sample_fn2 := Callable(layer, "_has_logic_cell")
		# (name, mask_bit, px0, py0, px1, py1) — all coords are within-tile pixels.
		var edges := [
			["N", 1, 0, 0, tile_size.x - 1, 0],
			["E", 2, tile_size.x - 1, 0, tile_size.x - 1, tile_size.y - 1],
			["S", 4, 0, tile_size.y - 1, tile_size.x - 1, tile_size.y - 1],
			["W", 8, 0, 0, 0, tile_size.y - 1],
		]
		for cell: Vector2i in painted:
			var ac2: Vector2i = primary.get_cell_atlas_coords(cell)
			if not eff_src.has_tile(ac2):
				continue
			var ax0: int = ac2.x * tile_size.x
			var ay0: int = ac2.y * tile_size.y
			var mask2: int = layer.layout.compute_mask(cell, sample_fn2)
			for e: Array in edges:
				var bit: int = e[1]
				if (mask2 & bit) == 0:
					continue
				var ex0: int = e[2]; var ey0: int = e[3]; var ex1: int = e[4]; var ey1: int = e[5]
				var op := 0; var total := 0
				for py in range(ey0, ey1 + 1):
					for px in range(ex0, ex1 + 1):
						total += 1
						if atlas_img.get_pixel(ax0 + px, ay0 + py).a > 0.01:
							op += 1
				var pct: float = 100.0 * float(op) / float(max(1, total))
				if pct < 80.0:
					edge_failures += 1
					if first_edge_fail == null:
						first_edge_fail = "cell %s mask=%d edge %s atlas %s opacity %.0f%%" % [cell, mask2, e[0], ac2, pct]
		if edge_failures > 0:
			_record(label, "%d cell-edges face a painted neighbor with <80%% opacity along that edge — visible seam (first: %s)" % [edge_failures, first_edge_fail])

	# Output summary line for visibility.
	print("  [%s] painted=%d unrenderable=%d transparent=%d max_interior=%d (atlas %s, %.0f%% coverage) edge_fails=%d pos=%s" % [
		label, painted.size(), unrenderable_atlas, transparent_atlas, max_interior_count, interior_atlas, interior_coverage_pct, edge_failures, primary.position
	])


func _record(label: String, msg: String) -> void:
	_failures.append("[" + label + "] " + msg)
	printerr("  FAIL " + label + ": " + msg)
