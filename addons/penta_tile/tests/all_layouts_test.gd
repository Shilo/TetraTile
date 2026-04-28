## End-to-end UAT-style test for every concrete PentaTileLayout subclass.
##
## What it does:
##   For each layout (DualGrid16, Wang2Edge, Wang2Corner, Min3x3, Penta-FIVE):
##     1. Fresh PentaTileMapLayer in tree.
##     2. Bind layout — auto-fill should populate tile_set from the bundled
##        greybox via get_fallback_tile_set().
##     3. Paint a deterministic cluster of logic cells.
##     4. After deferred rebuild settles, walk every painted display cell and
##        verify (mask, atlas_coords, transform_flags) against the expected
##        spec table for that layout.
##     5. Confirm the dispatched atlas_coords actually exists in the layer's
##        effective tile_set (synthesized for Penta, fallback for natives).
##     6. Save the layer's tile_map_data as text + the effective atlas image
##        as PNG to user:// for visual diff.
##
## Run headless:
##   Godot --headless --path . --script addons/penta_tile/tests/all_layouts_test.gd
##
## Exits 0 on PASS, 1 on FAIL with details on stderr.
extends SceneTree

const _SlotScript      = preload("res://addons/penta_tile/penta_tile_atlas_slot.gd")
const _LayerScript     = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _LayoutScript    = preload("res://addons/penta_tile/layouts/penta_tile_layout.gd")
const _PentaScript     = preload("res://addons/penta_tile/layouts/penta_tile_layout_penta.gd")
const _DualGrid16Sc    = preload("res://addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd")
const _Wang2EdgeSc     = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd")
const _Wang2CornerSc   = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd")
const _Min3x3Sc        = preload("res://addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd")

# Penta transform flags (mirror PentaTileLayoutPenta._ROTATE_*)
const _ROTATE_0   := 0
const _ROTATE_90  := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
const _ROTATE_180 := TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
const _ROTATE_270 := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V

# Penta locked dispatch table (from penta_tile_layout_penta.gd:154).
# Slot indices: 0=IsolatedCell, 1=Fill, 2=Border, 3=InnerCorner, 4=OppositeCorners.
const PENTA_EXPECTED := {
	0:  null,
	1:  [0, _ROTATE_90],
	2:  [0, _ROTATE_180],
	3:  [2, _ROTATE_180],
	4:  [0, _ROTATE_0],
	5:  [2, _ROTATE_90],
	6:  [4, TileSetAtlasSource.TRANSFORM_FLIP_H],
	7:  [3, _ROTATE_90],
	8:  [0, _ROTATE_270],
	9:  [4, _ROTATE_0],
	10: [2, _ROTATE_270],
	11: [3, _ROTATE_180],
	12: [2, _ROTATE_0],
	13: [3, _ROTATE_0],
	14: [3, _ROTATE_270],
	15: [1, _ROTATE_0],
}

# Failures collected across all layouts.
var _failures: Array = []


func _initialize() -> void:
	print("=== all_layouts_test ===")
	await _test_layout("DualGrid16",   _DualGrid16Sc.new(),  Callable(self, "_expected_dual_grid_16"))
	await _test_layout("Wang2Edge",    _Wang2EdgeSc.new(),   Callable(self, "_expected_wang_2_edge"))
	await _test_layout("Wang2Corner",  _Wang2CornerSc.new(), Callable(self, "_expected_wang_2_corner"))
	await _test_layout("Minimal3x3",   _Min3x3Sc.new(),      Callable(self, "_expected_min_3x3"))

	# Penta — explicit FIVE mode so all 5 archetypes are authored, no synthesis.
	# That isolates the dispatch table check from the synthesis math.
	var penta := _PentaScript.new()
	penta.set("axis", 0)            # HORIZONTAL
	penta.set("tile_count", 5)      # FIVE
	await _test_layout("Penta-FIVE-H", penta, Callable(self, "_expected_penta"))

	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d failures):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		quit(1)


