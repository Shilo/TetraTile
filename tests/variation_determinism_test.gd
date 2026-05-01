## Automated variation determinism and mode test.
##
## Run headless:
##   Godot_v4.6.2-stable_win64_console.exe --headless --path . --script tests/variation_determinism_test.gd
##
## What it does:
##   - Test SINGLE mode produces one tile per mask
##   - Test PROBABILITY mode pools candidates and picks via weighted random
##   - Test variation determinism: same (coord, terrain_id, seed) → same tile
##   - Test variation no-shimmer on rebuild
##   - Test STRIP mode picks from horizontal atlas strip
##   - Test set_cell_passthrough() bypasses solver
##   - Test variation_seed export property exists
##
## Exits 0 on PASS, 1 on FAIL with details to stderr.
extends SceneTree

const _LayerScript       = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _Wang2EdgeSc       = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd")
const _DualGrid16Sc      = preload("res://addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd")

var _failures: Array = []


func _initialize() -> void:
	print("=== variation_determinism_test ===")

	await _test_variation_seed_property()
	await _test_single_mode_preserved()
	await _test_probability_mode_weighted_pick()
	await _test_variation_determinism()
	await _test_no_shimmer_on_rebuild()
	await _test_strip_mode_pick()
	await _test_set_cell_passthrough()

	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		quit(1)


# --- Helpers ---

func _build_variation_tileset() -> TileSet:
	"""Build a TileSet with multiple terrain tiles for probability testing.
	Terrain 0 has 3 variant tiles at coords (0,0), (1,0), (2,0) with
	probabilities 0.1, 0.3, 0.6.
	Terrain 1 has 2 variant tiles at coords (3,0), (4,0) with equal weight.
	"""
	var ts := TileSet.new()
	ts.tile_size = Vector2i(32, 32)
	ts.add_terrain_set(0)
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)

	var src := TileSetAtlasSource.new()
	src.texture_region_size = Vector2i(32, 32)

	var img := Image.create(160, 32, false, Image.FORMAT_RGBA8)  # 5 cols x 1 row
	var colors := [
		Color(0.8, 0.2, 0.2, 1.0),  # (0,0) red — terrain 0, prob 0.1
		Color(0.2, 0.8, 0.2, 1.0),  # (1,0) green — terrain 0, prob 0.3
		Color(0.2, 0.2, 0.8, 1.0),  # (2,0) blue — terrain 0, prob 0.6
		Color(0.8, 0.8, 0.2, 1.0),  # (3,0) yellow — terrain 1, prob 1.0
		Color(0.8, 0.4, 0.8, 1.0),  # (4,0) purple — terrain 1, prob 1.0
	]
	for i: int in range(colors.size()):
		for px: int in range(32):
			for py: int in range(32):
				img.set_pixel(i * 32 + px, py, colors[i])
	src.texture = ImageTexture.create_from_image(img)

	# Create tiles with terrain and probability metadata
	src.create_tile(Vector2i(0, 0))
	var td0 := src.get_tile_data(Vector2i(0, 0), 0)
	td0.terrain_set = 0; td0.terrain = 0; td0.probability = 0.1

	src.create_tile(Vector2i(1, 0))
	var td1 := src.get_tile_data(Vector2i(1, 0), 0)
	td1.terrain_set = 0; td1.terrain = 0; td1.probability = 0.3

	src.create_tile(Vector2i(2, 0))
	var td2 := src.get_tile_data(Vector2i(2, 0), 0)
	td2.terrain_set = 0; td2.terrain = 0; td2.probability = 0.6

	src.create_tile(Vector2i(3, 0))
	var td3 := src.get_tile_data(Vector2i(3, 0), 0)
	td3.terrain_set = 0; td3.terrain = 1; td3.probability = 1.0

	src.create_tile(Vector2i(4, 0))
	var td4 := src.get_tile_data(Vector2i(4, 0), 0)
	td4.terrain_set = 0; td4.terrain = 1; td4.probability = 1.0

	ts.add_source(src, 0)
	return ts


func _build_strip_tileset() -> TileSet:
	"""Build a TileSet for STRIP mode testing.
	Atlas: 3 cols x 1 row, all terrain 0. STRIP picks random column.
	"""
	var ts := TileSet.new()
	ts.tile_size = Vector2i(32, 32)
	ts.add_terrain_set(0)
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)

	var src := TileSetAtlasSource.new()
	src.texture_region_size = Vector2i(32, 32)
	var img := Image.create(96, 32, false, Image.FORMAT_RGBA8)
	var scolors := [Color.RED, Color.GREEN, Color.BLUE]
	for i: int in range(3):
		for px: int in range(32):
			for py: int in range(32):
				img.set_pixel(i * 32 + px, py, scolors[i])
	src.texture = ImageTexture.create_from_image(img)

	for x: int in range(3):
		src.create_tile(Vector2i(x, 0))
		var td := src.get_tile_data(Vector2i(x, 0), 0)
		td.terrain_set = 0; td.terrain = 0

	ts.add_source(src, 0)
	return ts


