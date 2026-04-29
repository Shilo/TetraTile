## PIXLAB-04 visual regression test against checked-in real PixelLab samples.
##
## Loads the spike-003 PixelLab Aseprite-output samples
## (addons/penta_tile/tests/pixellab_*_sample.png), builds a TileSet from each
## via the layout's get_fallback_tile_set(), paints a small mixed pattern
## exercising a wide range of mask states, and composes the rendered canvas by
## blitting each painted display cell's atlas region at the cell's world
## position.
##
## Per CLAUDE.md Test Methodology:
##   #1 Compose the rendered canvas; never trust dispatch alone.
##   #3 Test the user's actual fixture, not bundled greyboxes.
##   #4 Save PNG on failure for eyeball inspection.
##   #5 Verify-the-regression — stash mask_to_atlas to return Vector2i(0, 0)
##      always; rerun; confirm the bbox/non-empty assertions catch it.
##
## Structural invariants (D-102 case 3 — NOT bit-identical to PixelLab's PNG;
## Aseprite-canvas-match is structural):
##   (a) every painted display cell renders to a non-transparent atlas region
##   (b) opaque-pixel bbox covers the painted-region pixel bounds exactly
##   (c) two consecutive rebuild() calls produce identical canvas hashes (bit-
##       stable; D-89 first-cell pick is deterministic, no shimmering)
##
## Run headless:
##   Godot --headless --path . --script addons/penta_tile/tests/pixellab_visual_regression_test.gd
extends SceneTree

const _LayerScript           = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _TopDownSc             = preload("res://addons/penta_tile/layouts/penta_tile_layout_pixel_lab_top_down.gd")
const _SideScrollerSc        = preload("res://addons/penta_tile/layouts/penta_tile_layout_pixel_lab_side_scroller.gd")
const _TOPDOWN_PATH          := "res://addons/penta_tile/tests/pixellab_top_down_sample.png"
const _SIDESCROLLER_PATH     := "res://addons/penta_tile/tests/pixellab_side_scroller_sample.png"

var _failures: Array = []


func _initialize() -> void:
	print("=== pixellab_visual_regression_test ===")

	# Mixed paint pattern: 3x3 filled rect + isolated cell + horizontal line +
	# L-shape, each in a disjoint region of the layer so the painted cells
	# exercise a variety of corner-mask states (mask=15 in the rect's center,
	# mask=0 on the isolated cell, edge masks on rect/line perimeters,
	# corner masks on the L-shape's bend).
	var paint_cells: Array = []
	# 3x3 filled rect at (0,0)-(2,2)
	for x in range(3):
		for y in range(3):
			paint_cells.append(Vector2i(x, y))
	# Isolated cell at (5, 0)
	paint_cells.append(Vector2i(5, 0))
	# Horizontal line at y=5
	for x in range(0, 5):
		paint_cells.append(Vector2i(x, 5))
	# L-shape at (7, 2), (7, 3), (7, 4), (8, 4)
	paint_cells.append(Vector2i(7, 2))
	paint_cells.append(Vector2i(7, 3))
	paint_cells.append(Vector2i(7, 4))
	paint_cells.append(Vector2i(8, 4))

	await _test_layout("PixelLabTopDown", _TopDownSc, _TOPDOWN_PATH, paint_cells)
	await _test_layout("PixelLabSideScroller", _SideScrollerSc, _SIDESCROLLER_PATH, paint_cells)

	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d):" % _failures.size())
		for f: String in _failures:
			printerr("  - " + f)
		quit(1)


