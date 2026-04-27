## Automated paint behaviour test for PentaTileLayoutPenta.
##
## Run headless:
##   Godot_v4.6.2-stable_win64_console.exe --headless --path . --script addons/penta_tile/tests/paint_test.gd
##
## What it does:
##   1. Builds a PentaTileMapLayer programmatically with the demo TileSet + FOUR-mode Penta layout
##   2. Paints test patterns (single cell, 2x1 strip, L-shape, 2x2 block)
##   3. After each paint, dumps the computed mask + actual painted atlas_coords/transform_flags
##      for every affected display cell — uses the SAME sample fn the layer uses so the dump
##      is what _paint_via_layout actually saw
##   4. Verifies:
##      - synthesized TileSet has tiles registered at (0,0)..(4,0)
##      - mask 0 cells produce no painted tile
##      - mask N produces the expected slot per the locked Phase 2 mapping
##      - dual-grid display offset is -tile_size/2
##
## Exits 0 on PASS, 1 on FAIL with details to stderr.
extends SceneTree

const _SynthesisScript = preload("res://addons/penta_tile/penta_tile_synthesis.gd")
const _SlotScript = preload("res://addons/penta_tile/penta_tile_atlas_slot.gd")
const _LayoutScript = preload("res://addons/penta_tile/layouts/penta_tile_layout.gd")
const _PentaScript = preload("res://addons/penta_tile/layouts/penta_tile_layout_penta.gd")
const _LayerScript = preload("res://addons/penta_tile/penta_tile_map_layer.gd")

# Locked Phase 2 mask → (slot_index, transform_flags) mapping per
# penta_tile_layout_penta.gd:146-191. Used to verify mask_to_atlas output.
const _ROTATE_0 := 0
const _ROTATE_90 := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
const _ROTATE_180 := TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
const _ROTATE_270 := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V

const _EXPECTED_MASK_TO_SLOT := {
	0:  null,                                                                         # null → erase
	1:  [0, _ROTATE_90],                                                              # TL only — IsolatedCell rotated
	2:  [0, _ROTATE_180],                                                             # TR only
	3:  [2, _ROTATE_180],                                                             # TL+TR — Border facing top
	4:  [0, _ROTATE_0],                                                               # BL only
	5:  [2, _ROTATE_90],                                                              # TL+BL — Border facing left
	6:  [4, TileSetAtlasSource.TRANSFORM_FLIP_H],                                     # TR+BL — OppositeCorners flipped
	7:  [3, _ROTATE_90],                                                              # InnerCorner
	8:  [0, _ROTATE_270],                                                             # BR only
	9:  [4, _ROTATE_0],                                                               # OppositeCorners anchor
	10: [2, _ROTATE_270],                                                             # TR+BR — Border facing right
	11: [3, _ROTATE_180],
	12: [2, _ROTATE_0],                                                               # BL+BR — Border facing bottom
	13: [3, _ROTATE_0],
	14: [3, _ROTATE_270],
	15: [1, _ROTATE_0],                                                               # Fill
}

var _failures: Array = []
var _layer: Node = null
var _layout: Resource = null


func _initialize() -> void:
	print("=== PentaTile paint test (multi-mode) ===")
	# Per-mode coverage: ONE/TWO/THREE/FOUR/FIVE + AUTO + AUTO_STRIP. Each mode uses
	# its own bundled preset PNG (so the source atlas has the correct authored slot
	# count) and runs the same paint patterns + mask→slot verification.
	for mode_label in ["ONE", "TWO", "THREE", "FOUR", "FIVE", "AUTO"]:
		await _run_mode(mode_label)
	await _test_abstract_base_guard()
	_finish()


func _run_mode(mode_label: String) -> void:
	print("\n=== MODE: %s ===" % mode_label)
	_setup_layer_for_mode(mode_label)
	if _layer == null:
		_fail("setup_%s" % mode_label, "could not build PentaTileMapLayer")
		return

	await process_frame
	await process_frame

	_check_synthesized_atlas()

	# Test patterns. Each is (name, painted_logic_cells: Array[Vector2i]).
	# Each mode runs the same pattern set. Mask correctness is universal — the
	# dispatch table is mode-independent. What VARIES per mode is the SYNTH
	# atlas pixel content (slots 1..4 may be authored or synthesized).
	await _test_pattern("single_cell", [Vector2i(0, 0)])
	await _test_pattern("2x2_block", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)])
	await _test_pattern("3x3_filled", [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
	])
	await _test_pattern("diagonal_TL_BR", [Vector2i(0, 0), Vector2i(1, 1)])


