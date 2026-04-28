## Cross-layout-swap regression test.
##
## User reported: paint a large filled area in Penta layout (slot 0). Switch
## layout to DualGrid16 (with the auto-fill chain rebuilding tile_set to the
## DualGrid16 fallback). The painted region should re-render correctly under
## DualGrid16's mask dispatch — interior cells = mask 15 = atlas (3, 3),
## corners = single-corner masks = atlas (mask%4, mask/4), etc.
##
## Observed bug: large painted region renders mostly empty after swap, with
## only a small row of tiles at one edge of the painted area visible.
##
## This test reproduces the exact scenario:
##   1. Build a layer
##   2. Bind Penta layout (auto-fill picks 5-tile fallback)
##   3. Paint a 12x8 logic-cell rectangle (atlas (0,0) everywhere — matches
##      the user's saved tile_map_data)
##   4. Snapshot painted display-cell count + verify all coords resolve
##   5. Swap layout to DualGrid16 (auto-fill chain rebuilds tile_set fallback)
##   6. Trigger rebuild
##   7. Assert: every painted display cell dispatches to a registered
##      atlas coord in the new tile_set, AND the painted-cell count stays
##      consistent (not zero, no orphans)
##
## Also runs the swap in reverse (DualGrid16 → Penta) for symmetry.
extends SceneTree

const _LayerScript     = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _PentaScript     = preload("res://addons/penta_tile/layouts/penta_tile_layout_penta.gd")
const _DualGrid16Sc    = preload("res://addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd")

var _failures: Array = []


func _initialize() -> void:
	print("=== layout_swap_test ===")
	# 12x8 rectangle of painted cells, all with atlas (0, 0) — matches user's
	# saved demo .tscn (decoded from tile_map_data: 96 cells, x∈[-1,10], y∈[-1,6]).
	var paint_cells: Array = []
	for x in range(-1, 11):
		for y in range(-1, 7):
			paint_cells.append(Vector2i(x, y))
	print("test paint pattern: %d cells (12x8 rectangle)" % paint_cells.size())

	await _test_swap("Penta -> DualGrid16", _PentaScript, _DualGrid16Sc, paint_cells)
	await _test_swap("DualGrid16 -> Penta", _DualGrid16Sc, _PentaScript, paint_cells)

	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		quit(1)


func _test_swap(label: String, layout1_script, layout2_script, paint_cells: Array) -> void:
	print("\n--- " + label + " ---")
	var layer = _LayerScript.new()
	layer.layout = layout1_script.new()
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Paint the rectangle.
	for c: Vector2i in paint_cells:
		layer.set_cell(c, 0, Vector2i(0, 0))
	await process_frame
	await process_frame
	if layer.has_method("rebuild"):
		layer.rebuild()
	await process_frame

	var primary = layer.get("_primary_layer")
	if primary == null:
		_record(label, "_primary_layer null")
		layer.queue_free()
		return

	var painted_pre: int = primary.get_used_cells().size()
	var unrenderable_pre := _count_unrenderable(layer, primary)
	print("  initial layout: painted=%d, unrenderable=%d" % [painted_pre, unrenderable_pre])
	if painted_pre == 0:
		_record(label, "initial layout produced 0 visual cells (paint/dispatch broken)")
	if unrenderable_pre > 0:
		_record(label, "initial layout has %d cells dispatching to non-registered atlas coords" % unrenderable_pre)

	# Swap layout. Auto-fill chain replaces tile_set if it's a fallback.
	layer.layout = layout2_script.new()
	await process_frame
	await process_frame
	if layer.has_method("rebuild"):
		layer.rebuild()
	await process_frame

	var painted_post: int = primary.get_used_cells().size()
	var unrenderable_post := _count_unrenderable(layer, primary)
	print("  after swap:     painted=%d, unrenderable=%d" % [painted_post, unrenderable_post])

	if painted_post == 0:
		_record(label, "after swap produced 0 visual cells (entire painted region disappeared)")
	if unrenderable_post > 0:
		_record(label, "after swap has %d cells dispatching to non-registered atlas coords (will render empty)" % unrenderable_post)

	# Sanity: painted cell count should be roughly the same across layouts —
	# both Penta and DualGrid16 are dual-grid with the same 4-corner expansion,
	# so the AFFECTED display cell set is identical. Different masks may
	# return null for some (e.g., DualGrid16 mask 0 erases) but the bulk
	# should match.
	if painted_post < painted_pre / 2 and painted_pre > 10:
		_record(label, "after swap painted=%d is MUCH less than initial painted=%d (>50%% drop suggests broken dispatch)" % [painted_post, painted_pre])

	layer.queue_free()


func _count_unrenderable(layer: Node, primary: Node) -> int:
	var ts: TileSet = layer.get("_synthesized_tile_set") if layer.get("_synthesized_tile_set") != null else layer.tile_set
	if ts == null or ts.get_source_count() == 0:
		return 0
	var src := ts.get_source(0) as TileSetAtlasSource
	if src == null:
		return 0
	var n := 0
	for cell: Vector2i in primary.get_used_cells():
		var ac: Vector2i = primary.get_cell_atlas_coords(cell)
		if not src.has_tile(ac):
			n += 1
	return n


func _record(label: String, msg: String) -> void:
	_failures.append("[" + label + "] " + msg)
	printerr("  FAIL: " + msg)