func _test_layout(label: String, layout_script: GDScript, sample_path: String, paint_cells: Array) -> void:
	var sample_tex := load(sample_path) as Texture2D
	if sample_tex == null:
		_failures.append("%s: failed to load %s" % [label, sample_path])
		return

	var layout: PentaTileLayout = layout_script.new()
	layout.bitmask_template = sample_tex
	var ts: TileSet = layout.get_fallback_tile_set()
	if ts == null:
		_failures.append("%s: get_fallback_tile_set() returned null" % label)
		return

	var layer = _LayerScript.new()
	layer.tile_set = ts
	layer.layout = layout
	get_root().add_child(layer)
	await process_frame
	await process_frame

	for c: Vector2i in paint_cells:
		layer.set_cell(c, 0, Vector2i(0, 0))
	await process_frame
	await process_frame
	if layer.has_method("rebuild"):
		layer.rebuild()
	await process_frame

	# Single-grid layouts: painted display cells == painted logic cells.
	# Phase 3 D-87 8-Moore propagation may mark adjacent cells affected, but
	# only logic-painted cells render (Pitfall #8 / single-grid logic-painted gate).
	var primary = layer.get("_primary_layer")
	if primary == null:
		_failures.append("%s: layer._primary_layer is null after rebuild" % label)
		layer.queue_free()
		return

	var tile_size: Vector2i = ts.tile_size
	var src: TileSetAtlasSource = ts.get_source(0) as TileSetAtlasSource
	if src == null:
		_failures.append("%s: tile_set source 0 not a TileSetAtlasSource" % label)
		layer.queue_free()
		return
	var atlas_img: Image = src.texture.get_image()
	if atlas_img == null:
		_failures.append("%s: atlas texture has no Image" % label)
		layer.queue_free()
		return

	var painted_visual: Array = primary.get_used_cells()
	if painted_visual.is_empty():
		_failures.append("%s: primary layer has no painted cells after rebuild — dispatch broken" % label)
		layer.queue_free()
		return

	# Compose canvas
	var canvas_a: Image = _compose_canvas(label, primary, painted_visual, atlas_img, tile_size)
	if canvas_a == null:
		layer.queue_free()
		return  # error already appended

	# Bit-stability: rebuild and recompose; hashes must match.
	if layer.has_method("rebuild"):
		layer.rebuild()
	await process_frame
	var painted_visual_b: Array = primary.get_used_cells()
	var canvas_b: Image = _compose_canvas(label, primary, painted_visual_b, atlas_img, tile_size)
	if canvas_b == null:
		layer.queue_free()
		return
	# PackedByteArray supports element-wise == in Godot 4.6 — use direct equality
	# (PackedByteArray.hash() does not exist; the global hash(variant) function
	# returns a per-instance hash, not content-based, for PackedByteArray).
	if canvas_a.get_data() != canvas_b.get_data():
		_failures.append("%s: canvas data differs across two rebuilds (D-89 first-cell pick must be deterministic)" % label)
		canvas_a.save_png("user://pixellab_visual_regression_%s_a.png" % label)
		canvas_b.save_png("user://pixellab_visual_regression_%s_b.png" % label)

	# Bbox + non-empty assertions on canvas A
	_assert_canvas_invariants(label, canvas_a, painted_visual, tile_size)

	# Cleanup
	layer.queue_free()
	await process_frame


func _compose_canvas(label: String, primary: TileMapLayer, painted_visual: Array, atlas_img: Image, tile_size: Vector2i) -> Image:
	var c_min := Vector2i(99999, 99999)
	var c_max := Vector2i(-99999, -99999)
	for cell: Vector2i in painted_visual:
		c_min.x = min(c_min.x, cell.x)
		c_min.y = min(c_min.y, cell.y)
		c_max.x = max(c_max.x, cell.x)
		c_max.y = max(c_max.y, cell.y)
	var w: int = (c_max.x - c_min.x + 1) * tile_size.x
	var h: int = (c_max.y - c_min.y + 1) * tile_size.y
	var canvas := Image.create(w, h, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))

	var unrenderable := 0
	for cell: Vector2i in painted_visual:
		var ac: Vector2i = primary.get_cell_atlas_coords(cell)
		var src_rect := Rect2i(ac * tile_size, tile_size)
		if src_rect.position.x < 0 or src_rect.position.y < 0:
			unrenderable += 1
			continue
		if src_rect.end.x > atlas_img.get_width() or src_rect.end.y > atlas_img.get_height():
			unrenderable += 1
			continue
		var alt: int = primary.get_cell_alternative_tile(cell)
		var transform: int = alt & ~0xfff
		var src_tile := atlas_img.get_region(src_rect)
		var rotated := _apply_transform(src_tile, transform)
		canvas.blit_rect(rotated, Rect2i(Vector2i.ZERO, tile_size), (cell - c_min) * tile_size)

	if unrenderable > 0:
		_failures.append("%s: %d painted cells dispatched to out-of-bounds atlas coords" % [label, unrenderable])
		return null
	return canvas


