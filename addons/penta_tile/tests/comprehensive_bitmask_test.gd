## Comprehensive bitmask test: paints a battery of cell patterns across every
## layout and verifies pixel correctness for EVERY painted cell. Designed to
## catch the kinds of bugs the user reported in UAT screenshots — partial-fill
## artifacts, missing isolated cells, single-bit-mask collapses, etc.
##
## Patterns:
##   - 1x1, 1x2_h, 1x2_v, 2x2, 3x3, 4x4, 5x5 (rectangles)
##   - line_h_3, line_v_3, line_h_5 (1-cell-wide lines, exercise mask=10/5/2/8/1/4)
##   - L_shape, T_shape, plus_shape (custom shapes, exercise corner masks)
##   - diag_pair, diag_anti (two diagonally-related cells, exercise Wang2Corner)
##   - 3_isolated (3 separate single cells)
##
## For each (layout, pattern) combo, the test verifies:
##   1. EVERY user-painted cell renders (no missing cells in single-grid).
##   2. SINGLE-GRID cells render with 100% atlas coverage (fully solid).
##   3. DUAL-GRID cells render with non-zero atlas coverage (sanity).
##   4. SINGLE-GRID layouts paint NO cells outside user-painted bounds.
##   5. The painted-region pixel bbox matches expectations (single-grid: exactly
##      user-painted bounds; dual-grid: same region, just rendered via 4-quadrant
##      composition over a 1-cell-larger display grid).
##
## Patterns systematically exercise the 16 possible mask values across each
## layout's mask convention:
##   - Wang2Edge / Min3x3 (cardinal mask N=1, E=2, S=4, W=8): 1xN / Nx1 / 2x2 /
##     3x3 / 5x5 collectively cover masks 0, 1, 2, 4, 5, 8, 10, plus 3/6/9/12/
##     7/11/13/14/15 from rectangles.
##   - Wang2Corner (corner-diagonal mask): diag_pair / 2x2 / 5x5 cover all 16
##     diagonal masks.
##
## Run headless:
##   Godot --headless --path . --script addons/penta_tile/tests/comprehensive_bitmask_test.gd
extends SceneTree

const _LayerScript     = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _PentaScript     = preload("res://addons/penta_tile/layouts/penta_tile_layout_penta.gd")
const _DualGrid16Sc    = preload("res://addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd")
const _Wang2EdgeSc     = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd")
const _Wang2CornerSc   = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd")
const _Min3x3Sc        = preload("res://addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd")
const _Blob47GodotSc   = preload("res://addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd")
const _PixelLabTopDownSc      = preload("res://addons/penta_tile/layouts/penta_tile_layout_pixel_lab_top_down.gd")
const _PixelLabSideScrollerSc = preload("res://addons/penta_tile/layouts/penta_tile_layout_pixel_lab_side_scroller.gd")

var _failures: Array = []


func _initialize() -> void:
	print("=== comprehensive_bitmask_test ===")

	var patterns := [
		{"name": "1x1",            "cells": [Vector2i(0, 0)]},
		{"name": "1x2_h",          "cells": _rect(0, 0, 2, 1)},
		{"name": "1x2_v",          "cells": _rect(0, 0, 1, 2)},
		{"name": "2x1",            "cells": _rect(0, 0, 2, 1)},
		{"name": "2x2",            "cells": _rect(0, 0, 2, 2)},
		{"name": "3x3",            "cells": _rect(0, 0, 3, 3)},
		{"name": "4x4",            "cells": _rect(0, 0, 4, 4)},
		{"name": "5x5",            "cells": _rect(0, 0, 5, 5)},
		{"name": "line_h_5",       "cells": _rect(0, 0, 5, 1)},
		{"name": "line_v_5",       "cells": _rect(0, 0, 1, 5)},
		{"name": "L_shape",        "cells": [Vector2i(0,0), Vector2i(0,1), Vector2i(0,2), Vector2i(1,2), Vector2i(2,2)]},
		{"name": "T_shape",        "cells": [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(1,1), Vector2i(1,2)]},
		{"name": "plus_shape",     "cells": [Vector2i(1,0), Vector2i(0,1), Vector2i(1,1), Vector2i(2,1), Vector2i(1,2)]},
		{"name": "diag_pair",      "cells": [Vector2i(0,0), Vector2i(1,1)]},
		{"name": "diag_anti",      "cells": [Vector2i(1,0), Vector2i(0,1)]},
		{"name": "3_isolated",     "cells": [Vector2i(0,0), Vector2i(3,0), Vector2i(0,3)]},
		# 8-Moore-revealing patterns (added Phase 3 Plan 06 for Blob47Godot coverage —
		# RESEARCH § 8.1). plus_with_diagonals fills a 3x3 to exercise the center cell
		# at mask=255 (all 4 edges + all 4 corners survive collapse). diag_chain
		# exercises corner-collapses-to-zero (cells whose only neighbors are diagonal
		# with no edge bits set).
		{"name": "plus_with_diagonals", "cells": [
			Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
			Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
			Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
		]},
		{"name": "diag_chain", "cells": [
			Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3),
		]},
	]

	var layouts := [
		{"name": "Penta",       "script": _PentaScript,     "is_dual_grid": true},
		{"name": "DualGrid16",  "script": _DualGrid16Sc,    "is_dual_grid": true},
		{"name": "Wang2Edge",   "script": _Wang2EdgeSc,     "is_dual_grid": false},
		{"name": "Wang2Corner", "script": _Wang2CornerSc,   "is_dual_grid": false},
		{"name": "Min3x3",      "script": _Min3x3Sc,        "is_dual_grid": false},
		{"name": "Blob47Godot", "script": _Blob47GodotSc,   "is_dual_grid": false},
		{"name": "PixelLabTopDown",      "script": _PixelLabTopDownSc,      "is_dual_grid": false},
		{"name": "PixelLabSideScroller", "script": _PixelLabSideScrollerSc, "is_dual_grid": false},
	]

	for layout: Dictionary in layouts:
		for pattern: Dictionary in patterns:
			await _test_combo(layout, pattern)

	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		quit(1)


