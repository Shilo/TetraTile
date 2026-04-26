## Baseline capture script.
## Run headlessly:
##   Godot_v4.6.2-stable_win64_console.exe --headless --path . --script addons/penta_tile/tests/_capture_baseline.gd
##
## Optional layout swap (for capturing non-default-layout baselines, e.g. the WR-07 VERTICAL baseline):
##   ... --script addons/penta_tile/tests/_capture_baseline.gd -- --layout-path=res://addons/penta_tile/demo/penta_layout_four_vertical.tres
## When --layout-path=<path> is passed, the script swaps the layer's `layout` Resource to that path
## before forcing rebuild. Without it, captures whatever layout the demo scene has bound (HORIZONTAL FOUR).
##
## Prints BASELINE_HASH=<integer> + BASELINE_CELLS / DATA_SIZE to stdout, then quits.
## Uses preload() to avoid class_name symbol-table ordering issues in --script mode.
extends SceneTree

# Preload all required scripts explicitly so symbols are available.
const _SynthesisScript = preload("res://addons/penta_tile/penta_tile_synthesis.gd")
const _SlotScript = preload("res://addons/penta_tile/penta_tile_atlas_slot.gd")
const _LayoutScript = preload("res://addons/penta_tile/layouts/penta_tile_layout.gd")
const _PentaScript = preload("res://addons/penta_tile/layouts/penta_tile_layout_penta.gd")
const _LayerScript = preload("res://addons/penta_tile/penta_tile_map_layer.gd")

func _initialize() -> void:
	# Optional layout swap via CLI: --layout-path=<res_path>. Used by the VERTICAL baseline
	# capture to close the WR-07 test-corpus gap without forking the demo scene.
	var override_layout_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--layout-path="):
			override_layout_path = arg.substr("--layout-path=".length())

	# Load the demo scene. The scene's PentaTileMapLayer will use the preloaded scripts.
	var demo_scene_path := "res://addons/penta_tile/demo/penta_tile_demo.tscn"
	var packed := load(demo_scene_path) as PackedScene
	if packed == null:
		printerr("_capture_baseline: could not load demo scene at " + demo_scene_path)
		quit(1)
		return

	var root_node := packed.instantiate()
	get_root().add_child(root_node)

	# Wait two frames so _ready fires and the deferred rebuild runs.
	await process_frame
	await process_frame

	# Find the PentaTileMapLayer node.
	var layer_node = root_node.find_child("PentaTileMapLayer", true, false)
	if layer_node == null:
		printerr("_capture_baseline: PentaTileMapLayer node not found in demo scene")
		root_node.queue_free()
		quit(1)
		return

	# Optional layout override: swap onto the layer before rebuilding.
	if override_layout_path != "":
		var override_layout := load(override_layout_path) as Resource
		if override_layout == null:
			printerr("_capture_baseline: could not load layout at " + override_layout_path)
			root_node.queue_free()
			quit(1)
			return
		layer_node.layout = override_layout
		# Wave 2 setter calls _queue_rebuild() but does NOT invalidate _synthesized_tile_set
		# (the cache nuke lives in _on_layout_changed which fires on Resource.changed, not on
		# layout-property reassignment). Without explicit invalidation, the rebuild reuses the
		# scene-load cached HORIZONTAL synthesis. Invoke _on_layout_changed manually to clear.
		if layer_node.has_method("_on_layout_changed"):
			layer_node._on_layout_changed()
		print("LAYOUT_OVERRIDE=%s axis=%d tile_count=%d" % [
			override_layout_path,
			int(override_layout.get("axis")),
			int(override_layout.get("tile_count")),
		])

	# Force synchronous rebuild (in case call_deferred hasn't fired yet).
	if layer_node.has_method("rebuild"):
		layer_node.rebuild()

	# Access _primary_layer.
	var primary = layer_node.get("_primary_layer")
	if primary == null:
		printerr("_capture_baseline: _primary_layer is null after rebuild")
		var synth = layer_node.get("_synthesized_tile_set")
		printerr("  _synthesized_tile_set = " + str(synth))
		root_node.queue_free()
		quit(1)
		return

	var data: PackedByteArray = primary.tile_map_data
	# Use GDScript builtin hash() on Array conversion — PackedByteArray has no .hash() in 4.6.
	var data_array: Array = Array(data)
	var h: int = hash(data_array)
	var cell_count: int = primary.get_used_cells().size()
	print("BASELINE_HASH=%d" % h)
	print("BASELINE_CELLS=%d" % cell_count)
	print("DATA_SIZE=%d" % data.size())

	root_node.queue_free()
	quit(0)
