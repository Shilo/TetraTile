## Temporary baseline capture script — NOT committed to git.
## Run headlessly:
##   Godot_v4.6.2-stable_win64_console.exe --headless --path . --script addons/penta_tile/tests/_capture_baseline.gd
## Prints BASELINE_HASH=<integer> to stdout, then quits.
## Uses preload() to avoid class_name symbol-table ordering issues in --script mode.
extends SceneTree

# Preload all required scripts explicitly so symbols are available.
const _SynthesisScript = preload("res://addons/penta_tile/penta_tile_synthesis.gd")
const _SlotScript = preload("res://addons/penta_tile/penta_tile_atlas_slot.gd")
const _LayoutScript = preload("res://addons/penta_tile/layouts/penta_tile_layout.gd")
const _PentaScript = preload("res://addons/penta_tile/layouts/penta_tile_layout_penta.gd")
const _LayerScript = preload("res://addons/penta_tile/penta_tile_map_layer.gd")

func _initialize() -> void:
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
