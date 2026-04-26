## Phase 2 Wave 7 determinism test — run headlessly:
##   Godot_v4.6.2-stable_win64.exe --headless --path . --script addons/penta_tile/tests/determinism_test.gd
##
## Tests:
##   Sub-test (a) — transform_vertex worked example (Gate 2, all 8 flag combos)
##   Sub-test (b) — clip_polygon_to_subrect hash determinism (10 invocations)
##   Main test    — rebuild loop × 10 runs; assert all hashes identical AND match BASELINE_HASH
##
## PENTA-SYNTH-06 invariant: cache-invalidation via rebuild() between runs.
## (The demo scene's PentaTileMapLayer.rebuild() call re-runs synthesis from scratch.)
extends SceneTree

# Preload all required scripts explicitly so symbols are available in --script mode.
const _SynthesisScript = preload("res://addons/penta_tile/penta_tile_synthesis.gd")
const _SlotScript = preload("res://addons/penta_tile/penta_tile_atlas_slot.gd")
const _LayoutScript = preload("res://addons/penta_tile/layouts/penta_tile_layout.gd")
const _PentaScript = preload("res://addons/penta_tile/layouts/penta_tile_layout_penta.gd")
const _LayerScript = preload("res://addons/penta_tile/penta_tile_map_layer.gd")

# FOUR-mode baseline from Wave 6 (addons/penta_tile/tests/baselines/four_mode_5x5.txt)
const BASELINE_HASH := 2986698704

func _initialize() -> void:
	# -----------------------------------------------------------------------
	# Sub-test (a) — transform_vertex worked example (Gate 2 table, all 8 combos)
	# -----------------------------------------------------------------------
	_subtest_transform_vertex_worked_example()

	# -----------------------------------------------------------------------
	# Sub-test (b) — clip_polygon_to_subrect determinism (10 invocations)
	# -----------------------------------------------------------------------
	_subtest_clip_polygon_determinism()

	# -----------------------------------------------------------------------
	# Main test — 10-run rebuild loop against demo scene (FOUR horizontal layout)
	# -----------------------------------------------------------------------
	await _run_main_rebuild_test()

	quit(0)


func _subtest_transform_vertex_worked_example() -> void:
	# Asserts PentaTileSynthesis.transform_vertex(v, flags) matches the
	# worked-example table from 02-02-PLAN.md Gate 2 for all 8 flag combinations.
	var v := Vector2(0.25, 0.75)
	var FLIP_H := TileSetAtlasSource.TRANSFORM_FLIP_H        # 4096
	var FLIP_V := TileSetAtlasSource.TRANSFORM_FLIP_V        # 8192
	var TRANSPOSE := TileSetAtlasSource.TRANSFORM_TRANSPOSE  # 16384

	# Expected outputs from 02-02-PLAN.md Gate 2 table:
	var cases := [
		{ "label": "identity",                      "flags": 0,                           "out": Vector2( 0.25,  0.75) },
		{ "label": "FLIP_H",                         "flags": FLIP_H,                      "out": Vector2(-0.25,  0.75) },
		{ "label": "FLIP_V",                         "flags": FLIP_V,                      "out": Vector2( 0.25, -0.75) },
		{ "label": "FLIP_H + FLIP_V",                "flags": FLIP_H | FLIP_V,             "out": Vector2(-0.25, -0.75) },
		{ "label": "TRANSPOSE",                      "flags": TRANSPOSE,                   "out": Vector2( 0.75,  0.25) },
		{ "label": "TRANSPOSE + FLIP_H",             "flags": TRANSPOSE | FLIP_H,          "out": Vector2(-0.75,  0.25) },
		{ "label": "TRANSPOSE + FLIP_V",             "flags": TRANSPOSE | FLIP_V,          "out": Vector2( 0.75, -0.25) },
		{ "label": "TRANSPOSE + FLIP_H + FLIP_V",    "flags": TRANSPOSE | FLIP_H | FLIP_V, "out": Vector2(-0.75, -0.25) },
	]

	var all_pass := true
	for case in cases:
		var actual: Vector2 = _SynthesisScript.transform_vertex(v, case.flags)
		var pass_flag := actual.is_equal_approx(case.out)
		if not pass_flag:
			printerr("FAIL sub-test (a) [%s]: transform_vertex(%s, %d) = %s; expected %s" % [
				case.label, v, case.flags, actual, case.out])
			all_pass = false

	if all_pass:
		print("Sub-test (a) — transform_vertex worked example: PASS (8 combinations)")
	else:
		printerr("Sub-test (a) — transform_vertex worked example: FAIL")
		quit(1)


