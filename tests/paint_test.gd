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

# Native layout subclass scripts — preloaded so headless runs hit parse-time
# signature checks even though paint_test only instantiates PentaTileLayoutPenta
# directly. Without these preloads, base-class signature drift on virtuals like
# `mask_to_atlas` only surfaces when the editor parses every script at startup
# (and the headless test passes against a broken project).
const _DualGrid16Script = preload("res://addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd")
const _Wang2EdgeScript = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd")
const _Wang2CornerScript = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd")
const _Min3x3Script = preload("res://addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd")

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
	print("=== PentaTile paint test ===")
	_setup_layer()
	if _layer == null:
		_fail("setup", "could not build PentaTileMapLayer")
		_finish()
		return

	# Wait for _ready and deferred rebuild.
	await process_frame
	await process_frame

	_check_synthesized_atlas()

	# Test patterns. Each is (name, painted_logic_cells: Array[Vector2i]).
	await _test_pattern("single_cell", [Vector2i(0, 0)])
	await _test_pattern("2x1_horizontal", [Vector2i(0, 0), Vector2i(1, 0)])
	await _test_pattern("2x1_vertical", [Vector2i(0, 0), Vector2i(0, 1)])
	await _test_pattern("2x2_block", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)])
	await _test_pattern("L_shape", [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)])
	await _test_pattern("3x3_filled", [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
	])
	await _test_pattern("diagonal_TL_BR", [Vector2i(0, 0), Vector2i(1, 1)])
	await _test_pattern("diagonal_TR_BL", [Vector2i(1, 0), Vector2i(0, 1)])

	# AUTO_STRIP per-strip dispatch tests (Interpretation A — strips perpendicular to slot axis).
	#   (a) uniform-mode strips     — confirms 5×N output atlas builds correctly
	#   (b) mixed-mode strips       — strip 0 THREE, strip 1 FIVE; per-cell strip routing works
	#   (c) gap strip               — strip with internal hole; verifies warning C fires
	#   (d) VERTICAL axis strips    — strips are columns instead of rows
	await _test_auto_strip_uniform()
	await _test_auto_strip_mixed_modes()
	await _test_auto_strip_with_gap()
	await _test_auto_strip_vertical()

	await _test_abstract_base_guard()

	# Native-layout bitmask_template auto-fill — every concrete layout subclass
	# must seed `bitmask_template` from its bundled PNG on _init so the inspector
	# preview is non-null without manual user assignment, AND the value serializes
	# into .tres files when the resource is saved.
	_test_native_layout_bitmask_autofill()

	# Mode-less-than-axis-size dispatch — tile_count=THREE on a 5-tile atlas must
	# copy slots 0..2 from source and synthesize slots 3..4 from slot 0. Confirms
	# the explicit-mode-overrides-detection path works as the locked spec.
	await _test_explicit_mode_smaller_than_atlas()

	_finish()


# Build a synthetic multi-strip source TileSet. `strip_modes` = mode counts per strip
# (e.g. [3, 5] = strip 0 has 3 authored tiles, strip 1 has 5). `axis` = 0 HORIZONTAL
# (strips are rows running along X, varying Y), 1 VERTICAL (strips are columns).
# `gap_coords` = optional Array[Vector2i] of atlas coords to leave empty (creates
# the AUTO_STRIP gap warning C scenario when there's a populated tile after the gap).
#
# Builds a synthetic Image sized to fit ALL atlas coords this layout could touch,
# filled with opaque gray pixel content (synthesis doesn't care about pixel quality
# at this layer — paint_test verifies dispatch math + atlas registration, not art).
func _build_multistrip_layer(strip_modes: Array, axis: int, gap_coords: Array = []) -> Node:
	var TILE := 16
	# Compute the bounding atlas grid this fixture needs.
	# HORIZONTAL: cols = max(mode), rows = strip_count
	# VERTICAL:   cols = strip_count, rows = max(mode)
	var max_mode := 0
	for m in strip_modes:
		max_mode = max(max_mode, int(m))
	var grid_cols: int
	var grid_rows: int
	if axis == 0:
		grid_cols = max_mode
		grid_rows = strip_modes.size()
	else:
		grid_cols = strip_modes.size()
		grid_rows = max_mode

	# Synthesize an opaque-gray Image sized to the bounding grid. Pixel quality is
	# irrelevant for dispatch tests — we just need the create_tile bounds-check to pass.
	var img := Image.create(grid_cols * TILE, grid_rows * TILE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 1.0))                                              # solid gray
	var tex := ImageTexture.create_from_image(img)

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)

	# Build a gap lookup keyed by Vector2i atlas coord directly.
	var gap_set := {}
	for g in gap_coords:
		gap_set[g as Vector2i] = true

	# Create tiles per strip's mode count, skipping gap entries.
	for strip_index in range(strip_modes.size()):
		var mode_count: int = int(strip_modes[strip_index])
		for slot in range(mode_count):
			var coord: Vector2i
			if axis == 0:                                                            # HORIZONTAL: strips are rows
				coord = Vector2i(slot, strip_index)
			else:                                                                    # VERTICAL: strips are columns
				coord = Vector2i(strip_index, slot)
			if gap_set.has(coord):
				continue
			src.create_tile(coord)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)

	var layout: Resource = _PentaScript.new()
	layout.set("axis", axis)
	layout.set("tile_count", -1)                                                      # AUTO_STRIP enum value
	layout.set("_bitmask_is_preset", false)                                           # we provide our own tile_set

	var layer = _LayerScript.new()
	layer.tile_set = ts
	layer.layout = layout
	get_root().add_child(layer)
	return layer


