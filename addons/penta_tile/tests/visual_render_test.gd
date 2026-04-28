## Visual-render regression test — catches "dispatch correct, pixels wrong"
## bugs that all_layouts_test misses (it only checks atlas_coords + transform,
## not the actual rendered pixel content).
##
## What it does, per concrete PentaTileLayout subclass:
##   1. Spawn fresh PentaTileMapLayer with auto-filled fallback tile_set.
##   2. Paint a 2x2 logic-cell block.
##   3. For each painted display cell: extract the dispatched source-atlas
##      tile pixels, apply the dispatched transform_flags (TRANSPOSE / FLIP_H
##      / FLIP_V) in code, and verify the resulting per-quadrant opacity
##      matches the spec for that layout's mask.
##   4. For Penta and DualGrid16/Wang2Corner: full per-quadrant assertion.
##      For Wang2Edge/Min3x3 (plus-sign edge tiles, no clean quadrant model):
##      verify the rendered tile has non-zero opacity (sanity).
##
## Caught by this test (would have caught earlier):
##   - Bundled FIVE-mode greybox slot 0 = full silhouette → 4 quadrants
##     opaque under any rotation. The fix shipped with this test asserts
##     "exactly one quadrant opaque" for OuterCorner masks (1/2/4/8).
##
## Run headless:
##   Godot --headless --path . --script addons/penta_tile/tests/visual_render_test.gd
extends SceneTree

const _LayerScript     = preload("res://addons/penta_tile/penta_tile_map_layer.gd")
const _PentaScript     = preload("res://addons/penta_tile/layouts/penta_tile_layout_penta.gd")
const _DualGrid16Sc    = preload("res://addons/penta_tile/layouts/penta_tile_layout_dual_grid_16.gd")
const _Wang2EdgeSc     = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_edge.gd")
const _Wang2CornerSc   = preload("res://addons/penta_tile/layouts/penta_tile_layout_wang_2_corner.gd")
const _Min3x3Sc        = preload("res://addons/penta_tile/layouts/penta_tile_layout_minimal_3x3.gd")

const _TRANSPOSE := TileSetAtlasSource.TRANSFORM_TRANSPOSE
const _FLIP_H    := TileSetAtlasSource.TRANSFORM_FLIP_H
const _FLIP_V    := TileSetAtlasSource.TRANSFORM_FLIP_V

# Penta locked dispatch table: mask → expected per-quadrant opacity.
# Each entry is [TL, TR, BL, BR] where 1 = opaque expected, 0 = transparent.
# Derived from the locked dispatch in penta_tile_layout_penta.gd applied to
# the FIVE-mode greybox shapes:
#   slot 0: BL only      → BL=1, others 0
#   slot 1: full         → all 1
#   slot 2: bottom half  → BL=1, BR=1
#   slot 3: L-shape (no TR) → TL=1, BL=1, BR=1
#   slot 4: TL+BR diag   → TL=1, BR=1
# Then transformed by the mask's transform_flags.
const PENTA_QUADS := {
	0:  null,                            # erase
	1:  [1, 0, 0, 0],                    # slot 0 BL → ROTATE_90 → TL
	2:  [0, 1, 0, 0],                    # slot 0 BL → ROTATE_180 → TR
	3:  [1, 1, 0, 0],                    # slot 2 bottom → ROTATE_180 → top half
	4:  [0, 0, 1, 0],                    # slot 0 BL → ROTATE_0 → BL
	5:  [1, 0, 1, 0],                    # slot 2 bottom → ROTATE_90 → left half
	6:  [0, 1, 1, 0],                    # slot 4 TL+BR → FLIP_H → TR+BL
	7:  [1, 1, 1, 0],                    # slot 3 (no TR) → ROTATE_90 → no BR
	8:  [0, 0, 0, 1],                    # slot 0 BL → ROTATE_270 → BR
	9:  [1, 0, 0, 1],                    # slot 4 TL+BR → ROTATE_0 → TL+BR
	10: [0, 1, 0, 1],                    # slot 2 bottom → ROTATE_270 → right half
	11: [1, 1, 0, 1],                    # slot 3 (no TR) → ROTATE_180 → no BL
	12: [0, 0, 1, 1],                    # slot 2 bottom → ROTATE_0
	13: [1, 0, 1, 1],                    # slot 3 (no TR) → ROTATE_0
	14: [0, 1, 1, 1],                    # slot 3 (no TR) → ROTATE_270 → no TL
	15: [1, 1, 1, 1],                    # slot 1 full
}

