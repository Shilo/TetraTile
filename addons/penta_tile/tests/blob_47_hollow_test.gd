## Phase 3 TBT-03: composed-canvas hollow-pattern visual regression for Blob47Godot.
##
## Paints a 5×5 outer ring with a 1×1 hole at logic cell (2,2). Composes the
## rendered canvas by blitting each painted cell's atlas tile at its world
## position, then asserts:
##   1. Every logic-painted cell renders SOMETHING (Pitfall #9 + Pitfall C catch)
##   2. Opaque-pixel bbox stays within the user-painted region [0..160px, 0..160px]
##   3. The hole interior at pixel [64..95, 64..95] is fully transparent
##      (catches 8-Moore diagonal-bleed regressions)
##
## Per CLAUDE.md "Test Methodology" #1: composes the rendered canvas;
## doesn't just check dispatch.
##
## Run headless:
##   Godot --headless --path . --script addons/penta_tile/tests/blob_47_hollow_test.gd
extends SceneTree

const _LayerScript = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _Blob47GodotSc = preload("res://addons/penta_tile/layouts/penta_tile_layout_blob_47_godot.gd")

const _TILE_SIZE := 32

var _failures: Array = []


func _initialize() -> void:
	print("=== blob_47_hollow_test ===")

	# 5×5 outer ring with 1×1 hole at center cell (2, 2).
	var paint_cells: Array = _build_hollow_ring(0, 0, 5, 5, 2, 2, 1, 1)

	await _test_pattern("hollow_5x5_with_1x1_hole", paint_cells, Vector2i(2, 2))

	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d):" % _failures.size())
		for f: String in _failures:
			printerr("  - " + f)
		quit(1)


# Returns the cells of an outer rectangle [(x0,y0)..(x0+w-1, y0+h-1)]
# with an inner hole [(hx0,hy0)..(hx0+hw-1, hy0+hh-1)] removed.
func _build_hollow_ring(x0: int, y0: int, w: int, h: int, hx0: int, hy0: int, hw: int, hh: int) -> Array:
	var cells: Array = []
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			if x >= hx0 and x < hx0 + hw and y >= hy0 and y < hy0 + hh:
				continue
			cells.append(Vector2i(x, y))
	return cells