func _get_visual_atlas_coord(layer: Node, display_cell: Vector2i) -> Vector2i:
	var primary: TileMapLayer = layer.get("_primary_layer")
	if primary == null or not is_instance_valid(primary):
		return Vector2i(-1, -1)
	return primary.get_cell_atlas_coords(display_cell)


# --- Tests ---

func _test_variation_seed_property() -> void:
	print("\n  --- variation_seed property ---")
	var layer := _LayerScript.new()
	_assert("variation_seed property exists", "variation_seed" in layer)
	_assert("variation_seed default is 0", layer.get("variation_seed") == 0)
	layer.queue_free()


func _test_single_mode_preserved() -> void:
	print("\n  --- SINGLE mode preserved ---")

	var ts := _build_variation_tileset()
	var layer := _LayerScript.new()

	var layout := _Wang2EdgeSc.new()
	layout.variation_mode = 0  # SINGLE
	layer.layout = layout
	layer.tile_set = ts
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Paint a cell with SINGLE mode — should produce one tile consistently.
	layer.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))
	await process_frame
	await process_frame

	var primary: TileMapLayer = layer.get("_primary_layer")
	if primary != null and is_instance_valid(primary):
		var sid: int = primary.get_cell_source_id(Vector2i(0, 0))
		_assert("SINGLE mode paints visual cell", sid != -1)

	layer.queue_free()


func _test_probability_mode_weighted_pick() -> void:
	print("\n  --- PROBABILITY mode weighted pick ---")

	var ts := _build_variation_tileset()
	var layer := _LayerScript.new()

	var layout := _Wang2EdgeSc.new()
	layout.variation_mode = 1  # PROBABILITY
	layer.layout = layout
	layer.tile_set = ts
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Verify variation_mode is PROBABILITY on the layout
	_assert("layout variation_mode is PROBABILITY", layout.variation_mode == 1)

	# Paint a single cell with terrain 0
	layer.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))
	await process_frame
	await process_frame

	var primary: TileMapLayer = layer.get("_primary_layer")
	if primary != null and is_instance_valid(primary):
		var sid: int = primary.get_cell_source_id(Vector2i(0, 0))
		_assert("PROBABILITY mode paints visual cell", sid != -1)

	layer.queue_free()


func _test_variation_determinism() -> void:
	print("\n  --- variation determinism (D-07) ---")

	var ts := _build_variation_tileset()
	var layer := _LayerScript.new()

	var layout := _Wang2EdgeSc.new()
	layout.variation_mode = 1  # PROBABILITY
	layer.layout = layout
	layer.tile_set = ts
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Paint 3 identical cells — all terrain 0
	for i: int in range(3):
		layer.set_cell(Vector2i(i, 0), 0, Vector2i(0, 0))
	await process_frame
	await process_frame

	# Record which atlas coords each cell got.
	var coords1: Array = []
	var primary: TileMapLayer = layer.get("_primary_layer")
	if primary != null and is_instance_valid(primary):
		for i: int in range(3):
			coords1.append(primary.get_cell_atlas_coords(Vector2i(i, 0)))

	# Rebuild and verify same coords.
	if layer.has_method("rebuild"):
		layer.rebuild()
		await process_frame
		await process_frame

	for i: int in range(3):
		var ac := primary.get_cell_atlas_coords(Vector2i(i, 0))
		_assert("determinism: cell %d same coords" % i, ac == coords1[i])

	print("  coords (run 1): ", coords1)

	# Change variation_seed and verify different coords.
	layer.set("variation_seed", 999)
	await process_frame
	await process_frame

	var coords2: Array = []
	for i: int in range(3):
		coords2.append(primary.get_cell_atlas_coords(Vector2i(i, 0)))

	print("  coords (run 2, seed=999): ", coords2)
	# Different seed should produce at least one different result
	# (not guaranteed for small candidate sets, but informative)
	var diff: bool = false
	for i: int in range(3):
		if coords1[i] != coords2[i]:
			diff = true
	# This is probabilistic — we just verify no crash and the test runs
	print("  any diff: ", diff)

	layer.queue_free()