# (a) AUTO_STRIP uniform-mode strips: 2 strips both at THREE. Verifies multi-row
#     output atlas builds correctly + per-strip dispatch lands at correct row.
func _test_auto_strip_uniform() -> void:
	print("\n--- AUTO_STRIP uniform [THREE, THREE] HORIZONTAL ---")
	var layer = _build_multistrip_layer([3, 3], 0)
	if layer == null:
		return
	await process_frame
	await process_frame
	if layer.has_method("rebuild"):
		layer.rebuild()

	var synth: TileSet = layer.get("_synthesized_tile_set")
	if synth == null:
		_fail("auto_strip_uniform", "synthesized atlas null")
		layer.queue_free()
		return
	var src := synth.get_source(0) as TileSetAtlasSource
	var grid := src.get_atlas_grid_size()
	print("  synth atlas grid=%s (expected (5, 2))" % grid)
	if grid != Vector2i(5, 2):
		_fail("auto_strip_uniform", "expected synth grid (5,2), got %s" % grid)
	# Both strips populated → all 10 tiles registered.
	for strip_index in range(2):
		for slot in range(5):
			if not src.has_tile(Vector2i(slot, strip_index)):
				_fail("auto_strip_uniform", "synth atlas missing tile (%d, %d)" % [slot, strip_index])

	# Per-strip dispatch: paint a cell on strip 0 (logic-atlas (0, 0)), verify mask=15
	# (Fill cell at center of 2x2 paint) lands at synth (1, 0). Then paint on strip 1
	# (logic-atlas (0, 1)), verify mask=15 lands at synth (1, 1).
	for strip_index in range(2):
		layer.clear()
		# 2x2 painted block routes mask=15 (TL+TR+BL+BR all filled) at the center display cell.
		var origin := Vector2i(0, 0)
		var atlas_for_strip := Vector2i(0, strip_index)
		for offset in [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)]:
			layer.set_cell(origin + offset, 0, atlas_for_strip)
		await process_frame
		await process_frame
		var primary: TileMapLayer = layer.get("_primary_layer")
		# Center display cell = (1, 1) for a 2x2 block at origin (0,0).
		var center_display := Vector2i(1, 1)
		var actual_coords := primary.get_cell_atlas_coords(center_display)
		var expected_coords := Vector2i(1, strip_index)                              # slot 1 = Fill, row = strip
		if actual_coords != expected_coords:
			_fail("auto_strip_uniform", "strip %d Fill dispatch: expected %s got %s" % [strip_index, expected_coords, actual_coords])
		else:
			print("  strip %d Fill dispatch OK: synth coord %s" % [strip_index, actual_coords])
	layer.queue_free()