func _test_pattern(label: String, paint_cells: Array, hole_cell: Vector2i) -> void:
	var layer = _LayerScript.new()
	layer.layout = _Blob47GodotSc.new()
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Paint each cell.
	for cell: Vector2i in paint_cells:
		layer.set_cell(cell, 0, Vector2i(0, 0))
	await process_frame
	await process_frame

	# Compose the rendered canvas. _primary_layer is a script-private TileMapLayer
	# child node; access via the variant property (not get_node — the Node name is
	# _PRIMARY_LAYER_NAME = "_PentaTileVisual", not "_primary_layer").
	var primary: TileMapLayer = layer.get("_primary_layer")
	if primary == null:
		_record(label, "_primary_layer is null on PentaTileMapLayer (visual-layer init failed)")
		layer.queue_free()
		return
	var ts := primary.tile_set
	if ts == null:
		_record(label, "primary_layer.tile_set is null after paint — fallback codegen broken?")
		layer.queue_free()
		return

	var src := ts.get_source(0) as TileSetAtlasSource
	if src == null or src.texture == null:
		_record(label, "tile_set source 0 missing or has no texture")
		layer.queue_free()
		return

	var atlas_img: Image = src.texture.get_image()
	if atlas_img == null:
		_record(label, "could not extract atlas Image from texture")
		layer.queue_free()
		return
	if atlas_img.get_format() != Image.FORMAT_RGBA8:
		atlas_img.convert(Image.FORMAT_RGBA8)

	# Bounds for canvas: enclose every paint cell + the hole cell.
	var c_min := Vector2i(2147483647, 2147483647)
	var c_max := Vector2i(-2147483648, -2147483648)
	for cell: Vector2i in paint_cells:
		c_min.x = mini(c_min.x, cell.x)
		c_min.y = mini(c_min.y, cell.y)
		c_max.x = maxi(c_max.x, cell.x)
		c_max.y = maxi(c_max.y, cell.y)

	var canvas_w := (c_max.x - c_min.x + 1) * _TILE_SIZE
	var canvas_h := (c_max.y - c_min.y + 1) * _TILE_SIZE
	var canvas := Image.create(canvas_w, canvas_h, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))

	# Blit each painted cell's atlas tile into the canvas.
	var painted_count := 0
	for cell: Vector2i in paint_cells:
		var atlas_coords: Vector2i = primary.get_cell_atlas_coords(cell)
		if atlas_coords == Vector2i(-1, -1):
			_record(label, "logic cell %s painted but primary_layer has no atlas coord" % cell)
			continue
		painted_count += 1
		var src_rect := Rect2i(atlas_coords * _TILE_SIZE, Vector2i(_TILE_SIZE, _TILE_SIZE))
		var dst_pos := (cell - c_min) * _TILE_SIZE
		canvas.blit_rect(atlas_img, src_rect, dst_pos)

	# ASSERTION 1: opaque-pixel bbox stays within canvas bounds [0..canvas_w, 0..canvas_h].
	var bbox := _compute_opaque_bbox(canvas)
	if bbox.position.x < 0 or bbox.position.y < 0:
		_record(label, "bbox starts negative: %s" % bbox)
	if bbox.position.x + bbox.size.x > canvas_w or bbox.position.y + bbox.size.y > canvas_h:
		_record(label, "bbox extends beyond canvas: bbox=%s canvas=(%d, %d)" % [bbox, canvas_w, canvas_h])

	# ASSERTION 1b (PRE-BAKED W-5 SENSITIVE — catches missing-diagonal-render
	# regressions even when the obvious bbox/hole checks pass):
	# The hollow ring's bounding box MUST exactly fill the canvas in BOTH axes,
	# because the outer ring touches every edge of the painted rectangle.
	if bbox.size.y != canvas_h:
		_record(label, "PRE-BAKED W-5: bbox.size.y=%d != canvas_h=%d — outer ring is missing rows (likely a diagonal-render regression)" % [bbox.size.y, canvas_h])
	if bbox.size.x != canvas_w:
		_record(label, "PRE-BAKED W-5: bbox.size.x=%d != canvas_w=%d — outer ring is missing cols (likely a diagonal-render regression)" % [bbox.size.x, canvas_w])
	# ASSERTION 1c (PRE-BAKED W-5): every paint cell must have rendered (strict equality).
	if painted_count != paint_cells.size():
		_record(label, "PRE-BAKED W-5: painted_count=%d != paint_cells.size()=%d (cells silently skipped renders)" % [painted_count, paint_cells.size()])

	# ASSERTION 2: hole interior is fully transparent.
	var hole_local := hole_cell - c_min
	var hole_x0 := hole_local.x * _TILE_SIZE
	var hole_y0 := hole_local.y * _TILE_SIZE
	for py in range(hole_y0, hole_y0 + _TILE_SIZE):
		for px in range(hole_x0, hole_x0 + _TILE_SIZE):
			var c: Color = canvas.get_pixel(px, py)
			if c.a > 0.0:
				_record(label, "hole interior pixel (%d, %d) is opaque (alpha=%f) — diagonal-bleed regression?" % [px, py, c.a])
				layer.queue_free()
				return

	layer.queue_free()


func _compute_opaque_bbox(img: Image) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.0:
				if x < min_x: min_x = x
				if y < min_y: min_y = y
				if x > max_x: max_x = x
				if y > max_y: max_y = y
	if max_x < 0:
		return Rect2i(0, 0, 0, 0)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _record(label: String, msg: String) -> void:
	_failures.append("[" + label + "] " + msg)
	printerr("  FAIL " + label + ": " + msg)
