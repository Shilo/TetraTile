@tool
## Synthesis machinery for PentaTileLayoutPenta. Builds runtime TileSets from
## a single source TileSet by extracting sub-regions of slot 0 (IsolatedCell)
## and assembling synthesized archetypes per the locked anchoring spec
## (see .planning/phases/02-native-layouts/02-02-PLAN.md Gate 1 / Gate 2).
##
## Determinism invariant: same (source_tile_set, axis, tile_count) → bit-identical
## output (PENTA-SYNTH-06). Re-runs only when these inputs change.
##
## Slot ordering (LOCKED — Phase 2 architectural sweep):
##   0 = IsolatedCell  (always authored; source of OuterCorner render-time rotation)
##   1 = Fill          (synthesized from slot 0 in ONE mode; authored in TWO..FIVE)
##   2 = Border        (synthesized from slot 0 in ONE/TWO modes; authored in THREE..FIVE)
##   3 = InnerCorner   (synthesized from slot 0 in ONE/TWO/THREE modes; authored in FOUR/FIVE)
##   4 = OppositeCorners (synthesized from slot 0 in ONE..FOUR modes; authored in FIVE)
##
## OuterCorner has NO synthesized output slot. mask_to_atlas returns slot 0 with
## rotation flags (ROTATE_90/180/270) at render time — Path B per Gate 1.
class_name PentaTileSynthesis
extends RefCounted

# Slot ordering (LOCKED — Phase 2 architectural sweep).
const SLOT_ISOLATED_CELL := 0
const SLOT_FILL := 1
const SLOT_BORDER := 2
const SLOT_INNER_CORNER := 3
const SLOT_OPPOSITE_CORNERS := 4

# Mode constants — match PentaTileLayoutPenta.TileCountMode in Wave 3.
const MODE_ONE := 1
const MODE_TWO := 2
const MODE_THREE := 3
const MODE_FOUR := 4
const MODE_FIVE := 5

# Number of output slots in a synthesized strip (IsolatedCell + 4 archetypes).
const _STRIP_SLOT_COUNT := 5

