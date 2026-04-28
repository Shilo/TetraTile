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
## STRIP LAYOUT (Interpretation A — locked): strips are PERPENDICULAR to the slot
## axis. For HORIZONTAL slots, each strip is a row at fixed Y; for VERTICAL slots,
## each strip is a column at fixed X. Strip i's slot 0 lives at a deterministic
## source coord based on `strip_index` alone — independent of other strips' tile
## counts. This matches `PentaTileLayoutPenta.resolve_strip_modes`.
##
## Parameters:
##   source_tile_set – user's TileSet (NOT mutated)
##   source_id       – atlas source id within source_tile_set
##   axis            – 0 = HORIZONTAL (slots along X), 1 = VERTICAL (slots along Y)
##   strip_index     – which strip (0 = first row/column under Interpretation A)
##   mode            – MODE_ONE..MODE_FIVE
##   strip_origin    – Optional Vector2i source-atlas coord of slot 0 of THIS strip.
##                     Default Vector2i(-1, -1) sentinel uses strip_index alone:
##                       HORIZONTAL: (0, strip_index)
##                       VERTICAL:   (strip_index, 0)
##                     Callers may override (e.g., synthetic test fixtures with
##                     non-canonical strip placement) but the default is correct
##                     for AUTO_STRIP per-strip dispatch and for the single-strip
##                     AUTO/explicit case (strip_index = 0).
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
		mode: int,
		strip_origin: Vector2i = Vector2i(-1, -1)) -> Dictionary:

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

	# Resolve strip_origin: source-atlas coord of slot 0 of THIS strip.
	# Under Interpretation A (strips perpendicular to slot axis), each strip's
	# slot 0 lives at a deterministic coord based on strip_index alone. The prior
	# `strip_index * _STRIP_SLOT_COUNT` formula (matching neither Interpretation
	# A nor the docstring's prior "cumulative offset" claim) was wrong for any
	# strip_index > 0; it only worked accidentally when strip_index == 0.
	var slot0_coords: Vector2i
	if strip_origin == Vector2i(-1, -1):
		if axis == 0:                                                                # HORIZONTAL: strips are rows at varying Y
			slot0_coords = Vector2i(0, strip_index)
		else:                                                                         # VERTICAL: strips are columns at varying X
			slot0_coords = Vector2i(strip_index, 0)
	else:
		slot0_coords = strip_origin

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
		# WR-03 FIX: derive authored slot coords from slot0_coords, NOT from the
		# raw strip_index * _STRIP_SLOT_COUNT formula. That keeps AUTO_STRIP per-strip
		# dispatch correct — caller supplies the cumulative origin reflecting prior
		# strips' actual widths, and authored slots N step off it by N along the axis.
		var src_atlas_coords: Vector2i
		if out_slot < authored_count:
			if axis == 0:  # HORIZONTAL
				src_atlas_coords = slot0_coords + Vector2i(out_slot, 0)
			else:  # VERTICAL
				src_atlas_coords = slot0_coords + Vector2i(0, out_slot)
		else:
			# Synthesized slot — sources from slot 0 of this strip.
			src_atlas_coords = slot0_coords

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


## Axis-aligned rectangle polygon clipping — canonical Sutherland-Hodgman algorithm.
## Clips against each of the 4 half-planes (left, right, top, bottom) in turn so all
## four crossing cases (in/in, in/out, out/in, out/out-but-crossing) fall out of the
## per-edge logic naturally. WR-01 FIX: the prior hand-rolled all-edges-at-once
## variant dropped the both-outside-but-segment-crosses-rect case, silently mis-clipping
## non-convex source polygons.
##
## `points` in tile-center-local coords; `sub_rect` also in tile-center-local coords.
## Returns clipped polygon rescaled from sub_rect-local coords to full tile coords.
## Drops polygon (returns empty) if < 3 vertices remain after clipping.
static func clip_polygon_to_subrect(
		points: PackedVector2Array,
		sub_rect: Rect2,
		full_tile_size: Vector2) -> PackedVector2Array:
	if points.size() < 3:
		return PackedVector2Array()

	# Sutherland-Hodgman: clip the polygon against each half-plane in sequence.
	# Edge order: left, right, top, bottom. Edge constants encode which axis-aligned
	# half-plane to keep ("inside" = on the rect's side of the edge).
	#   0: left   — keep x >= rect.position.x
	#   1: right  — keep x <= rect.end.x
	#   2: top    — keep y >= rect.position.y
	#   3: bottom — keep y <= rect.end.y
	var clipped: PackedVector2Array = points
	for edge in range(4):
		clipped = _clip_against_edge(clipped, sub_rect, edge)
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


