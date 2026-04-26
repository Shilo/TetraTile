@tool
## PentaTile Penta layout — 5-archetype dual-grid autotiling.
##
## Slot ordering (LOCKED in Phase 2 architectural sweep):
##   0 = IsolatedCell  (always present; synthesizes OuterCorner across all modes; feeds other archetypes when their slot is unfilled)
##   1 = Fill          (added at TWO mode and above)
##   2 = Border        (added at THREE mode and above; visual-frequency ordering puts Border before InnerCorner)
##   3 = InnerCorner   (added at FOUR mode and above)
##   4 = OppositeCorners (added at FIVE mode)
##
## OuterCorner is IMPLICIT — synthesized from slot 0 with rotation transforms across
## all modes. Never has a dedicated slot. (Acceptable per the user-confirmed design:
## an isolated cell visually IS four outer corners + edges + fill, so OuterCorner art
## is naturally expressed via slot 0.)
##
## Mask convention: TL=1, TR=2, BL=4, BR=8 (corner mask).
##
## ANCHORING NOTE (Excalibur.js cross-reference): PentaTile anchors mask 9 (TL+BR,
## "\\" diagonal) as the unrotated OppositeCorners case (`_ROTATE_0`). The Excalibur.js
## dual-grid reference (https://excaliburjs.com/blog/Dual%20Tilemap%20Autotiling%20Technique/)
## uses the opposite anchor (mask 6 = TR+BL = "/" diagonal). Both are valid conventions.
## If you author your OppositeCorners tile against the Excalibur convention, mask 6 and
## mask 9 will appear swapped — flip the sprite horizontally to match PentaTile's
## anchoring. PentaTile picks mask 9 = `_ROTATE_0` because it matches the project's
## TL=1 lowest-bit-first ordering (also used in `draw_corner_mask` in the bitmask
## generator script and across all corner-mask layouts in the project).
##
## CODENAME DISCIPLINE: "Penta" is reserved exclusively for the 5-archetype tileset
## format. This file is the canonical home of that codename. See CLAUDE.md
## § Coined-Term Discipline.
##
## Dual-grid: yes — paints at the half-tile-offset display cell.
## Synthesis: see PentaTileSynthesis (penta_tile_synthesis.gd).
class_name PentaTileLayoutPenta
extends PentaTileLayout

enum Axis {
	HORIZONTAL = 0,
	VERTICAL = 1,
}

enum TileCountMode {
	AUTO = 0,
	AUTO_STRIP = -1,                                                                 # negative sentinel; explicit ONE..FIVE use their numeric tile count
	ONE = 1,
	TWO = 2,
	THREE = 3,
	FOUR = 4,
	FIVE = 5,
}

@export var axis: Axis = Axis.HORIZONTAL:
	set(value):
		if axis == value:
			return
		axis = value
		notify_property_list_changed()
		emit_changed()

@export var tile_count: TileCountMode = TileCountMode.AUTO:
	set(value):
		if tile_count == value:
			return
		tile_count = value
		emit_changed()

# Class-level lookup table for axis × mode → bundled bitmask PNG path.
# Used by _validate_property to hide bitmask_template AND by get_fallback_tile_set()
# when computing the active fallback PNG for the current axis × mode.
# Resource paths land in Wave 5 (PNG migration); for now they reference the
# post-migration co-located paths (PNGs themselves materialize in Wave 5 — Godot
# will warn about missing resources between Wave 3 and Wave 5; that's accepted
# per CLAUDE.md Breaking Changes Policy intermediate-state allowance).
# H-4 BLOCKER FIX: keys are Vector2i(axis, mode), NOT [axis, mode] arrays.
# Godot 4.6 Dictionary uses Variant hashing, and Array key hash semantics vs. ==
# equality are not guaranteed identical (undocumented for Godot 4.x). Vector2i is a
# primitive value type with well-defined hash + equality across all 4.x versions —
# two Vector2i with same x/y always hash identically and compare equal. This removes
# the lookup-may-always-miss ambiguity that the audit identified.
# Note: TileCountMode.AUTO and AUTO_STRIP resolve to a concrete mode at runtime; the
# lookup is only invoked AFTER detection resolves to ONE..FIVE (1..5), so AUTO/AUTO_STRIP
# keys are not present in this table.
const _BITMASK_TEMPLATE_LOOKUP := {
	# Vector2i(axis, mode) → res:// path
	Vector2i(Axis.HORIZONTAL, TileCountMode.ONE):   "res://addons/penta_tile/layouts/penta_tile_layout_penta/one_horizontal.png",
	Vector2i(Axis.HORIZONTAL, TileCountMode.TWO):   "res://addons/penta_tile/layouts/penta_tile_layout_penta/two_horizontal.png",
	Vector2i(Axis.HORIZONTAL, TileCountMode.THREE): "res://addons/penta_tile/layouts/penta_tile_layout_penta/three_horizontal.png",
	Vector2i(Axis.HORIZONTAL, TileCountMode.FOUR):  "res://addons/penta_tile/layouts/penta_tile_layout_penta/four_horizontal.png",
	Vector2i(Axis.HORIZONTAL, TileCountMode.FIVE):  "res://addons/penta_tile/layouts/penta_tile_layout_penta/five_horizontal.png",
	Vector2i(Axis.VERTICAL,   TileCountMode.ONE):   "res://addons/penta_tile/layouts/penta_tile_layout_penta/one_vertical.png",
	Vector2i(Axis.VERTICAL,   TileCountMode.TWO):   "res://addons/penta_tile/layouts/penta_tile_layout_penta/two_vertical.png",
	Vector2i(Axis.VERTICAL,   TileCountMode.THREE): "res://addons/penta_tile/layouts/penta_tile_layout_penta/three_vertical.png",
	Vector2i(Axis.VERTICAL,   TileCountMode.FOUR):  "res://addons/penta_tile/layouts/penta_tile_layout_penta/four_vertical.png",
	Vector2i(Axis.VERTICAL,   TileCountMode.FIVE):  "res://addons/penta_tile/layouts/penta_tile_layout_penta/five_vertical.png",
}