# Transform flag values (PITFALLS.md §1).
# Shared int with alt-id low bits via _pack_alternative (alt_id must be < 4096).
const _TRANSFORM_FLIP_H := TileSetAtlasSource.TRANSFORM_FLIP_H       # 4096
const _TRANSFORM_FLIP_V := TileSetAtlasSource.TRANSFORM_FLIP_V       # 8192
const _TRANSFORM_TRANSPOSE := TileSetAtlasSource.TRANSFORM_TRANSPOSE  # 16384


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Synthesizes a single strip of _STRIP_SLOT_COUNT (5) slots from `source_tile_set`.
##
## Parameters:
##   source_tile_set – user's TileSet (NOT mutated)
##   source_id       – atlas source id within source_tile_set
##   axis            – 0 = HORIZONTAL (slots along X), 1 = VERTICAL (slots along Y)
##   strip_index     – which strip (0 = first row/column)
##   mode            – MODE_ONE..MODE_FIVE
##
## Returns Dictionary:
##   { "slots": Array[Dictionary], "tile_size": Vector2i, "warnings": Array[String] }
## Each slot dictionary:
##   { "atlas_coords": Vector2i, "image": Image, "polygons": Dictionary }
## Where polygons:
##   { "collision": { layer_idx: Array[PackedVector2Array] },
##     "occlusion": { layer_idx: Array[PackedVector2Array] },
##     "navigation": { layer_idx: { "outer": PackedVector2Array, "holes": Array } } }
##
## Returns empty Dictionary {} on hard validation failure (non-square / odd tile_size).
static func synthesize_strip(
		source_tile_set: TileSet,
		source_id: int,
		axis: int,
		strip_index: int,
		mode: int) -> Dictionary:

	if source_tile_set == null:
		return {}
	if not source_tile_set.has_source(source_id):
		return {}
	var atlas_source := source_tile_set.get_source(source_id) as TileSetAtlasSource
	if atlas_source == null:
		return {}

	var tile_size := atlas_source.texture_region_size
	var warnings := validate_tile_size(tile_size)

	# Hard errors: non-square or odd tile_size prevent synthesis.
	for w: String in warnings:
		if "square tiles" in w or "must be even" in w:
			return {"slots": [], "tile_size": tile_size, "warnings": warnings}

	# Clamp mode to valid range.
	mode = clampi(mode, MODE_ONE, MODE_FIVE)

	# Authored slot count per mode: how many consecutive slots the artist provides.
	# Slot 0 (IsolatedCell) is always authored. Slots 1..mode-1 are authored for mode ≥ 2.
	var authored_count := mode  # slot 0 always + (mode-1) more = mode slots total

	# Get the source atlas image once (used for all sub-region extractions).
	var atlas_texture := atlas_source.texture
	var atlas_image: Image
	if atlas_texture != null:
		atlas_image = atlas_texture.get_image()
	# atlas_image may be null if texture is not loaded; synthesized slots will be blank.

	var slots: Array = []

	# Output exactly _STRIP_SLOT_COUNT (5) slots regardless of mode.
	# Slots 0..authored_count-1 are copied directly from the source.
	# Slots authored_count.._STRIP_SLOT_COUNT-1 are synthesized from slot 0.
	for out_slot in range(_STRIP_SLOT_COUNT):
		# Atlas coords in the SOURCE tileset for this slot.
		var src_atlas_coords: Vector2i
		if axis == 0:  # HORIZONTAL
			src_atlas_coords = Vector2i(strip_index * _STRIP_SLOT_COUNT + out_slot, 0) if out_slot < authored_count else Vector2i(strip_index * _STRIP_SLOT_COUNT, 0)
		else:  # VERTICAL
			src_atlas_coords = Vector2i(0, strip_index * _STRIP_SLOT_COUNT + out_slot) if out_slot < authored_count else Vector2i(0, strip_index * _STRIP_SLOT_COUNT)

		# Slot 0 source coords (IsolatedCell — used for synthesis).
		var slot0_coords: Vector2i
		if axis == 0:
			slot0_coords = Vector2i(strip_index * _STRIP_SLOT_COUNT, 0)
		else:
			slot0_coords = Vector2i(0, strip_index * _STRIP_SLOT_COUNT)

		var slot_image: Image
		var slot_polygons: Dictionary

		if out_slot < authored_count:
			# Authored slot — copy image and polygons directly.
			slot_image = _extract_tile_image(atlas_image, src_atlas_coords, tile_size)
			slot_polygons = _extract_tile_polygons(atlas_source, src_atlas_coords, tile_size, source_tile_set)
		else:
			# Synthesized slot — produce from slot 0 sub-regions.
			slot_image = _synthesize_slot_image(atlas_image, slot0_coords, out_slot, tile_size)
			slot_polygons = _synthesize_slot_polygons(atlas_source, slot0_coords, out_slot, tile_size, source_tile_set)

		slots.append({
			"atlas_coords": Vector2i(out_slot, 0),  # output position in synthesized strip
			"image": slot_image,
			"polygons": slot_polygons,
		})

	# Include source layer counts so build_tile_set_from_synthesis can mirror them
	# on the synthesized TileSet before copying polygons (Rule 1 fix — synthesized TileSet
	# starts with 0 physics/occlusion/navigation layers; polygon copy crashes without them).
	return {
		"slots": slots,
		"tile_size": tile_size,
		"warnings": warnings,
		"physics_layer_count": source_tile_set.get_physics_layers_count(),
		"occlusion_layer_count": source_tile_set.get_occlusion_layers_count(),
		"navigation_layer_count": source_tile_set.get_navigation_layers_count(),
	}


## Per-vertex transform under TRANSFORM_FLIP_H/V/TRANSPOSE flags.
## Local origin: tile-CENTER (LOCKED — Gate 2). v in tile-center-local coords.
## Apply TRANSPOSE first, then FLIP_H, then FLIP_V (canonical order matching Godot internals).
static func transform_vertex(v: Vector2, flags: int) -> Vector2:
	var out := v
	if flags & _TRANSFORM_TRANSPOSE:
		out = Vector2(out.y, out.x)
	if flags & _TRANSFORM_FLIP_H:
		out.x = -out.x
	if flags & _TRANSFORM_FLIP_V:
		out.y = -out.y
	return out