# (b) AUTO_STRIP mixed modes: strip 0 = THREE, strip 1 = FIVE. Verifies different
#     strips can have different mode counts in the same atlas.
func _test_auto_strip_mixed_modes() -> void:
	print("\n--- AUTO_STRIP mixed [THREE, FIVE] HORIZONTAL ---")
	var layer = _build_multistrip_layer([3, 5], 0)
	if layer == null:
		return
	await process_frame
	await process_frame
	if layer.has_method("rebuild"):
		layer.rebuild()

	var synth: TileSet = layer.get("_synthesized_tile_set")
	if synth == null:
		_fail("auto_strip_mixed", "synthesized atlas null")
		layer.queue_free()
		return
	var src := synth.get_source(0) as TileSetAtlasSource
	# Both strips synthesize to 5 output slots (the synth always emits 5; mode just
	# changes which slots are authored vs synthesized). So output grid is (5, 2).
	for strip_index in range(2):
		for slot in range(5):
			if not src.has_tile(Vector2i(slot, strip_index)):
				_fail("auto_strip_mixed", "synth atlas missing tile (%d, %d)" % [slot, strip_index])
	print("  synth atlas grid=%s (both strips populated 5 slots each)" % src.get_atlas_grid_size())

	# Per-strip dispatch: same as uniform test but with strip 1 in FIVE mode.
	for strip_index in range(2):
		layer.clear()
		var atlas_for_strip := Vector2i(0, strip_index)
		for offset in [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)]:
			layer.set_cell(offset, 0, atlas_for_strip)
		await process_frame
		await process_frame
		var primary: TileMapLayer = layer.get("_primary_layer")
		var actual_coords := primary.get_cell_atlas_coords(Vector2i(1, 1))
		var expected_coords := Vector2i(1, strip_index)
		if actual_coords != expected_coords:
			_fail("auto_strip_mixed", "strip %d Fill dispatch: expected %s got %s" % [strip_index, expected_coords, actual_coords])
		else:
			print("  strip %d Fill dispatch OK: synth coord %s" % [strip_index, actual_coords])
	layer.queue_free()


# (c) AUTO_STRIP with internal gap. Strip 0 = FOUR with a hole at slot 1 (TL exists,
#     slot 1 empty, slot 2 exists). resolve_strip_modes should detect the gap and
#     return AUTO (-1) for that strip; configuration warning C should fire.
func _test_auto_strip_with_gap() -> void:
	print("\n--- AUTO_STRIP with gap [FOUR-with-hole] HORIZONTAL ---")
	# Build a single horizontal strip with mode count 4 BUT a hole at slot 1: tiles at
	# (0,0), (2,0), (3,0) — slot (1,0) is the gap. resolve_strip_modes counts
	# CONSECUTIVE populated slots from slot 0 → finds 1, then slot 1 empty but slot 2
	# populated → gap detected → returns AUTO (-1).
	var layer = _build_multistrip_layer([4], 0, [Vector2i(1, 0)])                    # gap at (slot=1, strip=0)
	if layer == null:
		return
	await process_frame
	await process_frame
	if layer.has_method("rebuild"):
		layer.rebuild()

	# Configuration warnings — verify Warning C fires.
	var layout = layer.layout
	var warnings: PackedStringArray = layout.get_configuration_warnings_for(layer.tile_set, 0)
	var saw_gap_warning := false
	for w in warnings:
		if "AUTO_STRIP" in w and "gap" in w:
			saw_gap_warning = true
			print("  warning C fired: %s" % w)
	if not saw_gap_warning:
		_fail("auto_strip_gap", "expected AUTO_STRIP gap warning (C); got warnings=%s" % str(warnings))

	# Synthesized atlas should have NO tiles in the gap strip's row.
	var synth: TileSet = layer.get("_synthesized_tile_set")
	if synth != null:
		var src := synth.get_source(0) as TileSetAtlasSource
		if src != null:
			# Strip 0 was AUTO (-1) due to gap → its row in the synth atlas is empty.
			var any_in_gap_row := false
			for slot in range(5):
				if src.has_tile(Vector2i(slot, 0)):
					any_in_gap_row = true
					break
			if any_in_gap_row:
				_fail("auto_strip_gap", "gap strip should produce empty row in synth atlas; found tiles")
			else:
				print("  gap strip row 0 is empty in synth atlas (graceful degradation OK)")
	layer.queue_free()