var _failures: Array = []


func _initialize() -> void:
	print("=== visual_render_test ===")
	# Penta — exercises rotation transforms; the layout where the user saw breakage.
	var penta := _PentaScript.new()
	penta.set("axis", 0)
	penta.set("tile_count", 5)
	await _test_layout("Penta-FIVE-H", penta, true, PENTA_QUADS)

	# DualGrid16 / Wang2Corner — bundled greybox draws bits-set quadrants per mask;
	# full per-quadrant verification matches the bit decomposition of `mask`.
	await _test_layout("DualGrid16",   _DualGrid16Sc.new(),  true, _build_corner_mask_quads())
	await _test_layout("Wang2Corner",  _Wang2CornerSc.new(), true, _build_corner_mask_quads())

	# Wang2Edge / Min3x3 — plus-sign edge tiles, no clean per-quadrant model.
	# Sanity-only: rendered tile must have non-zero opacity (mask 0 = null/erase
	# is fine; any rendered cell must have visible pixels).
	await _test_layout("Wang2Edge",    _Wang2EdgeSc.new(),   false, {})
	await _test_layout("Minimal3x3",   _Min3x3Sc.new(),      false, {})

	print("\n=== summary ===")
	if _failures.is_empty():
		print("ALL PASS")
		quit(0)
	else:
		printerr("FAIL (%d):" % _failures.size())
		for f in _failures:
			printerr("  - " + f)
		quit(1)


# Bundled DualGrid16 greybox: each mask draws the bits-set quadrants
# (TL=1, TR=2, BL=4, BR=8). No transform applied (mask_to_atlas returns
# transform=0). So expected per-quadrant matches the bit decomposition.
func _build_corner_mask_quads() -> Dictionary:
	var d: Dictionary = {0: null}
	for mask in range(1, 16):
		d[mask] = [
			1 if (mask & 1) else 0,    # TL
			1 if (mask & 2) else 0,    # TR
			1 if (mask & 4) else 0,    # BL
			1 if (mask & 8) else 0,    # BR
		]
	return d


func _test_layout(label: String, layout: Resource, full_quad_check: bool, expected_quads: Dictionary) -> void:
	print("\n--- %s ---" % label)
	var layer = _LayerScript.new()
	layer.layout = layout
	get_root().add_child(layer)
	await process_frame
	await process_frame

	# Paint a 2x2 logic-cell block — covers all 16 masks in the dual-grid 3x3
	# affected area for corner-mask layouts; covers cardinal-edge masks 1/2/4/8
	# + their combinations for edge-mask layouts.
	for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		layer.set_cell(c, 0, Vector2i.ZERO)
	await process_frame
	await process_frame

	var primary = layer.get("_primary_layer")
	if primary == null:
		_record(label, "_primary_layer is null")
		layer.queue_free()
		return

	var eff_ts: TileSet = layer.get("_synthesized_tile_set") if layer.get("_synthesized_tile_set") != null else layer.tile_set
	var eff_src := eff_ts.get_source(0) as TileSetAtlasSource if eff_ts.get_source_count() > 0 else null
	if eff_src == null:
		_record(label, "no atlas source 0")
		layer.queue_free()
		return
	var atlas_img: Image = eff_src.texture.get_image() if eff_src.texture else null
	var tile_size: Vector2i = eff_src.texture_region_size

	var sample_fn := Callable(layer, "_has_logic_cell")
	var fail_count := 0
	var first_fails: Array = []

	for cell: Vector2i in primary.get_used_cells():
		var mask: int = layout.compute_mask(cell, sample_fn)
		var atlas_coords: Vector2i = primary.get_cell_atlas_coords(cell)
		var alt: int = primary.get_cell_alternative_tile(cell)
		var transform: int = alt & ~0xfff

		# Extract the source tile sub-image and apply the dispatched transform.
		var src_tile := _extract_tile(atlas_img, atlas_coords, tile_size)
		var rendered := _apply_transform(src_tile, transform)

		# Sanity check — rendered tile has non-zero opacity (every painted cell
		# should produce visible art; mask 0 returns null in dispatch and won't
		# be in get_used_cells in the first place).
		var total_op := _total_opacity(rendered)
		if total_op == 0:
			fail_count += 1
			if first_fails.size() < 5:
				first_fails.append("cell %s mask=%d: rendered tile is fully transparent (atlas %s, transform %d)" % [cell, mask, atlas_coords, transform])
			continue

		# Per-quadrant verification (only for layouts with a clean quadrant model).
		if full_quad_check and expected_quads.has(mask) and expected_quads[mask] != null:
			var exp: Array = expected_quads[mask]
			var actual := _quadrant_opacity_pattern(rendered)
			if actual != exp:
				fail_count += 1
				if first_fails.size() < 5:
					first_fails.append("cell %s mask=%d: quad pattern %s != expected %s (atlas %s, transform %d)" % [cell, mask, str(actual), str(exp), atlas_coords, transform])

	print("  painted: %d, failures: %d" % [primary.get_used_cells().size(), fail_count])
	for f in first_fails:
		print("    " + f)

	if fail_count > 0:
		_record(label, "%d cells failed quadrant verification" % fail_count)

	layer.queue_free()