## Axis-aligned rectangle polygon clipping (Liang-Barsky-flavored).
## `points` in tile-center-local coords; `sub_rect` also in tile-center-local coords.
## Returns clipped polygon rescaled from sub_rect-local coords to full tile coords.
## Drops polygon (returns empty) if < 3 vertices remain after clipping.
static func clip_polygon_to_subrect(
		points: PackedVector2Array,
		sub_rect: Rect2,
		full_tile_size: Vector2) -> PackedVector2Array:
	if points.size() < 3:
		return PackedVector2Array()

	var clipped: PackedVector2Array = PackedVector2Array()
	var n := points.size()

	for i in range(n):
		var v_i: Vector2 = points[i]
		var v_next: Vector2 = points[(i + 1) % n]
		var v_i_in: bool = sub_rect.has_point(v_i)
		var v_next_in: bool = sub_rect.has_point(v_next)

		if v_i_in and v_next_in:
			clipped.append(v_i)
		elif v_i_in and not v_next_in:
			clipped.append(v_i)
			var intersect := _clip_segment_to_rect(v_i, v_next, sub_rect)
			clipped.append(intersect)
		elif not v_i_in and v_next_in:
			var intersect := _clip_segment_to_rect(v_i, v_next, sub_rect)
			clipped.append(intersect)
		# else: both outside → skip

	if clipped.size() < 3:
		return PackedVector2Array()

	# Rescale from sub_rect-local to full tile coords.
	# sub_rect is tile-center-local; output tile is tile-center-local at full tile_size.
	var scale := Vector2(
		full_tile_size.x / sub_rect.size.x if sub_rect.size.x > 0.0 else 1.0,
		full_tile_size.y / sub_rect.size.y if sub_rect.size.y > 0.0 else 1.0
	)
	var center := sub_rect.get_center()
	var result: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in clipped:
		result.append((v - center) * scale)
	return result


## Tile-size validation per Gate 1 constraints.
## Returns Array[String] of warnings; empty if valid.
static func validate_tile_size(tile_size: Vector2i) -> Array:
	var warnings: Array = []
	if tile_size.x != tile_size.y:
		warnings.append("PentaTile synthesis: source tile_set requires square tiles; got %d×%d" % [tile_size.x, tile_size.y])
	if tile_size.x % 2 != 0:
		warnings.append("PentaTile synthesis: tile_size must be even; got %d" % tile_size.x)
	if tile_size.x < 4:
		warnings.append("PentaTile synthesis: tile_size below 4 px; synthesized archetypes will be visually crude")
	return warnings