# Per-layout test runner. Asserts (mask, atlas_coords, transform) for each
# painted display cell against the expected_fn. expected_fn(mask) returns
# null OR Vector3i where x=col, y=row, z=transform_flags (using Vector3i so
# we can pack 3 ints into one return value).
func _test_layout(label: String, layout: Resource, expected_fn: Callable) -> void:
	print("\n--- %s ---" % label)
	var layer = _LayerScript.new()
	layer.layout = layout                         # auto-fills tile_set via fallback
	get_root().add_child(layer)

	# Wait for _ready + deferred rebuild to settle.
	await process_frame
	await process_frame

	# Sanity: tile_set must be auto-populated.
	if layer.tile_set == null:
		_record(label, "tile_set is null after layout assign — auto-fill failed")
		layer.queue_free()
		return

	# Paint a deterministic test cluster: enough patterns to exercise all
	# 16 mask states for the layout's neighbor topology. Strategy: paint
	# a 5×5 grid of logic cells, then verify the resulting display cells.
	# Different layouts hit different mask subsets from the same logic-cell
	# pattern — that's expected; we only assert what dispatches actually
	# happen, not 100% mask coverage.
	var logic_cells: Array[Vector2i] = []
	# Single cell (isolated)
	logic_cells.append(Vector2i(-3, 0))
	# 2×1 horizontal
	logic_cells.append_array([Vector2i(-1, 0), Vector2i(0, 0)])
	# 2×2 block
	logic_cells.append_array([Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1)])
	# L-shape
	logic_cells.append_array([Vector2i(-3, 3), Vector2i(-2, 3), Vector2i(-3, 4)])
	# 3×3 block
	logic_cells.append_array([
		Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3),
		Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4),
		Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5),
	])
	# Diagonal pair (mask 6/9 territory for Penta dual-grid)
	logic_cells.append_array([Vector2i(5, 0), Vector2i(6, 1)])

	for c in logic_cells:
		layer.set_cell(c, 0, Vector2i.ZERO)

	await process_frame
	await process_frame

	var primary = layer.get("_primary_layer")
	if primary == null:
		_record(label, "_primary_layer is null after paint")
		layer.queue_free()
		return

	# The effective tile_set under which dispatch lands. For Penta this is
	# the synthesized atlas; for natives it's the layer's tile_set itself.
	var effective_ts: TileSet = layer.get("_synthesized_tile_set") if layer.get("_synthesized_tile_set") != null else layer.tile_set
	var effective_src := effective_ts.get_source(0) as TileSetAtlasSource if effective_ts.get_source_count() > 0 else null
	if effective_src == null:
		_record(label, "effective tile_set has no atlas source 0")
		layer.queue_free()
		return

	# Walk every painted display cell.
	var sample_fn := Callable(layer, "_has_logic_cell")
	var painted_count := 0
	var fail_count := 0
	var first_fail_msgs: Array = []

	for display_cell in primary.get_used_cells():
		painted_count += 1
		var mask: int = layout.compute_mask(display_cell, sample_fn)
		var actual_coords: Vector2i = primary.get_cell_atlas_coords(display_cell)
		var actual_alt: int = primary.get_cell_alternative_tile(display_cell)
		var actual_transform := actual_alt & ~0xfff   # transform flags occupy >= 4096

		var expected: Variant = expected_fn.call(mask)
		if expected == null:
			# Spec says erase, but cell is painted → bug.
			fail_count += 1
			if first_fail_msgs.size() < 5:
				first_fail_msgs.append("cell %s mask=%d should be erased but rendered (%s, transform=%d)" % [display_cell, mask, actual_coords, actual_transform])
			continue

		var exp_coords: Vector2i = expected[0]
		var exp_transform: int = expected[1]
		var coords_match := actual_coords == exp_coords
		var transform_match := actual_transform == exp_transform
		var has_tile := effective_src.has_tile(actual_coords)

		if not coords_match or not transform_match or not has_tile:
			fail_count += 1
			if first_fail_msgs.size() < 5:
				var why: Array = []
				if not coords_match:
					why.append("coords %s != expected %s" % [actual_coords, exp_coords])
				if not transform_match:
					why.append("transform %d != expected %d" % [actual_transform, exp_transform])
				if not has_tile:
					why.append("atlas %s not in effective_src" % actual_coords)
				first_fail_msgs.append("cell %s mask=%d: %s" % [display_cell, mask, ", ".join(why)])

	# Also verify any logic cell that should produce mask=0 around an
	# isolated point (single cell at -3,0): for layouts where mask=0 means
	# erase, the corresponding display cells should NOT be in get_used_cells.
	# We don't enforce this — different layouts have different topology.

	print("  painted display cells: %d, failures: %d" % [painted_count, fail_count])
	for m in first_fail_msgs:
		print("    " + m)

	# Dump effective atlas image for visual diff.
	var atlas_img: Image = effective_src.texture.get_image() if effective_src.texture else null
	if atlas_img != null:
		var atlas_path := "user://layout_%s_atlas.png" % label.to_lower().replace("-", "_")
		atlas_img.save_png(atlas_path)
		print("  atlas dumped: " + ProjectSettings.globalize_path(atlas_path))

	# Dump painted state as text (cell, mask, atlas, transform).
	var state_path := "user://layout_%s_state.txt" % label.to_lower().replace("-", "_")
	var state_lines: Array = ["layout=" + label, "painted=" + str(painted_count), "failures=" + str(fail_count), ""]
	state_lines.append("display_cell\tmask\tatlas_coords\ttransform")
	for display_cell in primary.get_used_cells():
		var mask: int = layout.compute_mask(display_cell, sample_fn)
		var ac: Vector2i = primary.get_cell_atlas_coords(display_cell)
		var alt: int = primary.get_cell_alternative_tile(display_cell)
		var transform := alt & ~0xfff
		state_lines.append("%s\t%d\t%s\t%d" % [display_cell, mask, ac, transform])
	var state_file := FileAccess.open(state_path, FileAccess.WRITE)
	if state_file != null:
		state_file.store_string("\n".join(state_lines))
		state_file.close()
		print("  state dumped: " + ProjectSettings.globalize_path(state_path))

	if fail_count > 0:
		_record(label, "%d/%d painted cells failed expected dispatch" % [fail_count, painted_count])

	layer.queue_free()