func _record(label: String, msg: String) -> void:
	_failures.append("[%s] %s" % [label, msg])
	printerr("  FAIL: " + msg)


func _extract_tile(atlas: Image, atlas_coords: Vector2i, tile_size: Vector2i) -> Image:
	var x0: int = atlas_coords.x * tile_size.x
	var y0: int = atlas_coords.y * tile_size.y
	var sub := Image.create(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
	for y in range(tile_size.y):
		for x in range(tile_size.x):
			sub.set_pixel(x, y, atlas.get_pixel(x0 + x, y0 + y))
	return sub


# Apply Godot's tile-transform flag combination: TRANSPOSE first, then FLIP_H,
# then FLIP_V (matches the synthesis machinery's transform_vertex order).
func _apply_transform(src: Image, flags: int) -> Image:
	var w: int = src.get_width()
	var h: int = src.get_height()
	# Transpose changes the output dimensions only when src is non-square; all
	# our tiles are square so output is w×h regardless.
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var transpose: bool = (flags & _TRANSPOSE) != 0
	var flip_h: bool = (flags & _FLIP_H) != 0
	var flip_v: bool = (flags & _FLIP_V) != 0
	for sy in range(h):
		for sx in range(w):
			var dx: int = sx
			var dy: int = sy
			if transpose:
				var t: int = dx
				dx = dy
				dy = t
			if flip_h:
				dx = w - 1 - dx
			if flip_v:
				dy = h - 1 - dy
			out.set_pixel(dx, dy, src.get_pixel(sx, sy))
	return out


# Returns [TL, TR, BL, BR] each 1 if quadrant is mostly opaque, 0 if mostly
# transparent. Threshold tolerates ~25% slot-outline noise (1px border around
# tiles bleeds across quadrant boundaries).
func _quadrant_opacity_pattern(img: Image) -> Array:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var hw: int = w / 2
	var hh: int = h / 2
	var quad_total: int = hw * hh
	var threshold_high: int = quad_total / 2     # > 50% opaque → "1"
	var threshold_low: int = quad_total / 4      # < 25% opaque → "0"

	var counts := [
		_quad_op_count(img, 0, 0, hw, hh),       # TL
		_quad_op_count(img, hw, 0, w, hh),       # TR
		_quad_op_count(img, 0, hh, hw, h),       # BL
		_quad_op_count(img, hw, hh, w, h),       # BR
	]
	var out: Array = []
	for c: int in counts:
		if c > threshold_high:
			out.append(1)
		elif c < threshold_low:
			out.append(0)
		else:
			out.append(-1)                        # ambiguous; fail
	return out


func _quad_op_count(img: Image, x0: int, y0: int, x1: int, y1: int) -> int:
	var op := 0
	for y in range(y0, y1):
		for x in range(x0, x1):
			if img.get_pixel(x, y).a > 0.01:
				op += 1
	return op


func _total_opacity(img: Image) -> int:
	var op := 0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.01:
				op += 1
	return op