## Builds a runtime TileSet from synthesize_strip output.
## The new TileSet contains one TileSetAtlasSource whose texture is composed from
## the slot images returned by synthesize_strip; collision/occlusion/navigation
## polygons are copied per Gate 2.
## The user's source TileSet is never mutated.
##
## Sub-region resize uses Image.INTERPOLATE_NEAREST exclusively (PENTA-SYNTH-06
## determinism — non-NEAREST produces pixel drift across runs).
##
## Returns null if result is empty or tile_size is zero.
static func build_tile_set_from_synthesis(result: Dictionary) -> TileSet:
	if result.is_empty() or not result.has("slots"):
		return null
	var slots: Array = result["slots"]
	var tile_size: Vector2i = result["tile_size"]
	if slots.is_empty() or tile_size == Vector2i.ZERO:
		return null

	# Compose strip image: one tile_size per slot, laid out horizontally.
	var strip_width: int = tile_size.x * slots.size()
	var strip_image := Image.create(strip_width, tile_size.y, false, Image.FORMAT_RGBA8)
	strip_image.fill(Color(0.0, 0.0, 0.0, 0.0))  # transparent background

	for i in range(slots.size()):
		var slot_dict: Dictionary = slots[i]
		var slot_image: Image = slot_dict.get("image", null)
		if slot_image == null:
			# Create a blank transparent slot image.
			slot_image = Image.create(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
			slot_image.fill(Color(0.0, 0.0, 0.0, 0.0))
		# Ensure correct size (resize with NEAREST if needed).
		if slot_image.get_size() != tile_size:
			slot_image.resize(tile_size.x, tile_size.y, Image.INTERPOLATE_NEAREST)
		# Blit slot image into strip at (i * tile_size.x, 0).
		strip_image.blit_rect(
			slot_image,
			Rect2i(Vector2i.ZERO, tile_size),
			Vector2i(i * tile_size.x, 0)
		)

	var ts := TileSet.new()
	ts.tile_size = tile_size

	# Mirror physics/occlusion/navigation layers from the source TileSet so
	# _copy_polygons_to_tile_data can write polygons without out-of-bounds errors.
	# (Rule 1 fix: synthesized TileSet starts bare with 0 layers of each type.)
	var physics_count: int = result.get("physics_layer_count", 0)
	var occlusion_count: int = result.get("occlusion_layer_count", 0)
	var navigation_count: int = result.get("navigation_layer_count", 0)
	for _i in range(physics_count):
		ts.add_physics_layer()
	for _i in range(occlusion_count):
		ts.add_occlusion_layer()
	for _i in range(navigation_count):
		ts.add_navigation_layer()

	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(strip_image)
	src.texture_region_size = tile_size
	var added_id := ts.add_source(src, 0)

	# Create one tile per slot at atlas_coords (slot_index, 0).
	for i in range(slots.size()):
		var atlas_coords := Vector2i(i, 0)
		src.create_tile(atlas_coords)
		var tile_data := src.get_tile_data(atlas_coords, 0)
		if tile_data == null:
			continue
		var slot_dict: Dictionary = slots[i]
		var polygons: Dictionary = slot_dict.get("polygons", {})
		_copy_polygons_to_tile_data(tile_data, polygons)

	return ts


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Copy collision / occlusion / navigation polygons onto a synthesized TileData.
## polygons shape (produced by synthesize_strip):
##   {
##     "collision": { layer_idx: Array[PackedVector2Array] },
##     "occlusion": { layer_idx: Array[PackedVector2Array] },
##     "navigation": { layer_idx: { "outer": PackedVector2Array, "holes": Array } },
##   }
## NOT copied (Gate 2): animation frames, custom data, probability, Y-sort origin,
## texture origin/modulate, material override, z-index.
static func _copy_polygons_to_tile_data(tile_data: TileData, polygons: Dictionary) -> void:
	# Collision polygons (per physics layer).
	var collision: Dictionary = polygons.get("collision", {})
	for layer_index: int in collision.keys():
		var polys: Array = collision[layer_index]
		for poly_points: PackedVector2Array in polys:
			if poly_points.size() < 3:
				continue
			var idx := tile_data.get_collision_polygons_count(layer_index)
			tile_data.add_collision_polygon(layer_index)
			tile_data.set_collision_polygon_points(layer_index, idx, poly_points)

	# Occlusion polygons (per occlusion layer).
	# Godot 4.6 TileData supports one OccluderPolygon2D per layer via
	# set_occluder(layer_index, occluder) — no multi-polygon-per-layer API exists.
	# We take the first polygon in the polys array (if any) and discard the rest.
	var occlusion: Dictionary = polygons.get("occlusion", {})
	for layer_index: int in occlusion.keys():
		var polys: Array = occlusion[layer_index]
		if polys.is_empty():
			continue
		var poly_points: PackedVector2Array = polys[0]
		if poly_points.size() < 3:
			continue
		var occ := OccluderPolygon2D.new()
		occ.polygon = poly_points
		tile_data.set_occluder(layer_index, occ)

	# Navigation polygons (per navigation layer; one nav poly with optional hole loops).
	var navigation: Dictionary = polygons.get("navigation", {})
	for layer_index: int in navigation.keys():
		var nav_dict: Dictionary = navigation[layer_index]
		var outer: PackedVector2Array = nav_dict.get("outer", PackedVector2Array())
		if outer.size() < 3:
			continue  # outer loop dropped → entire nav poly invalid per Gate 2
		var nav_poly := NavigationPolygon.new()
		nav_poly.add_outline(outer)
		var holes: Array = nav_dict.get("holes", [])
		for hole: PackedVector2Array in holes:
			if hole.size() >= 3:
				nav_poly.add_outline(hole)
		nav_poly.make_polygons_from_outlines()
		tile_data.set_navigation_polygon(layer_index, nav_poly)


## Extract the pixel sub-image for an authored slot.
static func _extract_tile_image(
		atlas_image: Image,
		atlas_coords: Vector2i,
		tile_size: Vector2i) -> Image:
	if atlas_image == null:
		var blank := Image.create(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
		blank.fill(Color(0.0, 0.0, 0.0, 0.0))
		return blank
	var pixel_pos := Vector2i(atlas_coords.x * tile_size.x, atlas_coords.y * tile_size.y)
	var region := Rect2i(pixel_pos, tile_size)
	# Clamp to atlas image bounds.
	var atlas_bounds := Rect2i(Vector2i.ZERO, atlas_image.get_size())
	region = region.intersection(atlas_bounds)
	if region.size.x <= 0 or region.size.y <= 0:
		var blank := Image.create(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
		blank.fill(Color(0.0, 0.0, 0.0, 0.0))
		return blank
	var tile_img := atlas_image.get_region(region)
	if tile_img.get_size() != tile_size:
		tile_img.resize(tile_size.x, tile_size.y, Image.INTERPOLATE_NEAREST)
	return tile_img


## Extract polygon data from an authored slot in the source atlas source.
## source_tile_set is used to get physics/occlusion/navigation layer counts so
## probing loops stay within bounds (Rule 1 fix — out-of-bounds crashes on layer_idx ≥ count).
static func _extract_tile_polygons(
		atlas_source: TileSetAtlasSource,
		atlas_coords: Vector2i,
		tile_size: Vector2i,
		source_tile_set: TileSet = null) -> Dictionary:
	if not atlas_source.has_tile(atlas_coords):
		return {}
	var tile_data := atlas_source.get_tile_data(atlas_coords, 0)
	if tile_data == null:
		return {}

	var result: Dictionary = {}

	# Use source_tile_set layer counts to cap probing loops — avoids out-of-bounds crashes.
	# If source_tile_set is null (legacy call path without TileSet ref), fall back to 0
	# layers (no polygon extraction) since we can't probe safely without the count.
	var phys_layers: int = source_tile_set.get_physics_layers_count() if source_tile_set != null else 0
	var occ_layers: int = source_tile_set.get_occlusion_layers_count() if source_tile_set != null else 0
	var nav_layers: int = source_tile_set.get_navigation_layers_count() if source_tile_set != null else 0

	# Collision layers — iterate exactly phys_layers indices (0..phys_layers-1).
	var collision_dict: Dictionary = {}
	for layer_idx in range(phys_layers):
		var poly_count := tile_data.get_collision_polygons_count(layer_idx)
		if poly_count > 0:
			var polys: Array = []
			for p in range(poly_count):
				polys.append(tile_data.get_collision_polygon_points(layer_idx, p))
			collision_dict[layer_idx] = polys
	if not collision_dict.is_empty():
		result["collision"] = collision_dict

	# Occlusion layers — iterate exactly occ_layers indices.
	# Godot 4.6 TileData: get_occluder(layer_index) → one OccluderPolygon2D or null.
	var occlusion_dict: Dictionary = {}
	for layer_idx in range(occ_layers):
		var occ: OccluderPolygon2D = tile_data.get_occluder(layer_idx)
		if occ != null and occ.polygon.size() >= 3:
			occlusion_dict[layer_idx] = [occ.polygon]
	if not occlusion_dict.is_empty():
		result["occlusion"] = occlusion_dict

	# Navigation layers — iterate exactly nav_layers indices.
	var navigation_dict: Dictionary = {}
	for layer_idx in range(nav_layers):
		var nav_poly := tile_data.get_navigation_polygon(layer_idx)
		if nav_poly == null:
			continue
		var outline_count := nav_poly.get_outline_count()
		if outline_count > 0:
			var outer: PackedVector2Array = nav_poly.get_outline(0)
			var holes: Array = []
			for h in range(1, outline_count):
				holes.append(nav_poly.get_outline(h))
			navigation_dict[layer_idx] = {"outer": outer, "holes": holes}
	if not navigation_dict.is_empty():
		result["navigation"] = navigation_dict

	return result


## Synthesize slot `out_slot` image from slot 0 (IsolatedCell) sub-regions.
## Gate 1 anchoring spec:
##   SLOT_FILL (1)           — center 50% of slot 0, stretched to tile_size
##   SLOT_BORDER (2)         — bottom-half slab (S edge), stretched to tile_size
##   SLOT_INNER_CORNER (3)   — three-quadrant L-shape (missing TR), stretched to tile_size
##   SLOT_OPPOSITE_CORNERS (4) — TL_quad + BR_quad composited on transparent canvas
static func _synthesize_slot_image(
		atlas_image: Image,
		slot0_coords: Vector2i,
		out_slot: int,
		tile_size: Vector2i) -> Image:
	if atlas_image == null:
		var blank := Image.create(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
		blank.fill(Color(0.0, 0.0, 0.0, 0.0))
		return blank

	# Pixel origin of slot 0 in the atlas image.
	var slot0_px := Vector2i(slot0_coords.x * tile_size.x, slot0_coords.y * tile_size.y)
	var ts := tile_size  # shorthand

	match out_slot:
		SLOT_FILL:
			# Center 50% rect of slot 0, stretched to tile_size.
			# Rect: x = ts/4 .. 3*ts/4, y = ts/4 .. 3*ts/4
			var sub_x := slot0_px.x + ts.x / 4
			var sub_y := slot0_px.y + ts.y / 4
			var sub_w := ts.x / 2
			var sub_h := ts.y / 2
			var sub_region := Rect2i(sub_x, sub_y, sub_w, sub_h)
			var sub_img := atlas_image.get_region(sub_region)
			sub_img.resize(ts.x, ts.y, Image.INTERPOLATE_NEAREST)
			return sub_img

		SLOT_BORDER:
			# Bottom-half slab ("S" edge): rect (0, ts/2) to (ts, ts), stretched to tile_size.
			var sub_x := slot0_px.x
			var sub_y := slot0_px.y + ts.y / 2
			var sub_w := ts.x
			var sub_h := ts.y / 2
			var sub_region := Rect2i(sub_x, sub_y, sub_w, sub_h)
			var sub_img := atlas_image.get_region(sub_region)
			sub_img.resize(ts.x, ts.y, Image.INTERPOLATE_NEAREST)
			return sub_img

		SLOT_INNER_CORNER:
			# Three-quadrant L-shape: full slot 0 minus the TR quadrant.
			# Strategy: start with full slot 0 image; blank out TR quadrant (top-right).
			# TR quadrant: x = ts/2..ts, y = 0..ts/2
			# Then stretch the result to tile_size (already full tile_size; just copy).
			var full_region := Rect2i(slot0_px.x, slot0_px.y, ts.x, ts.y)
			var full_img := atlas_image.get_region(full_region)
			# Blank out TR quadrant (x = ts/2.., y = ..ts/2).
			var half_x := ts.x / 2
			var half_y := ts.y / 2
			for py in range(0, half_y):
				for px in range(half_x, ts.x):
					full_img.set_pixel(px, py, Color(0.0, 0.0, 0.0, 0.0))
			# The resulting L-shape covers BL + TL + BR quadrants.
			# Stretch to tile_size (already tile_size — no resize needed).
			return full_img

		SLOT_OPPOSITE_CORNERS:
			# TL_quad composited at TL position, BR_quad composited at BR position.
			# Canvas: tile_size × tile_size, transparent.
			var canvas := Image.create(ts.x, ts.y, false, Image.FORMAT_RGBA8)
			canvas.fill(Color(0.0, 0.0, 0.0, 0.0))
			var half_x := ts.x / 2
			var half_y := ts.y / 2

			# TL quad: slot0_px + (0, 0), size = half_x × half_y
			var tl_region := Rect2i(slot0_px.x, slot0_px.y, half_x, half_y)
			var tl_img := atlas_image.get_region(tl_region)
			canvas.blit_rect(tl_img, Rect2i(Vector2i.ZERO, Vector2i(half_x, half_y)), Vector2i(0, 0))

			# BR quad: slot0_px + (half_x, half_y), size = half_x × half_y
			var br_region := Rect2i(slot0_px.x + half_x, slot0_px.y + half_y, half_x, half_y)
			var br_img := atlas_image.get_region(br_region)
			canvas.blit_rect(br_img, Rect2i(Vector2i.ZERO, Vector2i(half_x, half_y)), Vector2i(half_x, half_y))

			return canvas

		_:
			# Unknown slot — return blank.
			var blank := Image.create(ts.x, ts.y, false, Image.FORMAT_RGBA8)
			blank.fill(Color(0.0, 0.0, 0.0, 0.0))
			return blank


## Synthesize polygon data for a synthesized slot from slot 0 source polygons.
## Applies sub-region clipping per Gate 2 anchoring spec.
## source_tile_set passed through to _extract_tile_polygons for bounds-safe layer probing.
static func _synthesize_slot_polygons(
		atlas_source: TileSetAtlasSource,
		slot0_coords: Vector2i,
		out_slot: int,
		tile_size: Vector2i,
		source_tile_set: TileSet = null) -> Dictionary:
	if not atlas_source.has_tile(slot0_coords):
		return {}
	var source_polygons := _extract_tile_polygons(atlas_source, slot0_coords, tile_size, source_tile_set)
	if source_polygons.is_empty():
		return {}

	var sub_rect := _subrect_for_slot(out_slot, tile_size)
	if sub_rect == Rect2():
		# SLOT_OPPOSITE_CORNERS or unrecognised — no simple clipping; skip polygon synthesis.
		return {}

	var full_tile_size := Vector2(tile_size)
	var result: Dictionary = {}

	# Collision.
	var collision: Dictionary = source_polygons.get("collision", {})
	if not collision.is_empty():
		var out_collision: Dictionary = {}
		for layer_idx: int in collision.keys():
			var polys: Array = collision[layer_idx]
			var clipped_polys: Array = []
			for pts: PackedVector2Array in polys:
				var clipped := clip_polygon_to_subrect(pts, sub_rect, full_tile_size)
				if clipped.size() >= 3:
					clipped_polys.append(clipped)
			if not clipped_polys.is_empty():
				out_collision[layer_idx] = clipped_polys
		if not out_collision.is_empty():
			result["collision"] = out_collision

	# Occlusion.
	var occlusion: Dictionary = source_polygons.get("occlusion", {})
	if not occlusion.is_empty():
		var out_occlusion: Dictionary = {}
		for layer_idx: int in occlusion.keys():
			var polys: Array = occlusion[layer_idx]
			var clipped_polys: Array = []
			for pts: PackedVector2Array in polys:
				var clipped := clip_polygon_to_subrect(pts, sub_rect, full_tile_size)
				if clipped.size() >= 3:
					clipped_polys.append(clipped)
			if not clipped_polys.is_empty():
				out_occlusion[layer_idx] = clipped_polys
		if not out_occlusion.is_empty():
			result["occlusion"] = out_occlusion

	# Navigation.
	var navigation: Dictionary = source_polygons.get("navigation", {})
	if not navigation.is_empty():
		var out_navigation: Dictionary = {}
		for layer_idx: int in navigation.keys():
			var nav_dict: Dictionary = navigation[layer_idx]
			var outer: PackedVector2Array = nav_dict.get("outer", PackedVector2Array())
			if outer.size() < 3:
				continue
			var clipped_outer := clip_polygon_to_subrect(outer, sub_rect, full_tile_size)
			if clipped_outer.size() < 3:
				continue  # outer dropped — entire nav poly invalid
			var holes: Array = nav_dict.get("holes", [])
			var clipped_holes: Array = []
			for hole: PackedVector2Array in holes:
				var clipped_hole := clip_polygon_to_subrect(hole, sub_rect, full_tile_size)
				if clipped_hole.size() >= 3:
					clipped_holes.append(clipped_hole)
			out_navigation[layer_idx] = {"outer": clipped_outer, "holes": clipped_holes}
		if not out_navigation.is_empty():
			result["navigation"] = out_navigation

	return result


## Returns the tile-center-local Rect2 sub-region of slot 0 to clip/extract for
## a synthesized archetype slot. Per Gate 1 anchoring spec.
## Returns empty Rect2() for SLOT_OPPOSITE_CORNERS (no simple sub-rect clipping).
static func _subrect_for_slot(slot: int, tile_size: Vector2i) -> Rect2:
	var hw := tile_size.x * 0.5
	var hh := tile_size.y * 0.5
	var qw := tile_size.x * 0.25
	var qh := tile_size.y * 0.25
	# All coords in tile-center-local space: center = (0, 0);
	# top-left = (-hw, -hh), bottom-right = (+hw, +hh).
	match slot:
		SLOT_FILL:
			# Center 50% of tile: (-qw, -qh) to (+qw, +qh)
			return Rect2(-qw, -qh, hw, hh)
		SLOT_BORDER:
			# Bottom-half slab ("S" edge): (-hw, 0) to (+hw, +hh)
			return Rect2(-hw, 0.0, tile_size.x, hh)
		SLOT_INNER_CORNER:
			# L-shape: full tile minus TR quadrant.
			# Use full rect; the image extraction handles the L-shape blanking separately.
			# For polygon clipping purposes, use the full tile rect (safe conservative clip).
			return Rect2(-hw, -hh, tile_size.x, tile_size.y)
		_:
			# SLOT_OPPOSITE_CORNERS and others — no simple sub-rect.
			return Rect2()


## Liang-Barsky line-segment-to-rect-boundary intersection helper.
## Returns the intersection point of segment p0→p1 with the boundary of `rect`.
## Assumes one endpoint is inside and one is outside.
static func _clip_segment_to_rect(p0: Vector2, p1: Vector2, rect: Rect2) -> Vector2:
	var dx := p1.x - p0.x
	var dy := p1.y - p0.y
	var t := 1.0  # parameter along segment (0=p0, 1=p1)

	# Test each of the four clipping edges.
	# Left: x = rect.position.x
	if dx != 0.0:
		var t_left := (rect.position.x - p0.x) / dx
		if t_left >= 0.0 and t_left < t:
			var y_at := p0.y + t_left * dy
			if y_at >= rect.position.y and y_at <= rect.end.y:
				t = t_left
	# Right: x = rect.end.x
	if dx != 0.0:
		var t_right := (rect.end.x - p0.x) / dx
		if t_right >= 0.0 and t_right < t:
			var y_at := p0.y + t_right * dy
			if y_at >= rect.position.y and y_at <= rect.end.y:
				t = t_right
	# Top: y = rect.position.y
	if dy != 0.0:
		var t_top := (rect.position.y - p0.y) / dy
		if t_top >= 0.0 and t_top < t:
			var x_at := p0.x + t_top * dx
			if x_at >= rect.position.x and x_at <= rect.end.x:
				t = t_top
	# Bottom: y = rect.end.y
	if dy != 0.0:
		var t_bot := (rect.end.y - p0.y) / dy
		if t_bot >= 0.0 and t_bot < t:
			var x_at := p0.x + t_bot * dx
			if x_at >= rect.position.x and x_at <= rect.end.x:
				t = t_bot

	return Vector2(p0.x + t * dx, p0.y + t * dy)