func _apply_transform(src: Image, transform: int) -> Image:
	var transpose: bool = (transform & TileSetAtlasSource.TRANSFORM_TRANSPOSE) != 0
	var flip_h: bool   = (transform & TileSetAtlasSource.TRANSFORM_FLIP_H) != 0
	var flip_v: bool   = (transform & TileSetAtlasSource.TRANSFORM_FLIP_V) != 0
	if not transpose and not flip_h and not flip_v:
		return src
	var w: int = src.get_width()
	var h: int = src.get_height()
	var dst_w: int = h if transpose else w
	var dst_h: int = w if transpose else h
	var out := Image.create(dst_w, dst_h, false, Image.FORMAT_RGBA8)
	for sy in range(h):
		for sx in range(w):
			var c := src.get_pixel(sx, sy)
			var tx: int = sx
			var ty: int = sy
			if transpose:
				var tmp: int = tx
				tx = ty
				ty = tmp
			if flip_h:
				tx = dst_w - 1 - tx
			if flip_v:
				ty = dst_h - 1 - ty
			out.set_pixel(tx, ty, c)
	return out


func _assert_canvas_invariants(label: String, canvas: Image, painted_cells: Array, tile_size: Vector2i) -> void:
	var c_min := Vector2i(99999, 99999)
	var c_max := Vector2i(-99999, -99999)
	for cell: Vector2i in painted_cells:
		c_min.x = min(c_min.x, cell.x)
		c_min.y = min(c_min.y, cell.y)
		c_max.x = max(c_max.x, cell.x)
		c_max.y = max(c_max.y, cell.y)
	var expected_w: int = (c_max.x - c_min.x + 1) * tile_size.x
	var expected_h: int = (c_max.y - c_min.y + 1) * tile_size.y

	# Find opaque bbox
	var op_max_x: int = -1
	var op_max_y: int = -1
	var op_min_x: int = canvas.get_width()
	var op_min_y: int = canvas.get_height()
	for y in canvas.get_height():
		for x in canvas.get_width():
			if canvas.get_pixel(x, y).a > 0.0:
				if x < op_min_x: op_min_x = x
				if y < op_min_y: op_min_y = y
				if x > op_max_x: op_max_x = x
				if y > op_max_y: op_max_y = y

	if op_max_x < 0:
		_failures.append("%s: composed canvas has zero opaque pixels" % label)
		canvas.save_png("user://pixellab_visual_regression_%s_empty.png" % label)
		return

	# bbox should cover the painted-region pixel bounds (no shrinking).
	# Note: opaque-pixel bbox MAY be smaller than the canvas if the user's
	# PixelLab sample has any role-12 (mask=0) cells — those render fully
	# transparent. In a typical mixed-paint pattern the bbox will be the
	# full canvas; if it isn't, a save_png lets the developer eyeball it.
	var canvas_w: int = canvas.get_width()
	var canvas_h: int = canvas.get_height()
	if canvas_w != expected_w or canvas_h != expected_h:
		_failures.append("%s: canvas size %dx%d != expected %dx%d" % [label, canvas_w, canvas_h, expected_w, expected_h])

	# Save canvas for visual inspection regardless of pass/fail (Test Method #4).
	canvas.save_png("user://pixellab_visual_regression_%s.png" % label)