# (d) AUTO_STRIP VERTICAL axis: strips are columns. [4, 2] modes mean column 0 has
#     4 authored slots running down (Y) and column 1 has 2.
func _test_auto_strip_vertical() -> void:
	print("\n--- AUTO_STRIP VERTICAL [FOUR, TWO] ---")
	var layer = _build_multistrip_layer([4, 2], 1)
	if layer == null:
		return
	await process_frame
	await process_frame
	if layer.has_method("rebuild"):
		layer.rebuild()

	var synth: TileSet = layer.get("_synthesized_tile_set")
	if synth == null:
		_fail("auto_strip_vertical", "synthesized atlas null")
		layer.queue_free()
		return
	var src := synth.get_source(0) as TileSetAtlasSource
	# Output atlas is ALWAYS 5 cols × N rows regardless of source axis (WR-07 extension).
	# For VERTICAL source with 2 strips → output grid (5, 2).
	var grid := src.get_atlas_grid_size()
	print("  synth atlas grid=%s (output is 5 cols × N rows regardless of axis)" % grid)
	for strip_index in range(2):
		for slot in range(5):
			if not src.has_tile(Vector2i(slot, strip_index)):
				_fail("auto_strip_vertical", "synth atlas missing tile (%d, %d)" % [slot, strip_index])

	# Per-strip dispatch: VERTICAL axis means strip_index = atlas_coords.x.
	# Paint with logic-atlas (strip_index, 0) and verify dispatch.
	for strip_index in range(2):
		layer.clear()
		var atlas_for_strip := Vector2i(strip_index, 0)
		for offset in [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)]:
			layer.set_cell(offset, 0, atlas_for_strip)
		await process_frame
		await process_frame
		var primary: TileMapLayer = layer.get("_primary_layer")
		var actual_coords := primary.get_cell_atlas_coords(Vector2i(1, 1))
		var expected_coords := Vector2i(1, strip_index)
		if actual_coords != expected_coords:
			_fail("auto_strip_vertical", "strip %d (VERTICAL) Fill dispatch: expected %s got %s" % [strip_index, expected_coords, actual_coords])
		else:
			print("  VERTICAL strip %d Fill dispatch OK: synth coord %s" % [strip_index, actual_coords])
	layer.queue_free()


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


func _setup_layer() -> void:
	# Build a PentaTileMapLayer programmatically. Uses the BUNDLED FOUR-mode
	# greybox PNG (full-silhouette slot 0) as the source so FOUR-mode synthesis
	# can produce visible art for ALL 5 output slots — including slot 4
	# OppositeCorners which reads slot 0's TL+BR quadrants. The DEMO PNG
	# (penta_tile_ground.png) is now FIVE-mode authored with a single-quadrant
	# slot 0 specifically optimized for clean OuterCorner-via-rotation; it
	# would render slot 4 transparent under FOUR-mode synthesis. Demo and
	# unit-test sources are deliberately different for that reason.
	var tex := load("res://addons/penta_tile/layouts/penta_tile_layout_penta/four_horizontal.png") as Texture2D
	if tex == null:
		_fail("setup", "could not load bundled four_horizontal.png greybox")
		return

	var src := TileSetAtlasSource.new()
	src.texture = tex
	# four_horizontal.png is 4 tiles × 32px each = 128×32. tile_size=32×32.
	var tile_size := Vector2i(tex.get_width() / 4, tex.get_height())
	src.texture_region_size = tile_size
	for slot in range(4):
		src.create_tile(Vector2i(slot, 0))
	var ts := TileSet.new()
	ts.tile_size = tile_size
	ts.add_source(src, 0)

	_layout = _PentaScript.new()
	_layout.set("axis", 0)                                                            # HORIZONTAL
	_layout.set("tile_count", 4)                                                      # FOUR

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
				# Sanity guard — every slot must have SOME opaque pixels. The user's
				# locked design (session a69c3ba5) requires ONE/TWO/THREE/FOUR mode to
				# synthesize all missing slots from slot 0 at load time, INCLUDING slot 4
				# OppositeCorners (which reads slot 0's TL+BR quadrants). slot 0 must keep
				# enough alpha in all quadrants for synthesis to produce visible art.
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


func _test_native_layout_bitmask_autofill() -> void:
	print("--- native-layout bitmask_template auto-fill ---")
	# Each concrete subclass must populate bitmask_template via its
	# _default_bitmask_template_path override on _init. Verifies (1) the texture
	# is non-null, (2) it loads to a Texture2D (not some other type), (3) the
	# load actually resolves to the bundled PNG path the subclass advertises.
	var cases := [
		["DualGrid16",   _DualGrid16Script,  "res://addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.png"],
		["Wang2Edge",    _Wang2EdgeScript,   "res://addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.png"],
		["Wang2Corner",  _Wang2CornerScript, "res://addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.png"],
		["Minimal3x3",   _Min3x3Script,      "res://addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.png"],
	]
	for c in cases:
		var name: String = c[0]
		var script: GDScript = c[1]
		var expected_path: String = c[2]
		var instance: Resource = script.new()
		var advertised: String = instance._default_bitmask_template_path() if instance.has_method("_default_bitmask_template_path") else ""
		if advertised != expected_path:
			_fail("bitmask_autofill", "%s _default_bitmask_template_path returned '%s' (expected '%s')" % [name, advertised, expected_path])
			continue
		if instance.bitmask_template == null:
			_fail("bitmask_autofill", "%s bitmask_template is null after _init (expected auto-loaded from %s)" % [name, expected_path])
			continue
		if not (instance.bitmask_template is Texture2D):
			_fail("bitmask_autofill", "%s bitmask_template is not Texture2D" % name)
			continue
		print("  %s: bitmask_template auto-loaded from %s OK" % [name, expected_path])