# Slot indices in the synthesized strip (locked Phase 2 ordering).
# Literal values mirror PentaTileSynthesis.SLOT_* constants — class-level const
# cannot reference another class's const at parse time in GDScript 2 (resolved
# before the class_name symbol table is populated). Values must stay in sync with
# PentaTileSynthesis manually; an assert in PentaTileSynthesis guards divergence.
const _SLOT_ISOLATED_CELL   := 0  # PentaTileSynthesis.SLOT_ISOLATED_CELL
const _SLOT_FILL             := 1  # PentaTileSynthesis.SLOT_FILL
const _SLOT_BORDER           := 2  # PentaTileSynthesis.SLOT_BORDER
const _SLOT_INNER_CORNER     := 3  # PentaTileSynthesis.SLOT_INNER_CORNER
const _SLOT_OPPOSITE_CORNERS := 4  # PentaTileSynthesis.SLOT_OPPOSITE_CORNERS

# Transform-flag rotations (relocated from Phase 1 with constant names preserved).
const _ROTATE_0 := 0
const _ROTATE_90 := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
const _ROTATE_180 := TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
const _ROTATE_270 := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V

# Corner-neighbor offsets (preserved from Phase 1).
const _TL := Vector2i(-1, -1)
const _TR := Vector2i(0, -1)
const _BL := Vector2i(-1, 0)
const _BR := Vector2i(0, 0)


func is_dual_grid() -> bool:
	return true


func needs_synthesis() -> bool:
	return true


func compute_mask(coord: Vector2i, sample_fn: Callable) -> int:
	var mask := 0
	if sample_fn.call(coord + _TL): mask |= 1
	if sample_fn.call(coord + _TR): mask |= 2
	if sample_fn.call(coord + _BL): mask |= 4
	if sample_fn.call(coord + _BR): mask |= 8
	return mask


# 16-state corner-mask resolution under the new Phase 2 slot ordering.
# Slot indices remapped from Phase 1's horizontal layout per the locked ordering;
# OuterCorner now derives from slot 0 + transform per Gate 1 anchoring spec.
#
# Mask 0 returns null (dispatcher short-circuits to erase).
# Masks 6 and 9 use slot 4 (OppositeCorners) directly — single-layer paint, no
# overlay. The complement-corner pixels are pre-baked into slot 4 by synthesis
# (FIVE mode) or hand-authored (FIVE mode authored explicitly).
func mask_to_atlas(mask: int) -> PentaTileAtlasSlot:
	match mask:
		0:
			return null
		1:
			# TL only → OuterCorner via rotation reuse on slot 0 — Path B locked, see
			# 02-02-PLAN.md Gate 1 OuterCorner row + clarifying paragraph (PentaTile does NOT
			# synthesize a dedicated OuterCorner cell; slot 0 is rendered with _ROTATE_90).
			return _make_slot(_SLOT_ISOLATED_CELL, _ROTATE_90)
		2:
			# TR only → OuterCorner via rotation reuse on slot 0 — Path B locked, see
			# 02-02-PLAN.md Gate 1 OuterCorner row + clarifying paragraph.
			return _make_slot(_SLOT_ISOLATED_CELL, _ROTATE_180)
		3:
			# TL + TR → border facing top
			return _make_slot(_SLOT_BORDER, _ROTATE_180)
		4:
			# BL only → OuterCorner via rotation reuse on slot 0 — Path B locked, see
			# 02-02-PLAN.md Gate 1 OuterCorner row + clarifying paragraph.
			return _make_slot(_SLOT_ISOLATED_CELL, _ROTATE_0)
		5:
			return _make_slot(_SLOT_BORDER, _ROTATE_90)
		6:
			# TR + BL = "/" diagonal — OppositeCorners with TRANSFORM_FLIP_H (vs PentaTile's _ROTATE_0 anchor on mask 9)
			return _make_slot(_SLOT_OPPOSITE_CORNERS, TileSetAtlasSource.TRANSFORM_FLIP_H)
		7:
			return _make_slot(_SLOT_INNER_CORNER, _ROTATE_90)
		8:
			# BR only → OuterCorner via rotation reuse on slot 0 — Path B locked, see
			# 02-02-PLAN.md Gate 1 OuterCorner row + clarifying paragraph.
			return _make_slot(_SLOT_ISOLATED_CELL, _ROTATE_270)
		9:
			# TL + BR = "\\" diagonal — OppositeCorners ANCHOR (PentaTile canonical _ROTATE_0)
			return _make_slot(_SLOT_OPPOSITE_CORNERS, _ROTATE_0)
		10:
			return _make_slot(_SLOT_BORDER, _ROTATE_270)
		11:
			return _make_slot(_SLOT_INNER_CORNER, _ROTATE_180)
		12:
			return _make_slot(_SLOT_BORDER, _ROTATE_0)
		13:
			return _make_slot(_SLOT_INNER_CORNER, _ROTATE_0)
		14:
			return _make_slot(_SLOT_INNER_CORNER, _ROTATE_270)
		15:
			return _make_slot(_SLOT_FILL, _ROTATE_0)
	push_error("PentaTileLayoutPenta.mask_to_atlas got out-of-range mask %d" % mask)
	return null