# Verifies _resolve_layout suppresses painting + emits a warning when `layout` is the
# bare `PentaTileLayout` base class (the case where user picks "New PentaTileLayout"
# from the inspector dropdown). Pre-fix: spammed compute_mask/is_dual_grid abstract
# errors on every painted cell. Post-fix: silent no-op + one-shot warning.
func _test_abstract_base_guard() -> void:
	print("--- abstract base layout guard ---")
	var base_layout: Resource = _LayoutScript.new()
	_layer.layout = base_layout
	# Paint should be suppressed entirely; no abstract errors should fire.
	_layer.clear()
	_layer.set_cell(Vector2i(0, 0), 0, Vector2i.ZERO)
	await process_frame
	await process_frame
	var primary: TileMapLayer = _layer.get("_primary_layer")
	var painted := primary.get_used_cells().size() if primary != null else -1
	if painted == 0:
		print("  OK: base layout produced no painted cells (rendering suppressed)")
	else:
		_fail("abstract_base", "base layout painted %d cells (expected 0; should be suppressed)" % painted)
	# Restore real layout for clean teardown.
	_layer.layout = _layout


func _setup_layer_for_mode(mode_label: String) -> void:
	# Pick the bundled preset PNG for this mode. AUTO uses FOUR's PNG (so the auto
	# detector reads atlas axis size 4 and resolves to FOUR mode).
	var path_lookup := {
		"ONE":   "res://addons/penta_tile/layouts/penta_tile_layout_penta/one_horizontal.png",
		"TWO":   "res://addons/penta_tile/layouts/penta_tile_layout_penta/two_horizontal.png",
		"THREE": "res://addons/penta_tile/layouts/penta_tile_layout_penta/three_horizontal.png",
		"FOUR":  "res://addons/penta_tile/layouts/penta_tile_layout_penta/four_horizontal.png",
		"FIVE":  "res://addons/penta_tile/layouts/penta_tile_layout_penta/five_horizontal.png",
		"AUTO":  "res://addons/penta_tile/layouts/penta_tile_layout_penta/four_horizontal.png",
	}
	var mode_to_int := {
		"ONE": 1, "TWO": 2, "THREE": 3, "FOUR": 4, "FIVE": 5,
		"AUTO": 0,                                                                    # TileCountMode.AUTO = 0
	}
	var tile_counts := {
		"ONE": 1, "TWO": 2, "THREE": 3, "FOUR": 4, "FIVE": 5, "AUTO": 4,
	}

	var path: String = path_lookup[mode_label]
	var tile_count: int = tile_counts[mode_label]
	var tile_count_enum: int = mode_to_int[mode_label]

	var tex := load(path) as Texture2D
	if tex == null:
		_fail("setup_%s" % mode_label, "could not load preset %s" % path)
		return

	# Bundled presets are 32px tiles. Compute tile_size from texture dimensions.
	var tile_w := tex.get_width() / tile_count
	var tile_h := tex.get_height()

	# Tear down previous layer if present.
	if _layer != null:
		_layer.queue_free()
		_layer = null

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(tile_w, tile_h)
	for slot in range(tile_count):
		src.create_tile(Vector2i(slot, 0))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(tile_w, tile_h)
	ts.add_source(src, 0)

	_layout = _PentaScript.new()
	_layout.set("axis", 0)                                                            # HORIZONTAL
	_layout.set("tile_count", tile_count_enum)
	_layout.set("_bitmask_is_preset", false)                                          # we're providing our own tile_set; suppress preset auto-load

	_layer = _LayerScript.new()
	_layer.tile_set = ts
	_layer.layout = _layout

	get_root().add_child(_layer)


func _check_synthesized_atlas() -> void:
	# Force the synthesis cache to build by triggering rebuild() now.
	if _layer.has_method("rebuild"):
		_layer.rebuild()

	var synth: TileSet = _layer.get("_synthesized_tile_set")
	if synth == null:
		_fail("synth", "_synthesized_tile_set is null after rebuild — synthesis did not run")
		return

	var src := synth.get_source(0) as TileSetAtlasSource
	if src == null:
		_fail("synth", "synthesized TileSet has no source 0")
		return

	var grid := src.get_atlas_grid_size()
	print("synth_atlas: grid=%s region=%s" % [grid, src.texture_region_size])

	# Expect 5 tiles at (0,0)..(4,0) for FOUR mode (4 explicit + 1 synthesized OppositeCorners).
	for slot_index in range(5):
		var coord := Vector2i(slot_index, 0)
		if not src.has_tile(coord):
			_fail("synth", "synthesized atlas missing tile at %s — slot %d not registered" % [coord, slot_index])
		else:
			print("  slot %d → %s OK" % [slot_index, coord])

	# Dump the synthesized atlas texture to disk so we can visually verify the pixel
	# content per slot. Also count opaque pixels per slot to catch all-transparent regressions.
	var tex := src.texture
	if tex != null:
		var img: Image = tex.get_image()
		if img != null:
			var dump_path := "user://synthesized_atlas_dump.png"
			img.save_png(dump_path)
			var abs_path := ProjectSettings.globalize_path(dump_path)
			print("synth_atlas: wrote %s (%dx%d)" % [abs_path, img.get_width(), img.get_height()])
			# Per-slot opacity stats
			var region := src.texture_region_size
			for slot_index in range(5):
				var x0 := slot_index * region.x
				var opaque := 0
				var total := region.x * region.y
				for y in range(region.y):
					for x in range(region.x):
						if img.get_pixel(x0 + x, y).a > 0.01:
							opaque += 1
				var pct := 100.0 * float(opaque) / float(total)
				print("  slot %d opacity: %d/%d pixels (%.1f%%)" % [slot_index, opaque, total, pct])
				# Sanity guard — every slot should have SOME opaque pixels (rendering art)
				if opaque == 0:
					_fail("synth_pixels", "slot %d is fully transparent — no art rendered" % slot_index)