func _record(label: String, msg: String) -> void:
	var entry := "[%s] %s" % [label, msg]
	_failures.append(entry)
	printerr("  FAIL: " + msg)


# ----- Expected dispatch tables (per-layout) -----

# DualGrid16: mask N → (N % 4, N / 4), no transform.
func _expected_dual_grid_16(mask: int) -> Variant:
	if mask == 0:
		return null
	return [Vector2i(mask % 4, mask / 4), 0]


# Wang2Edge: atlas (mask % 4, mask / 4). Single-grid layouts dispatch mask=0
# to atlas (0, 0) (a logic-painted isolated cell still needs to render).
func _expected_wang_2_edge(mask: int) -> Variant:
	return [Vector2i(mask % 4, mask / 4), 0]


# Wang2Corner: same atlas coordinate formula as Wang2Edge.
func _expected_wang_2_corner(mask: int) -> Variant:
	return [Vector2i(mask % 4, mask / 4), 0]


# Min3x3: open-side rule.
#   open_t=(mask&1)==0, open_e=(mask&2)==0, open_b=(mask&4)==0, open_w=(mask&8)==0
#   col = 0 if (open_w and not open_e) else 2 if (open_e and not open_w) else 1
#   row = 0 if (open_t and not open_b) else 2 if (open_b and not open_t) else 1
func _expected_min_3x3(mask: int) -> Variant:
	# mask=0 falls through to (1, 1) center per the open-side rule (all open
	# means neither col 0 nor col 2, neither row 0 nor row 2). Logic-painted
	# isolated cells must still render in single-grid layouts.
	var open_t := (mask & 1) == 0
	var open_e := (mask & 2) == 0
	var open_b := (mask & 4) == 0
	var open_w := (mask & 8) == 0
	var col := 1
	if open_w and not open_e:
		col = 0
	elif open_e and not open_w:
		col = 2
	var row := 1
	if open_t and not open_b:
		row = 0
	elif open_b and not open_t:
		row = 2
	return [Vector2i(col, row), 0]


# Penta in FIVE mode: pure-authored 5-tile dispatch per the locked table.
func _expected_penta(mask: int) -> Variant:
	if mask == 0:
		return null
	var entry: Array = PENTA_EXPECTED[mask]
	# entry = [slot_index, transform]; output coord = (slot, 0) for non-AUTO_STRIP.
	return [Vector2i(entry[0], 0), entry[1]]