## Clip a polygon against a single axis-aligned half-plane edge of `rect`.
## edge: 0=left (x>=position.x), 1=right (x<=end.x), 2=top (y>=position.y), 3=bottom (y<=end.y).
## Standard Sutherland-Hodgman per-edge logic — handles all four crossing cases naturally
## (in/in, in/out, out/in, out/out — last case emits no vertices).
static func _clip_against_edge(
		points: PackedVector2Array,
		rect: Rect2,
		edge: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var n := points.size()
	if n == 0:
		return out
	for i in range(n):
		var v_curr: Vector2 = points[i]
		var v_prev: Vector2 = points[(i + n - 1) % n]
		var curr_in: bool = _point_inside_edge(v_curr, rect, edge)
		var prev_in: bool = _point_inside_edge(v_prev, rect, edge)
		if curr_in:
			if not prev_in:
				out.append(_intersect_edge(v_prev, v_curr, rect, edge))
			out.append(v_curr)
		elif prev_in:
			out.append(_intersect_edge(v_prev, v_curr, rect, edge))
	return out


## Returns true if `p` is on the "inside" side of the given axis-aligned half-plane edge.
## Boundary points are treated as inside (consistent with Sutherland-Hodgman convention).
static func _point_inside_edge(p: Vector2, rect: Rect2, edge: int) -> bool:
	match edge:
		0: return p.x >= rect.position.x
		1: return p.x <= rect.end.x
		2: return p.y >= rect.position.y
		3: return p.y <= rect.end.y
	return false


## Compute intersection of segment p0→p1 with a single axis-aligned edge line.
## edge: 0=left (x=position.x), 1=right (x=end.x), 2=top (y=position.y), 3=bottom (y=end.y).
## Caller guarantees the segment crosses the edge line (one endpoint inside, one outside).
static func _intersect_edge(p0: Vector2, p1: Vector2, rect: Rect2, edge: int) -> Vector2:
	var dx := p1.x - p0.x
	var dy := p1.y - p0.y
	match edge:
		0:
			# x = rect.position.x
			if dx == 0.0:
				return Vector2(rect.position.x, p0.y)
			var t := (rect.position.x - p0.x) / dx
			return Vector2(rect.position.x, p0.y + t * dy)
		1:
			# x = rect.end.x
			if dx == 0.0:
				return Vector2(rect.end.x, p0.y)
			var t := (rect.end.x - p0.x) / dx
			return Vector2(rect.end.x, p0.y + t * dy)
		2:
			# y = rect.position.y
			if dy == 0.0:
				return Vector2(p0.x, rect.position.y)
			var t := (rect.position.y - p0.y) / dy
			return Vector2(p0.x + t * dx, rect.position.y)
		3:
			# y = rect.end.y
			if dy == 0.0:
				return Vector2(p0.x, rect.end.y)
			var t := (rect.end.y - p0.y) / dy
			return Vector2(p0.x + t * dx, rect.end.y)
	return p0


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


## Builds a runtime TileSet from synthesize_strip output(s).
##
## Accepts EITHER a single result Dictionary (AUTO/explicit modes — produces a
## 5-col × 1-row atlas) OR an Array[Dictionary] (AUTO_STRIP — produces a 5-col ×
## N-row atlas where N = array length). Tile coords in the synthesized atlas are
## Vector2i(slot, strip_index); for the single-Dict / N=1 case strip_index is
## always 0 → bit-identical to the prior single-strip output.
##
## For the Array[Dict] form, `null` entries (or empty dicts) represent
## gap/unresolved strips and produce empty rows in the output atlas — painted
## cells dispatched to those strips will hit `has_tile() == false` and render
## empty (graceful degradation).
##
## The new TileSet contains one TileSetAtlasSource whose texture is composed from
## the slot images returned by synthesize_strip; collision/occlusion/navigation
## polygons are copied per Gate 2. The user's source TileSet is never mutated.
##
## Sub-region resize uses Image.INTERPOLATE_NEAREST exclusively (PENTA-SYNTH-06
## determinism — non-NEAREST produces pixel drift across runs).
##
## Returns null on hard failure (no usable strip with consistent tile_size).
static func build_tile_set_from_synthesis(result) -> TileSet:
	# Normalize: accept Dictionary or Array[Dictionary] uniformly. Single-Dict callers
	# get a 1-row atlas; multi-Dict callers get an N-row atlas. Same builder either way.
	var strip_results: Array = []
	if result is Dictionary:
		strip_results = [result]
	elif result is Array:
		strip_results = result
	else:
		return null
	if strip_results.is_empty():
		return null

	# Pick canonical tile_size + layer counts from the first non-empty strip.
	# All strips MUST share tile_size (same source TileSet); empty strips contribute
	# no metadata (their row in the output atlas stays empty).
	var tile_size: Vector2i = Vector2i.ZERO
	var physics_count: int = 0
	var occlusion_count: int = 0
	var navigation_count: int = 0
	for r in strip_results:
		if r is Dictionary and not r.is_empty() and r.has("slots") and not r["slots"].is_empty():
			var ts_v: Vector2i = r.get("tile_size", Vector2i.ZERO)
			if ts_v != Vector2i.ZERO:
				tile_size = ts_v
				physics_count = r.get("physics_layer_count", 0)
				occlusion_count = r.get("occlusion_layer_count", 0)
				navigation_count = r.get("navigation_layer_count", 0)
				break
	if tile_size == Vector2i.ZERO:
		return null

	# Compose atlas image: 5 cols × N rows. Each strip i populates row i.
	var n_strips: int = strip_results.size()
	var atlas_width: int = tile_size.x * _STRIP_SLOT_COUNT
	var atlas_height: int = tile_size.y * n_strips
	var atlas_image := Image.create(atlas_width, atlas_height, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color(0.0, 0.0, 0.0, 0.0))                                       # transparent background

	for strip_index in range(n_strips):
		var strip = strip_results[strip_index]
		if not (strip is Dictionary) or strip.is_empty() or not strip.has("slots"):
			continue                                                                  # gap/unresolved strip — row stays empty
		var slots: Array = strip["slots"]
		if slots.is_empty():
			continue
		for slot_i in range(slots.size()):
			var slot_dict: Dictionary = slots[slot_i]
			var slot_image: Image = slot_dict.get("image", null)
			if slot_image == null:
				slot_image = Image.create(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
				slot_image.fill(Color(0.0, 0.0, 0.0, 0.0))
			if slot_image.get_size() != tile_size:
				slot_image.resize(tile_size.x, tile_size.y, Image.INTERPOLATE_NEAREST)
			atlas_image.blit_rect(
				slot_image,
				Rect2i(Vector2i.ZERO, tile_size),
				Vector2i(slot_i * tile_size.x, strip_index * tile_size.y)
			)

	var ts := TileSet.new()
	ts.tile_size = tile_size

	# Mirror physics/occlusion/navigation layers from the source TileSet so
	# _copy_polygons_to_tile_data can write polygons without out-of-bounds errors.
	for _i in range(physics_count):
		ts.add_physics_layer()
	for _i in range(occlusion_count):
		ts.add_occlusion_layer()
	for _i in range(navigation_count):
		ts.add_navigation_layer()

	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(atlas_image)
	src.texture_region_size = tile_size
	ts.add_source(src, 0)

	# Create one tile per (slot, strip_index) for non-empty strips.
	for strip_index in range(n_strips):
		var strip = strip_results[strip_index]
		if not (strip is Dictionary) or strip.is_empty() or not strip.has("slots"):
			continue
		var slots: Array = strip["slots"]
		for slot_i in range(slots.size()):
			var atlas_coords := Vector2i(slot_i, strip_index)
			src.create_tile(atlas_coords)
			var tile_data := src.get_tile_data(atlas_coords, 0)
			if tile_data == null:
				continue
			var slot_dict: Dictionary = slots[slot_i]
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


## Synthesize slot `out_slot` image by composing rotated copies of slot 0's
## BL-quadrant outer-corner piece into the appropriate output positions.
##
## Slot 0 convention (locked across all Penta modes): BL quadrant of slot 0
## (pixels (0..ts/2-1, ts/2..ts-1)) contains a single outer-corner piece;
## other 3 quadrants are transparent.
##
## Output composition per slot:
##   SLOT_FILL (1, mask 15)           — 4 BL quadrants placed at output's 4
##                                      quadrants. For uniform fill art the
##                                      output is a continuous fill region.
##   SLOT_BORDER (2, canonical mask 12) — 2 BL quadrants placed at output's
##                                      BL + BR positions. Top half stays
##                                      transparent → bottom-edge tile.
##   SLOT_INNER_CORNER (3, canonical mask 13) — 3 BL quadrants at output's
##                                      TL + BL + BR. TR transparent.
##   SLOT_OPPOSITE_CORNERS (4, canonical mask 9) — 2 BL quadrants at output's
##                                      TL + BR (diagonal). TR + BL transparent.
##
## Earlier revisions stretched sub-rectangles of a full-silhouette slot 0
## (Fill = center 50% stretched, Border = bottom half stretched, etc.). That
## approach produced visibly broken output when the slot 0 source contained
## complex silhouette content — corner caps + edges + fill all mixed in a
## sub-region became distorted under stretch. The compose-from-quadrants
## approach is consistent (every synthesized slot built from the same source
## shape, just placed differently) and produces clean multi-cell rendering.
static func _synthesize_slot_image(
		atlas_image: Image,
		slot0_coords: Vector2i,
		out_slot: int,
		tile_size: Vector2i) -> Image:
	if atlas_image == null:
		var blank := Image.create(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
		blank.fill(Color(0.0, 0.0, 0.0, 0.0))
		return blank

	var ts := tile_size                                                                # shorthand
	var half := Vector2i(ts.x / 2, ts.y / 2)

	# Extract slot 0's BL quadrant once — shared by all archetypes.
	var slot0_px := Vector2i(slot0_coords.x * ts.x, slot0_coords.y * ts.y)
	var bl_region := Rect2i(slot0_px.x, slot0_px.y + half.y, half.x, half.y)
	var bl_quad := atlas_image.get_region(bl_region)

	# Output canvas — transparent base for every archetype's composition.
	var canvas := Image.create(ts.x, ts.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.0, 0.0, 0.0, 0.0))
	var src_full := Rect2i(Vector2i.ZERO, half)

	match out_slot:
		SLOT_FILL:
			# 4 quadrants — solid fill when slot 0 BL is solid.
			canvas.blit_rect(bl_quad, src_full, Vector2i(0, 0))                        # TL
			canvas.blit_rect(bl_quad, src_full, Vector2i(half.x, 0))                   # TR
			canvas.blit_rect(bl_quad, src_full, Vector2i(0, half.y))                   # BL
			canvas.blit_rect(bl_quad, src_full, Vector2i(half.x, half.y))              # BR
		SLOT_BORDER:
			# Canonical mask 12 = BL + BR painted = bottom edge facing up.
			# Bottom half filled, top half transparent.
			canvas.blit_rect(bl_quad, src_full, Vector2i(0, half.y))                   # BL
			canvas.blit_rect(bl_quad, src_full, Vector2i(half.x, half.y))              # BR
		SLOT_INNER_CORNER:
			# Canonical mask 13 = TL + BL + BR painted = inner corner pointing TR.
			# 3 quadrants filled, TR transparent.
			canvas.blit_rect(bl_quad, src_full, Vector2i(0, 0))                        # TL
			canvas.blit_rect(bl_quad, src_full, Vector2i(0, half.y))                   # BL
			canvas.blit_rect(bl_quad, src_full, Vector2i(half.x, half.y))              # BR
		SLOT_OPPOSITE_CORNERS:
			# Canonical mask 9 = TL + BR painted = "\\" diagonal.
			canvas.blit_rect(bl_quad, src_full, Vector2i(0, 0))                        # TL
			canvas.blit_rect(bl_quad, src_full, Vector2i(half.x, half.y))              # BR
		_:
			pass                                                                        # unknown slot → transparent canvas
	return canvas


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


## Note: the legacy _clip_segment_to_rect helper was removed in WR-01 fix —
## the canonical Sutherland-Hodgman implementation above (clip_polygon_to_subrect →
## _clip_against_edge → _intersect_edge) supersedes it and handles all four crossing
## cases correctly, including the previously-dropped both-outside-but-segment-crosses
## case.
