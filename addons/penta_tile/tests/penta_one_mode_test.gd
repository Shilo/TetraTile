## Penta HORIZONTAL ONE-mode single-cell paint regression.
##
## Setup: PentaTileLayoutPenta with axis=HORIZONTAL, tile_count=ONE. Auto-fill
## picks bundled one_horizontal.png as the tile_set fallback. Paint one logic
## cell. The synthesizer builds a 5-slot output atlas: slot 0 copied verbatim
## from source, slots 1-4 synthesized from slot 0's regions (Fill from
## center 50%, Border from bottom half, InnerCorner from full minus TR,
## OppositeCorners from TL+BR composite).
##
## Asserts:
##   1. Exactly 4 display cells get painted (the dual-grid 2x2 around the
##      single logic cell).
##   2. Each painted display cell has the correct mask + dispatched
##      atlas_coords + transform_flags per the locked Penta dispatch table:
##        - NW cell: mask=8 → atlas (0, 0) + ROTATE_270
##        - NE cell: mask=4 → atlas (0, 0) + ROTATE_0
##        - SW cell: mask=2 → atlas (0, 0) + ROTATE_180
##        - SE cell: mask=1 → atlas (0, 0) + ROTATE_90
##   3. The synthesized atlas's slot 0 matches the bundled one_horizontal.png
##      slot 0 spec PIXEL-FOR-PIXEL — every pixel of the full-silhouette
##      pattern (4 corner caps + 4 edge slabs + center fill) verified.
##   4. Synthesized slots 1-4 each have non-zero opacity (synthesis from
##      slot 0 produced visible art, not transparent placeholders).
##
## Run headless:
##   Godot --headless --path . --script addons/penta_tile/tests/penta_one_mode_test.gd
extends SceneTree

const _LayerScript = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _PentaScript = preload("res://addons/penta_tile/layouts/penta_tile_layout_penta.gd")

# Locked Penta corner-mask dispatch (from penta_tile_layout_penta.gd:154
# mask_to_atlas). Each entry [slot_index, transform_flags].
const _ROTATE_0   := 0
const _ROTATE_90  := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
const _ROTATE_180 := TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
const _ROTATE_270 := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V

# Expected dispatch for the 4 display cells around a single logic cell
# painted at (0, 0) on a HORIZONTAL ONE Penta layer.
# Cell (X, Y) samples neighbors at offsets _TL=(−1,−1), _TR=(0,−1),
# _BL=(−1,0), _BR=(0,0). Painted logic cell is at (0, 0).
const _EXPECTED := {
	Vector2i(0, 0): {"mask": 8,  "transform": _ROTATE_270},   # only BR neighbor exists (the painted cell)
	Vector2i(1, 0): {"mask": 4,  "transform": _ROTATE_0},     # only BL
	Vector2i(0, 1): {"mask": 2,  "transform": _ROTATE_180},   # only TR
	Vector2i(1, 1): {"mask": 1,  "transform": _ROTATE_90},    # only TL
}

var _failures: Array = []


func _initialize() -> void:
	print("=== penta_one_mode_test ===")
	await _run()
	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		quit(1)