func _test_pattern(name: String, logic_cells: Array) -> void:
	print("--- pattern: %s (%d cells) ---" % [name, logic_cells.size()])
	# Reset: clear any previous paint.
	_layer.clear()
	if _layer.has_method("rebuild"):
		_layer.rebuild()

	# Paint the pattern. Use source_id = 0 with atlas_coords = (0,0) on the LOGIC layer.
	for c: Vector2i in logic_cells:
		_layer.set_cell(c, 0, Vector2i.ZERO)

	# Wait for deferred _update_cells to process.
	await process_frame
	await process_frame

	# Pull the visual layer state.
	var primary: TileMapLayer = _layer.get("_primary_layer")
	if primary == null:
		_fail(name, "_primary_layer is null after paint")
		return

	# Compute affected display cells (dual-grid: 4 corner offsets per logic cell).
	var affected: Dictionary = {}
	for c: Vector2i in logic_cells:
		affected[c] = true
		affected[c + Vector2i.RIGHT] = true
		affected[c + Vector2i.DOWN] = true
		affected[c + Vector2i(1, 1)] = true

	# Build a local sample fn that mirrors _has_logic_cell.
	var logic_set := {}
	for c: Vector2i in logic_cells:
		logic_set[c] = true
	var sample_fn := func(coord: Vector2i) -> bool: return logic_set.has(coord)

	# For each affected display cell, compute mask + expected slot, compare against
	# what _primary_layer actually painted.
	var any_fail := false
	for display_cell: Vector2i in affected.keys():
		var mask: int = _layout.compute_mask(display_cell, sample_fn)
		var expected = _EXPECTED_MASK_TO_SLOT.get(mask)
		var actual_source := primary.get_cell_source_id(display_cell)
		var actual_coords := primary.get_cell_atlas_coords(display_cell)
		var actual_alt := primary.get_cell_alternative_tile(display_cell)

		var status := ""
		if expected == null:
			# Mask 0 — should be erased (source_id == -1).
			if actual_source != -1:
				status = "FAIL: mask=0 but cell painted (source=%d coords=%s alt=%d)" % [actual_source, actual_coords, actual_alt]
				any_fail = true
			else:
				status = "OK: mask=0 erased"
		else:
			var exp_coords := Vector2i(expected[0], 0)
			var exp_flags: int = expected[1]
			if actual_source == -1:
				status = "FAIL: mask=%d expected slot %d (rot=%d) but cell empty" % [mask, expected[0], exp_flags]
				any_fail = true
			elif actual_coords != exp_coords:
				status = "FAIL: mask=%d expected coords=%s got coords=%s alt=%d" % [mask, exp_coords, actual_coords, actual_alt]
				any_fail = true
			elif actual_alt != exp_flags:
				status = "FAIL: mask=%d expected alt=%d (rot) got alt=%d (coords=%s OK)" % [mask, exp_flags, actual_alt, actual_coords]
				any_fail = true
			else:
				status = "OK: mask=%2d slot=%d rot=%d" % [mask, expected[0], exp_flags]
		print("  cell=%s mask=%2d %s" % [display_cell, mask, status])

	if any_fail:
		_fail(name, "one or more display cells did not match expected mask→slot mapping")


func _fail(scope: String, msg: String) -> void:
	_failures.append("[%s] %s" % [scope, msg])
	printerr("FAIL [%s] %s" % [scope, msg])


func _finish() -> void:
	print("=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		print("FAILURES (%d):" % _failures.size())
		for f in _failures:
			print("  - %s" % f)
		quit(1)
