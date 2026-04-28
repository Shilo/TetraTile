## Diagnostic: spawn a fresh PentaTileMapLayer (no .tscn) and verify the
## default layout + auto-fill chain populates tile_set correctly.
extends SceneTree

const _LayerScript = preload("res://addons/penta_tile/penta_tile_map_layer.gd")


func _initialize() -> void:
	print("=== fresh_node_diag ===")

	# Spawn a fresh layer the same way Godot's "Add Node" would.
	var layer = _LayerScript.new()

	print("\n[BEFORE add_child]")
	print("  layout:", layer.layout)
	print("  layout class:", layer.layout.get_script().resource_path if layer.layout != null and layer.layout.get_script() != null else "null")
	print("  tile_set:", layer.tile_set)
	print("  _tile_set_is_fallback:", layer.get("_tile_set_is_fallback"))

	get_root().add_child(layer)
	await process_frame
	await process_frame

	print("\n[AFTER add_child + 2 frames]")
	print("  layout:", layer.layout)
	print("  tile_set:", layer.tile_set)
	print("  _tile_set_is_fallback:", layer.get("_tile_set_is_fallback"))

	if layer.tile_set != null:
		var src := layer.tile_set.get_source(0) as TileSetAtlasSource
		if src != null:
			print("  tile_set source 0 grid:", src.get_atlas_grid_size())
			print("  tile_set source 0 tile_size:", src.texture_region_size)
			print("  tile_set tile_size:", layer.tile_set.tile_size)

	# Also check the layout's bitmask_template (should be auto-filled by Penta._init)
	if layer.layout != null:
		print("  layout.bitmask_template:", layer.layout.bitmask_template)
		print("  layout.axis:", layer.layout.get("axis"))
		print("  layout.tile_count:", layer.layout.get("tile_count"))

	layer.queue_free()
	quit(0)