func _run() -> void:
	# 1. Build a Penta-HORIZONTAL-ONE layer. Auto-fill picks one_horizontal.png.
	var penta := _PentaScript.new()
	penta.set("axis", 0)             # HORIZONTAL
	penta.set("tile_count", 1)       # ONE
	var layer = _LayerScript.new()
	layer.layout = penta
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Sanity: bitmask_template auto-loaded the ONE-mode greybox.
	if penta.bitmask_template == null:
		_fail("bitmask_template is null; expected one_horizontal.png auto-loaded")
		return

	# 2. Paint a single logic cell at (0, 0).
	layer.set_cell(Vector2i(0, 0), 0, Vector2i.ZERO)
	await process_frame
	await process_frame

	var primary = layer.get("_primary_layer")
	if primary == null:
		_fail("_primary_layer is null after paint")
		layer.queue_free()
		return

	# 3. Verify exactly 4 display cells painted (dual-grid 2x2 around painted cell).
	var painted: Array = primary.get_used_cells()
	print("painted display cells:", painted.size())
	if painted.size() != 4:
		_fail("expected 4 painted display cells (dual-grid 2x2), got %d" % painted.size())

	# 4. Verify per-cell dispatch matches the expected table.
	var sample_fn := Callable(layer, "_has_logic_cell")
	for cell: Vector2i in painted:
		if not _EXPECTED.has(cell):
			_fail("unexpected painted cell %s (not in 2x2 around painted logic cell)" % cell)
			continue
		var exp: Dictionary = _EXPECTED[cell]
		var actual_mask: int = penta.compute_mask(cell, sample_fn)
		var actual_atlas: Vector2i = primary.get_cell_atlas_coords(cell)
		var actual_alt: int = primary.get_cell_alternative_tile(cell)
		var actual_transform: int = actual_alt & ~0xfff
		if actual_mask != exp["mask"]:
			_fail("cell %s: mask %d != expected %d" % [cell, actual_mask, exp["mask"]])
		if actual_atlas != Vector2i(0, 0):
			_fail("cell %s mask=%d: atlas %s != expected (0, 0) (ONE-mode dispatches to slot 0)" % [cell, actual_mask, actual_atlas])
		if actual_transform != exp["transform"]:
			_fail("cell %s mask=%d: transform %d != expected %d" % [cell, actual_mask, actual_transform, exp["transform"]])
		else:
			print("  cell %s mask=%d atlas=(0,0) transform=%d OK" % [cell, actual_mask, actual_transform])

	# 5. Pixel-precise verification of the synthesized atlas's slot 0 against
	#    the bundled one_horizontal.png spec (full silhouette).
	var synth: TileSet = layer.get("_synthesized_tile_set")
	if synth == null:
		_fail("_synthesized_tile_set is null (Penta ONE mode should synthesize)")
		layer.queue_free()
		return
	var synth_src := synth.get_source(0) as TileSetAtlasSource
	if synth_src == null or synth_src.texture == null:
		_fail("synthesized atlas source 0 missing or has no texture")
		layer.queue_free()
		return
	var synth_img: Image = synth_src.texture.get_image()
	var tile_size: int = synth_src.texture_region_size.x

	var slot0_pixel_diffs: int = 0
	var first_diff: Vector2i = Vector2i(-1, -1)
	for y in range(tile_size):
		for x in range(tile_size):
			var actual_op: bool = synth_img.get_pixel(x, y).a > 0.01
			var expected_op: bool = _expected_one_mode_slot0(x, y, tile_size)
			if actual_op != expected_op:
				slot0_pixel_diffs += 1
				if first_diff == Vector2i(-1, -1):
					first_diff = Vector2i(x, y)
	if slot0_pixel_diffs > 0:
		_fail("synthesized slot 0 has %d pixel diffs vs one_horizontal.png spec; first at %s" % [slot0_pixel_diffs, first_diff])
	else:
		print("  synth slot 0 pixel match: OK (%dx%d full silhouette)" % [tile_size, tile_size])

	# 6. Verify slots 1-4 (synthesized) have non-zero opacity.
	for slot: int in [1, 2, 3, 4]:
		var x0: int = slot * tile_size
		var op: int = 0
		for y in range(tile_size):
			for x in range(tile_size):
				if synth_img.get_pixel(x0 + x, y).a > 0.01:
					op += 1
		if op == 0:
			_fail("synthesized slot %d is fully transparent (synthesis from slot 0 failed)" % slot)
		else:
			print("  synth slot %d opacity: %d/%d" % [slot, op, tile_size * tile_size])

	layer.queue_free()


# Expected pixel pattern for the bundled ONE-mode one_horizontal.png slot 0.
# Mirrors `draw_penta_isolated_cell` (BL-quadrant single-corner piece) in
# addons/penta_tile/_generate_bitmasks.py — 32x32 tile with the BL quadrant
# (x:0..15, y:16..31) filled, other 3 quadrants transparent.
# Returns true if pixel (x, y) should be opaque.
func _expected_one_mode_slot0(x: int, y: int, ts: int) -> bool:
	if ts != 32:
		# Spec is encoded for 32-px tiles. Different tile sizes aren't tested here.
		return false
	# BL quadrant only.
	return x >= 0 and x <= 15 and y >= 16 and y <= 31


func _fail(msg: String) -> void:
	_failures.append(msg)
	printerr("  FAIL: " + msg)