func _subtest_clip_polygon_determinism() -> void:
	# Calls clip_polygon_to_subrect 10 times with identical inputs;
	# asserts output hash is identical across all invocations.
	var test_polygon := PackedVector2Array([
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(1, 1),
		Vector2(0, 1),
	])
	var test_sub_rect := Rect2(0.25, 0.25, 0.5, 0.5)
	var test_full_tile_size := Vector2(1.0, 1.0)

	var hashes: Array[int] = []
	for i in range(10):
		var clipped: PackedVector2Array = _SynthesisScript.clip_polygon_to_subrect(
			test_polygon, test_sub_rect, test_full_tile_size
		)
		hashes.append(hash(Array(clipped)))

	var first_hash := hashes[0]
	var all_match := true
	for i in range(1, 10):
		if hashes[i] != first_hash:
			printerr("FAIL sub-test (b): clip_polygon_to_subrect non-deterministic on run %d: %d != %d" % [i, hashes[i], first_hash])
			all_match = false

	if all_match:
		print("Sub-test (b) — clip_polygon_to_subrect determinism: PASS (10 invocations, hash=%d)" % first_hash)
	else:
		printerr("Sub-test (b) — clip_polygon_to_subrect determinism: FAIL")
		quit(1)


func _run_main_rebuild_test() -> void:
	# Load demo scene, run rebuild() 11 times (run 0 + 10 re-runs),
	# assert all hashes identical AND match BASELINE_HASH.
	var demo_scene_path := "res://addons/penta_tile/demo/penta_tile_demo.tscn"
	var packed := load(demo_scene_path) as PackedScene
	if packed == null:
		printerr("determinism_test: could not load demo scene at " + demo_scene_path)
		quit(1)
		return

	var root_node := packed.instantiate()
	get_root().add_child(root_node)

	# Wait two frames so _ready fires and the deferred rebuild runs.
	await process_frame
	await process_frame

	var layer_node = root_node.find_child("PentaTileMapLayer", true, false)
	if layer_node == null:
		printerr("determinism_test: PentaTileMapLayer node not found in demo scene")
		root_node.queue_free()
		quit(1)
		return

	# Force initial synchronous rebuild.
	if layer_node.has_method("rebuild"):
		layer_node.rebuild()

	var primary = layer_node.get("_primary_layer")
	if primary == null:
		printerr("determinism_test: _primary_layer is null after initial rebuild")
		root_node.queue_free()
		quit(1)
		return

	var data: PackedByteArray = primary.tile_map_data
	var h0: int = hash(Array(data))
	print("Run 0 (initial): hash=%d baseline_match=%s" % [h0, str(h0 == BASELINE_HASH)])

	var all_match := true
	var run_hashes: Array[int] = [h0]

	for i in range(1, 11):
		# Invalidate synthesis cache via _on_layout_changed, then rebuild.
		if layer_node.has_method("_on_layout_changed"):
			layer_node._on_layout_changed()
		layer_node.rebuild()
		var h: int = hash(Array(primary.tile_map_data))
		run_hashes.append(h)
		print("Run %d: hash=%d matches_run0=%s baseline_match=%s" % [
			i, h, str(h == h0), str(h == BASELINE_HASH)])
		if h != h0:
			printerr("FAIL main test: determinism violated on run %d: %d != %d" % [i, h, h0])
			all_match = false

	if all_match and h0 == BASELINE_HASH:
		print("MAIN TEST PASSED — 10 re-runs identical AND match BASELINE_HASH=%d" % BASELINE_HASH)
	elif all_match and h0 != BASELINE_HASH:
		printerr("MAIN TEST WARNING — 10 re-runs internally consistent but hash %d != BASELINE_HASH %d" % [h0, BASELINE_HASH])
		all_match = false
	else:
		printerr("MAIN TEST FAILED — synthesis is non-deterministic")

	root_node.queue_free()

	if not all_match:
		quit(1)
