## Renders both BitmaskDemo layers from the demo scene to PNGs so we can
## visually verify the 16-pattern grid is correct (independent of the user's
## screenshot).
extends SceneTree

const _DEMO_PATH := "res://addons/penta_tile/demo/penta_tile_demo.tscn"


func _initialize() -> void:
	print("=== _render_bitmask_demo_diag ===")

	var packed := load(_DEMO_PATH) as PackedScene
	var root := packed.instantiate()
	get_root().add_child(root)
	await process_frame
	await process_frame
	await process_frame

	var found_layers: Array = []
	for child in root.get_children():
		if child.name == "BitmaskDemo_BundledGreybox" or child.name == "BitmaskDemo_GroundTres":
			found_layers.append(child)
	print("found %d demo layers" % found_layers.size())

	for layer: Node in found_layers:
		var primary = layer.get("_primary_layer")
		if primary == null:
			print("  %s: no _primary_layer" % layer.name)
			continue
		var painted: Array = primary.get_used_cells()
		var eff_ts: TileSet = primary.tile_set
		var eff_src := eff_ts.get_source(0) as TileSetAtlasSource
		var atlas_img: Image = eff_src.texture.get_image()
		var tile_size: Vector2i = eff_src.texture_region_size

		# Compute bbox of painted display cells.
		var c_min := Vector2i(99999, 99999)
		var c_max := Vector2i(-99999, -99999)
		for cell: Vector2i in painted:
			c_min.x = min(c_min.x, cell.x)
			c_min.y = min(c_min.y, cell.y)
			c_max.x = max(c_max.x, cell.x)
			c_max.y = max(c_max.y, cell.y)

		# Pad by 1 cell so any half-tile-offset perimeter pixels are visible.
		var pad := 1
		var w: int = (c_max.x - c_min.x + 1 + 2 * pad) * tile_size.x
		var h: int = (c_max.y - c_min.y + 1 + 2 * pad) * tile_size.y
		var canvas := Image.create(w, h, false, Image.FORMAT_RGBA8)
		canvas.fill(Color(0.18, 0.18, 0.18, 1.0))                                 # dark grey background

		for cell: Vector2i in painted:
			var ac: Vector2i = primary.get_cell_atlas_coords(cell)
			if not eff_src.has_tile(ac):
				continue
			var alt: int = primary.get_cell_alternative_tile(cell)
			var transform: int = alt & ~0xfff
			var src_tile := atlas_img.get_region(Rect2i(ac * tile_size, tile_size))
			var rotated := _apply_transform(src_tile, transform)
			canvas.blit_rect(rotated, Rect2i(Vector2i.ZERO, tile_size), (cell - c_min + Vector2i(pad, pad)) * tile_size)

		var save_path := "addons/penta_tile/tests/_diag_demo_%s.png" % layer.name.to_lower()
		canvas.save_png(save_path)
		print("  %s painted=%d bbox=%s..%s tile_size=%s saved=%s" % [layer.name, painted.size(), c_min, c_max, tile_size, save_path])

	quit(0)


func _apply_transform(src: Image, transform: int) -> Image:
	var transpose: bool = (transform & TileSetAtlasSource.TRANSFORM_TRANSPOSE) != 0
	var flip_h: bool = (transform & TileSetAtlasSource.TRANSFORM_FLIP_H) != 0
	var flip_v: bool = (transform & TileSetAtlasSource.TRANSFORM_FLIP_V) != 0
	var w: int = src.get_width()
	var h: int = src.get_height()
	var dst_w: int = h if transpose else w
	var dst_h: int = w if transpose else h
	var dst := Image.create(dst_w, dst_h, false, Image.FORMAT_RGBA8)
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
			dst.set_pixel(tx, ty, c)
	return dst