# Build an AtlasSlot — branches on `axis` for X-axis vs Y-axis layout.
# Replaces Phase 1's _make_slot override-in-subclass pattern.
func _make_slot(slot_index: int, transform_flags: int) -> PentaTileAtlasSlot:
	var slot := PentaTileAtlasSlot.new()
	if axis == Axis.HORIZONTAL:
		slot.atlas_coords = Vector2i(slot_index, 0)                                  # x-axis strip
	else:
		slot.atlas_coords = Vector2i(0, slot_index)                                  # y-axis strip
	slot.transform_flags = transform_flags
	slot.alternative_tile = 0                                                        # no variation in Phase 2
	return slot


# PENTA-SYNTH-09: hide bitmask_template from inspector. Auto-resolved per axis × mode
# via _BITMASK_TEMPLATE_LOOKUP at fallback-TileSet construction time.
func _validate_property(property: Dictionary) -> void:
	if property.name == "bitmask_template":
		# H-1 BLOCKER FIX: bitwise-clear PROPERTY_USAGE_EDITOR (1<<2) to remove inspector
		# visibility while preserving storage + other existing flags. An overwrite approach
		# (assigning a composite constant directly) discards any pre-existing flags —
		# the &= ~ pattern is the canonical Godot 4.6 idiom for hiding properties without
		# losing storage/READ_ONLY semantics.
		property.usage &= ~PROPERTY_USAGE_EDITOR


# Override base get_fallback_tile_set: builds a TileSet from the active axis × mode
# PNG. Mode-aware texture_region_size derivation (no hardcoded 16×16): tile dimensions
# are computed from the loaded texture's pixel dimensions divided by the strip's tile
# count (mode along strip axis × strip count along the other axis = 1 strip in this
# bundled-PNG case).
func get_fallback_tile_set() -> TileSet:
	# tile_count == AUTO or AUTO_STRIP needs a runtime detected mode — the layer
	# resolves that path; here we pick a sensible default of FOUR for the
	# inspector preview / fallback path. (Wave 6 wires runtime detection to
	# the actual layer.)
	var resolved_mode := tile_count
	if resolved_mode == TileCountMode.AUTO or resolved_mode == TileCountMode.AUTO_STRIP:
		resolved_mode = TileCountMode.FOUR
	# H-4 BLOCKER FIX: Vector2i key (matches the new dict-key type above) + .get() with
	# default empty string for graceful miss handling. Empty path → load() returns null →
	# we fall through to the warning + return null below.
	var key := Vector2i(axis, resolved_mode)
	var path: String = _BITMASK_TEMPLATE_LOOKUP.get(key, "")
	if path.is_empty():
		push_warning("PentaTileLayoutPenta: no bundled PNG for axis=%s mode=%s" % [axis, resolved_mode])
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		# Wave 3-5 intermediate state: PNG ships in Wave 5.
		return null
	# Mode-aware texture_region_size derivation (matches Wave 4 native-layout pattern).
	# Bundled Penta PNGs are single-strip:
	#   HORIZONTAL: mode tiles laid out along X; strip count = 1 along Y.
	#   VERTICAL:   mode tiles laid out along Y; strip count = 1 along X.
	var mode_count: int = int(resolved_mode)
	var tile_w: int
	var tile_h: int
	if axis == Axis.HORIZONTAL:
		tile_w = tex.get_width() / mode_count
		tile_h = tex.get_height()                                                    # single strip → full image height per tile
	else:
		tile_w = tex.get_width()                                                     # single strip → full image width per tile
		tile_h = tex.get_height() / mode_count
	var ts := TileSet.new()
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(tile_w, tile_h)
	ts.tile_size = Vector2i(tile_w, tile_h)
	ts.add_source(src, 0)
	# Create one tile per slot along the strip axis.
	for slot_index in range(mode_count):
		var atlas_coords: Vector2i = (
			Vector2i(slot_index, 0) if axis == Axis.HORIZONTAL
			else Vector2i(0, slot_index)
		)
		src.create_tile(atlas_coords)
	return ts