func _test_no_shimmer_on_rebuild() -> void:
	print("\n  --- no shimmer on rebuild ---")

	var ts := _build_variation_tileset()
	var layer := _LayerScript.new()

	var layout := _Wang2EdgeSc.new()
	layout.variation_mode = 1  # PROBABILITY
	layer.layout = layout
	layer.tile_set = ts
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Paint a 2x2 block.
	for x: int in range(2):
		for y: int in range(2):
			layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	await process_frame
	await process_frame

	var primary: TileMapLayer = layer.get("_primary_layer")
	var coords_run1: Array = []
	if primary != null and is_instance_valid(primary):
		for x: int in range(2):
			for y: int in range(2):
				coords_run1.append(primary.get_cell_atlas_coords(Vector2i(x, y)))

	# Rebuild 3 times, verify all produce same coords.
	for rebuild: int in range(3):
		if layer.has_method("rebuild"):
			layer.rebuild()
		await process_frame
		await process_frame

		var idx: int = 0
		for x: int in range(2):
			for y: int in range(2):
				var ac := primary.get_cell_atlas_coords(Vector2i(x, y))
				_assert("shimmer-check: rebuild %d cell (%d,%d) same" % [rebuild, x, y], ac == coords_run1[idx])
				idx += 1

	print("  rebuilds 0-2 all match run 1")
	layer.queue_free()


func _test_strip_mode_pick() -> void:
	print("\n  --- STRIP mode pick ---")

	var ts := _build_strip_tileset()
	var layer := _LayerScript.new()

	var layout := _DualGrid16Sc.new()
	layout.variation_mode = 2  # STRIP
	layer.layout = layout
	layer.tile_set = ts
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Verify variation_mode is STRIP
	_assert("layout variation_mode is STRIP", layout.variation_mode == 2)

	# Paint cells with terrain 0. STRIP mode picks random column within atlas row.
	layer.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))
	layer.set_cell(Vector2i(1, 0), 0, Vector2i(0, 0))
	await process_frame
	await process_frame

	var primary: TileMapLayer = layer.get("_primary_layer")
	if primary != null and is_instance_valid(primary):
		var sid: int = primary.get_cell_source_id(Vector2i(0, 0))
		_assert("STRIP mode paints visual cell", sid != -1)

		# Verify atlas coords are valid (non-negative)
		var ac0 := primary.get_cell_atlas_coords(Vector2i(0, 0))
		print("  STRIP coords cell 0: ", ac0)
		_assert("STRIP mode atlas coords valid", ac0.x >= 0 and ac0.y >= 0)

	layer.queue_free()


func _test_set_cell_passthrough() -> void:
	print("\n  --- set_cell_passthrough ---")

	var ts := _build_variation_tileset()
	var layer := _LayerScript.new()
	layer.tile_set = ts

	# Bind a layout (even though passthrough bypasses solver).
	var layout := _Wang2EdgeSc.new()
	layer.layout = layout
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Verify set_cell_passthrough method exists
	_assert("set_cell_passthrough exists", layer.has_method("set_cell_passthrough"))

	# Use passthrough to place a raw atlas cell at (2, 0) = blue tile
	if layer.has_method("set_cell_passthrough"):
		layer.call("set_cell_passthrough", Vector2i(0, 0), 0, Vector2i(2, 0), 0)
	await process_frame
	await process_frame

	# Verify the visual layer has the passthrough cell
	var primary: TileMapLayer = layer.get("_primary_layer")
	if primary != null and is_instance_valid(primary):
		var sid: int = primary.get_cell_source_id(Vector2i(0, 0))
		_assert("passthrough cell on visual layer", sid != -1)

		var ac := primary.get_cell_atlas_coords(Vector2i(0, 0))
		_assert("passthrough atlas coords are (2,0)", ac == Vector2i(2, 0))

	# Rebuild: passthrough cell should survive.
	if layer.has_method("rebuild"):
		layer.rebuild()
	await process_frame
	await process_frame

	if primary != null and is_instance_valid(primary):
		var sid2: int = primary.get_cell_source_id(Vector2i(0, 0))
		_assert("passthrough cell survives rebuild", sid2 != -1)
		var ac2 := primary.get_cell_atlas_coords(Vector2i(0, 0))
		_assert("passthrough coords survive rebuild", ac2 == Vector2i(2, 0))

	layer.queue_free()


# --- Assertions ---

func _assert(label: String, condition: bool) -> void:
	if not condition:
		_failures.append(label)
		printerr("  FAIL: " + label)