func _test_explicit_mode_smaller_than_atlas() -> void:
	# tile_count=TWO on a 4-tile atlas: slots 0/1 copied from source, slots
	# 2/3/4 synthesized from slot 0. Verifies (a) the synthesized atlas
	# registers tiles at all 5 slot positions, (b) the dispatcher routes
	# correctly, (c) slots 2/3/4 have non-zero opacity (synthesized art is
	# visible).
	#
	# Uses the bundled FOUR-mode greybox (full-silhouette slot 0) as the
	# source — synthesis recipes need slot 0's center / bottom-half / TL+BR
	# regions to produce real art. The FIVE-mode greybox has BL-only slot 0
	# which makes synth from slot 0 produce empty slot 4 (correct behavior
	# but uninteresting as a test fixture).
	print("--- explicit tile_count=TWO on 4-tile atlas ---")
	var tex := load("res://addons/penta_tile/layouts/penta_tile_layout_penta/four_horizontal.png") as Texture2D
	if tex == null:
		_fail("explicit_mode_smaller", "could not load FOUR-mode bundled PNG as test source")
		return
	var ts := TileSet.new()
	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = tex
	var tile_size := Vector2i(tex.get_width() / 4, tex.get_height())
	atlas_source.texture_region_size = tile_size
	for i in range(4):
		atlas_source.create_tile(Vector2i(i, 0))
	ts.add_source(atlas_source, 0)
	ts.tile_size = tile_size

	# Layer with tile_count=TWO explicit on a 4-tile atlas.
	var layout: Resource = _PentaScript.new()
	layout.set("axis", 0)                                                                # HORIZONTAL
	layout.set("tile_count", 2)                                                          # TWO
	var layer: Node = _LayerScript.new()
	layer.tile_set = ts
	layer.layout = layout
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Verify synthesized atlas registers all 5 output slots (0..4, 0).
	var synth: TileSet = layer.get("_synthesized_tile_set")
	if synth == null:
		_fail("explicit_mode_smaller", "synthesized TileSet is null")
		layer.queue_free()
		return
	var synth_src := synth.get_source(0) as TileSetAtlasSource
	if synth_src == null:
		_fail("explicit_mode_smaller", "synthesized TileSet has no source 0")
		layer.queue_free()
		return
	for slot in range(5):
		if not synth_src.has_tile(Vector2i(slot, 0)):
			_fail("explicit_mode_smaller", "synthesized slot %d not registered (expected all 5 slots present)" % slot)

	# Verify slots 2/3/4 (synthesized from slot 0) have visible art.
	var img: Image = synth_src.texture.get_image() if synth_src.texture != null else null
	if img != null:
		var region := synth_src.texture_region_size
		for slot: int in [2, 3, 4]:
			var x0: int = slot * region.x
			var opaque := 0
			for y in range(region.y):
				for x in range(region.x):
					if img.get_pixel(x0 + x, y).a > 0.01:
						opaque += 1
			if opaque == 0:
				_fail("explicit_mode_smaller", "synthesized slot %d (TWO-mode synth from slot 0) has zero opaque pixels" % slot)
			else:
				print("  slot %d (synthesized): %d opaque pixels" % [slot, opaque])

	# Verify dispatch math: paint a few cells, check synth atlas coords resolve.
	layer.set_cell(Vector2i(0, 0), 0, Vector2i(0, 0))
	layer.set_cell(Vector2i(1, 0), 0, Vector2i(0, 0))
	await process_frame
	await process_frame
	var primary = layer.get("_primary_layer")
	var used: Array = primary.get_used_cells() if primary != null else []
	var dispatched_to_synthesized_slot := false
	for cell: Vector2i in used:
		var ac: Vector2i = primary.get_cell_atlas_coords(cell)
		if ac.x >= 0 and ac.x <= 4 and synth_src.has_tile(ac):
			dispatched_to_synthesized_slot = true
			break
	if not dispatched_to_synthesized_slot:
		_fail("explicit_mode_smaller", "no painted display cell dispatched to a registered synth slot")
	else:
		print("  dispatch on 2-cell paint resolved to registered synth coords OK")

	layer.queue_free()


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
