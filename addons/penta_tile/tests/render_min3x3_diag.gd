## Renders the demo's 12x8 painted region under Min3x3 to a PNG file so we
## can pixel-inspect EXACTLY what the user is seeing in-editor. Bypasses
## the visual layer entirely — composes the rendered output directly from
## the bundled bitmask greybox PNG.
##
## Run headless:
##   Godot --headless --path . --script addons/penta_tile/tests/render_min3x3_diag.gd
extends SceneTree

const _LayerScript     = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _Min3x3Sc        = preload("res://addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd")


func _initialize() -> void:
	print("=== render_min3x3_diag ===")

	var layer = _LayerScript.new()
	layer.layout = _Min3x3Sc.new()
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Match the demo's painted region exactly.
	for x in range(-1, 11):
		for y in range(-1, 7):
			layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	await process_frame
	await process_frame
	if layer.has_method("rebuild"):
		layer.rebuild()
	await process_frame

	var primary = layer.get("_primary_layer")
	var painted: Array = primary.get_used_cells()
	var eff_ts: TileSet = primary.tile_set
	var eff_src := eff_ts.get_source(0) as TileSetAtlasSource
	var atlas_img: Image = eff_src.texture.get_image()
	var tile_size: Vector2i = eff_src.texture_region_size

	# Find painted bounds.
	var c_min := Vector2i(99999, 99999)
	var c_max := Vector2i(-99999, -99999)
	for cell: Vector2i in painted:
		c_min.x = min(c_min.x, cell.x)
		c_min.y = min(c_min.y, cell.y)
		c_max.x = max(c_max.x, cell.x)
		c_max.y = max(c_max.y, cell.y)

	# Add 2-cell padding so we see the surrounding "background".
	var pad := 2
	var w: int = (c_max.x - c_min.x + 1 + 2 * pad) * tile_size.x
	var h: int = (c_max.y - c_min.y + 1 + 2 * pad) * tile_size.y
	print("painted bounds: %s to %s, canvas: %dx%d" % [c_min, c_max, w, h])

	var canvas := Image.create(w, h, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.18, 0.18, 0.18, 1.0))                                       # dark grey background

	# Per-cell render.
	var cells_with_cuts: Array = []
	for cell: Vector2i in painted:
		var ac: Vector2i = primary.get_cell_atlas_coords(cell)
		var src_rect := Rect2i(ac * tile_size, tile_size)
		var sub := atlas_img.get_region(src_rect)
		var dst: Vector2i = (cell - c_min + Vector2i(pad, pad)) * tile_size
		canvas.blit_rect(sub, Rect2i(Vector2i.ZERO, tile_size), dst)
		# Detect which cells get a cut (any transparent pixel in dispatched tile).
		var has_cut := false
		for py in range(tile_size.y):
			for px in range(tile_size.x):
				if sub.get_pixel(px, py).a < 0.01:
					has_cut = true
					break
			if has_cut:
				break
		if has_cut:
			cells_with_cuts.append("cell %s atlas %s" % [cell, ac])

	canvas.save_png("addons/penta_tile/tests/render_min3x3_diag.png")
	print("saved to: addons/penta_tile/tests/render_min3x3_diag.png")
	print("cells with corner cuts (%d):" % cells_with_cuts.size())
	for c in cells_with_cuts:
		print("  " + c)

	# Also dump per-cell atlas dispatch and mask.
	var sample_fn := Callable(layer, "_has_logic_cell")
	print("\nper-cell mask + atlas dispatch:")
	for y in range(c_min.y, c_max.y + 1):
		var row := ""
		for x in range(c_min.x, c_max.x + 1):
			var cell := Vector2i(x, y)
			if cell in painted:
				var mask: int = layer.layout.compute_mask(cell, sample_fn)
				row += "%2d " % mask
			else:
				row += " . "
		print(row)

	layer.queue_free()
	quit(0)