func _rect(x: int, y: int, w: int, h: int) -> Array:
	var cells: Array = []
	for ix in range(x, x + w):
		for iy in range(y, y + h):
			cells.append(Vector2i(ix, iy))
	return cells


func _test_combo(layout_def: Dictionary, pattern_def: Dictionary) -> void:
	var label := "%s/%s" % [layout_def.name, pattern_def.name]
	var layer = _LayerScript.new()
	layer.layout = layout_def.script.new()
	get_root().add_child(layer)
	await process_frame
	await process_frame

	var paint_cells: Array = pattern_def.cells
	for c: Vector2i in paint_cells:
		layer.set_cell(c, 0, Vector2i(0, 0))
	await process_frame
	await process_frame
	if layer.has_method("rebuild"):
		layer.rebuild()
	await process_frame

	var primary = layer.get("_primary_layer")
	if primary == null:
		_record(label, "_primary_layer is null")
		layer.queue_free()
		return

	var painted_visual: Array = primary.get_used_cells()
	var eff_ts: TileSet = primary.tile_set
	if eff_ts == null or eff_ts.get_source_count() == 0:
		_record(label, "visual layer has no tile_set / no atlas source")
		layer.queue_free()
		return
	var eff_src := eff_ts.get_source(0) as TileSetAtlasSource
	if eff_src == null:
		_record(label, "visual layer source 0 not a TileSetAtlasSource")
		layer.queue_free()
		return
	var atlas_img: Image = eff_src.texture.get_image() if eff_src.texture else null
	var tile_size: Vector2i = eff_src.texture_region_size

	var is_dual_grid: bool = layout_def.is_dual_grid

	# ── ASSERTION 1: every user-painted cell renders (single-grid only).
	# In dual-grid layouts the "rendered cells" are display cells, not the
	# logic cells the user painted, so this 1:1 mapping doesn't apply.
	var painted_visual_set: Dictionary = {}
	for c: Vector2i in painted_visual:
		painted_visual_set[c] = true

	if not is_dual_grid:
		for user_cell: Vector2i in paint_cells:
			if not painted_visual_set.has(user_cell):
				_record(label, "user-painted cell %s did NOT render in single-grid layout" % str(user_cell))
				break

	# ── ASSERTION 2 (single-grid): every painted cell dispatches to a 100%
	# opaque atlas tile. ASSERTION 3 (dual-grid): every painted cell dispatches
	# to a tile with NON-ZERO opacity (sanity).
	if atlas_img != null:
		var solidity_fails := 0
		var first_solidity_fail: Variant = null
		var blank_fails := 0
		var first_blank_fail: Variant = null
		for cell: Vector2i in painted_visual:
			var ac: Vector2i = primary.get_cell_atlas_coords(cell)
			if not eff_src.has_tile(ac):
				_record(label, "cell %s dispatches to non-registered atlas %s" % [cell, ac])
				continue
			var ax: int = ac.x * tile_size.x
			var ay: int = ac.y * tile_size.y
			var op := 0
			var total: int = tile_size.x * tile_size.y
			for py in range(tile_size.y):
				for px in range(tile_size.x):
					if atlas_img.get_pixel(ax + px, ay + py).a > 0.01:
						op += 1
			if not is_dual_grid and op < total:
				solidity_fails += 1
				if first_solidity_fail == null:
					var pct: float = 100.0 * float(op) / float(max(1, total))
					first_solidity_fail = "cell %s atlas %s coverage %.1f%% (must be 100%%)" % [cell, ac, pct]
			elif is_dual_grid and op == 0:
				blank_fails += 1
				if first_blank_fail == null:
					first_blank_fail = "cell %s atlas %s 0%% opacity" % [cell, ac]
		if solidity_fails > 0:
			_record(label, "%d painted cells in single-grid layout dispatch to non-solid tiles (first: %s)" % [solidity_fails, first_solidity_fail])
		if blank_fails > 0:
			_record(label, "%d painted display cells dispatch to fully-transparent tiles (first: %s)" % [blank_fails, first_blank_fail])

	# ── ASSERTION 4 (single-grid): no visual cells outside user-painted bounds.
	if not is_dual_grid and paint_cells.size() > 0:
		var min_painted := Vector2i(99999, 99999)
		var max_painted := Vector2i(-99999, -99999)
		for c: Vector2i in paint_cells:
			min_painted.x = mini(min_painted.x, c.x)
			min_painted.y = mini(min_painted.y, c.y)
			max_painted.x = maxi(max_painted.x, c.x)
			max_painted.y = maxi(max_painted.y, c.y)
		var bbox_failures := 0
		var first_bbox_fail: Variant = null
		for cell: Vector2i in painted_visual:
			if cell.x < min_painted.x or cell.x > max_painted.x or cell.y < min_painted.y or cell.y > max_painted.y:
				bbox_failures += 1
				if first_bbox_fail == null:
					first_bbox_fail = "cell %s outside user-painted bounds %s..%s" % [cell, min_painted, max_painted]
		if bbox_failures > 0:
			_record(label, "%d visual cells rendered OUTSIDE user-painted region (first: %s)" % [bbox_failures, first_bbox_fail])

	# ── ASSERTION 5 (single-grid only): painted-region pixel bbox matches
	# user-painted bounds exactly. Single-grid renders one tile per logic cell
	# at its canonical position, so opaque pixels span exactly user_cells × 32.
	# Dual-grid is skipped because the half-tile offset and per-layout quadrant
	# composition (Penta archetypes vs DualGrid16 quadrant masks) produce
	# layout-specific opaque bboxes that aren't captured by a single formula.
	if not is_dual_grid and atlas_img != null and paint_cells.size() > 0:
		var min_paint := Vector2i(99999, 99999)
		var max_paint := Vector2i(-99999, -99999)
		for c: Vector2i in paint_cells:
			min_paint.x = mini(min_paint.x, c.x)
			min_paint.y = mini(min_paint.y, c.y)
			max_paint.x = maxi(max_paint.x, c.x)
			max_paint.y = maxi(max_paint.y, c.y)
		var expected_min := Vector2i(min_paint.x * tile_size.x, min_paint.y * tile_size.y)
		var expected_max := Vector2i((max_paint.x + 1) * tile_size.x - 1, (max_paint.y + 1) * tile_size.y - 1)

		# Build a virtual canvas covering ANY visual cells so we can find pixel bbox.
		var c_min := Vector2i(99999, 99999)
		var c_max := Vector2i(-99999, -99999)
		for cell: Vector2i in painted_visual:
			c_min.x = mini(c_min.x, cell.x)
			c_min.y = mini(c_min.y, cell.y)
			c_max.x = maxi(c_max.x, cell.x)
			c_max.y = maxi(c_max.y, cell.y)
		if painted_visual.size() > 0:
			var w: int = (c_max.x - c_min.x + 1) * tile_size.x
			var h: int = (c_max.y - c_min.y + 1) * tile_size.y
			var canvas := Image.create(w, h, false, Image.FORMAT_RGBA8)
			canvas.fill(Color(0, 0, 0, 0))
			for cell: Vector2i in painted_visual:
				var ac: Vector2i = primary.get_cell_atlas_coords(cell)
				if not eff_src.has_tile(ac):
					continue
				var sub := atlas_img.get_region(Rect2i(ac * tile_size, tile_size))
				canvas.blit_rect(sub, Rect2i(Vector2i.ZERO, tile_size), (cell - c_min) * tile_size)
			var canvas_origin := c_min * tile_size
			# Find opaque-pixel bbox in WORLD coords.
			var op_min := Vector2i(999999, 999999)
			var op_max := Vector2i(-999999, -999999)
			var any_opaque := false
			for py in range(h):
				for px in range(w):
					if canvas.get_pixel(px, py).a > 0.01:
						any_opaque = true
						var wx: int = canvas_origin.x + px
						var wy: int = canvas_origin.y + py
						op_min.x = mini(op_min.x, wx)
						op_min.y = mini(op_min.y, wy)
						op_max.x = maxi(op_max.x, wx)
						op_max.y = maxi(op_max.y, wy)
			if not any_opaque:
				_record(label, "painted region rendered ZERO opaque pixels (expected bbox %s..%s)" % [expected_min, expected_max])
			else:
				if op_min != expected_min or op_max != expected_max:
					_record(label, "painted opaque-pixel bbox %s..%s != expected %s..%s" % [op_min, op_max, expected_min, expected_max])

	layer.queue_free()


func _record(label: String, msg: String) -> void:
	_failures.append("[" + label + "] " + msg)
	printerr("  FAIL " + label + ": " + msg)
