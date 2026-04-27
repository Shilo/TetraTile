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
		_refresh_preset_bitmask()
		notify_property_list_changed()
		emit_changed()

@export var tile_count: TileCountMode = TileCountMode.AUTO:
	set(value):
		if tile_count == value:
			return
		tile_count = value
		_refresh_preset_bitmask()
		emit_changed()

# When true, `bitmask_template` was auto-assigned from the (axis × tile_count) preset
# lookup and may be replaced when those properties change. When the user assigns a
# texture themselves, this flips false and `_refresh_preset_bitmask` becomes a no-op
# so user art is never silently overwritten.
@export_storage var _bitmask_is_preset: bool = true

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
#
# strip_index (default 0) is the synthesized atlas Y-row to dispatch to. AUTO_STRIP
# resolves per painted cell via `resolve_display_strip`; AUTO/explicit always 0.
func mask_to_atlas(mask: int, strip_index: int = 0) -> PentaTileAtlasSlot:
	match mask:
		0:
			return null
		1:
			# TL only → OuterCorner via rotation reuse on slot 0 — Path B locked, see
			# 02-02-PLAN.md Gate 1 OuterCorner row + clarifying paragraph (PentaTile does NOT
			# synthesize a dedicated OuterCorner cell; slot 0 is rendered with _ROTATE_90).
			return _make_slot(_SLOT_ISOLATED_CELL, _ROTATE_90, strip_index)
		2:
			# TR only → OuterCorner via rotation reuse on slot 0 — Path B locked, see
			# 02-02-PLAN.md Gate 1 OuterCorner row + clarifying paragraph.
			return _make_slot(_SLOT_ISOLATED_CELL, _ROTATE_180, strip_index)
		3:
			# TL + TR → border facing top
			return _make_slot(_SLOT_BORDER, _ROTATE_180, strip_index)
		4:
			# BL only → OuterCorner via rotation reuse on slot 0 — Path B locked, see
			# 02-02-PLAN.md Gate 1 OuterCorner row + clarifying paragraph.
			return _make_slot(_SLOT_ISOLATED_CELL, _ROTATE_0, strip_index)
		5:
			return _make_slot(_SLOT_BORDER, _ROTATE_90, strip_index)
		6:
			# TR + BL = "/" diagonal — OppositeCorners with TRANSFORM_FLIP_H (vs PentaTile's _ROTATE_0 anchor on mask 9)
			return _make_slot(_SLOT_OPPOSITE_CORNERS, TileSetAtlasSource.TRANSFORM_FLIP_H, strip_index)
		7:
			return _make_slot(_SLOT_INNER_CORNER, _ROTATE_90, strip_index)
		8:
			# BR only → OuterCorner via rotation reuse on slot 0 — Path B locked, see
			# 02-02-PLAN.md Gate 1 OuterCorner row + clarifying paragraph.
			return _make_slot(_SLOT_ISOLATED_CELL, _ROTATE_270, strip_index)
		9:
			# TL + BR = "\\" diagonal — OppositeCorners ANCHOR (PentaTile canonical _ROTATE_0)
			return _make_slot(_SLOT_OPPOSITE_CORNERS, _ROTATE_0, strip_index)
		10:
			return _make_slot(_SLOT_BORDER, _ROTATE_270, strip_index)
		11:
			return _make_slot(_SLOT_INNER_CORNER, _ROTATE_180, strip_index)
		12:
			return _make_slot(_SLOT_BORDER, _ROTATE_0, strip_index)
		13:
			return _make_slot(_SLOT_INNER_CORNER, _ROTATE_0, strip_index)
		14:
			return _make_slot(_SLOT_INNER_CORNER, _ROTATE_270, strip_index)
		15:
			return _make_slot(_SLOT_FILL, _ROTATE_0, strip_index)
	push_error("PentaTileLayoutPenta.mask_to_atlas got out-of-range mask %d" % mask)
	return null


# Build an AtlasSlot — output coords are Vector2i(slot_index, strip_index).
#
# WR-07 FIX: the SYNTHESIZED atlas is ALWAYS a horizontal strip regardless of `axis`.
# The user-facing `axis` enum governs only which axis the synthesizer WALKS when
# reading the source TileSet — the OUTPUT layout is invariant in the slot dimension.
#
# AUTO_STRIP extension: the OUTPUT atlas is 5 cols × N rows where N = strip count.
# strip_index selects the Y-row. For AUTO/explicit modes (single-strip output),
# strip_index is always 0 → output coord (slot_index, 0), bit-identical to the
# pre-AUTO_STRIP behavior. For AUTO_STRIP, the layer threads a per-display-cell
# strip_index from `resolve_display_strip` so per-strip dispatch lands at
# Vector2i(slot_index, strip_index).
func _make_slot(slot_index: int, transform_flags: int, strip_index: int = 0) -> PentaTileAtlasSlot:
	var slot := PentaTileAtlasSlot.new()
	slot.atlas_coords = Vector2i(slot_index, strip_index)                            # synthesized atlas: 5 cols × N rows
	slot.transform_flags = transform_flags
	slot.alternative_tile = 0                                                        # no variation in Phase 2
	return slot


# AUTO_STRIP per-strip dispatch: returns the strip_index for `coord` based on the
# FIRST non-empty TL/TR/BL/BR neighbor's source-atlas coords (canonical order).
# AUTO/explicit modes always return 0 (single-strip output atlas).
#
# RULE (locked): scan neighbors in TL → TR → BL → BR order; the first non-empty
# neighbor's source-atlas coord component (Y for HORIZONTAL, X for VERTICAL)
# becomes the strip_index. If all 4 neighbors empty, return 0 (caller's mask
# will be 0 anyway → erase, strip_index irrelevant).
#
# DOCUMENTED v0.2 LIMITATION: when the 4 neighbors disagree on strip identity
# (different terrains adjacent), the FIRST non-empty neighbor's strip wins for
# the entire 16-state mask dispatch at this display cell. The visual boundary
# between two different-mode strips may render wrong — proper terrain
# transitions are MULTITERR-* in the v2 backlog (out of v0.2 scope).
func resolve_display_strip(coord: Vector2i, sample_atlas_fn: Callable) -> int:
	if tile_count != TileCountMode.AUTO_STRIP:
		return 0                                                                      # single-strip output for AUTO/explicit
	# Same neighbor offsets compute_mask uses (TL/TR/BL/BR).
	for offset in [_TL, _TR, _BL, _BR]:
		var atlas_coords: Vector2i = sample_atlas_fn.call(coord + offset)
		if atlas_coords.x >= 0 and atlas_coords.y >= 0:                              # non-empty (Vector2i(-1,-1) sentinel = empty)
			return atlas_coords.y if axis == Axis.HORIZONTAL else atlas_coords.x
	return 0                                                                          # all neighbors empty (mask will be 0)


# ---------------------------------------------------------------------------
# Wave 6: AUTO/AUTO_STRIP detection + configuration warnings
# ---------------------------------------------------------------------------

# PENTA-SYNTH-02: AUTO-mode dimension-only detection. O(1).
# Returns the active TileCountMode for this layout given the current source TileSet.
# When tile_count is explicit (ONE..FIVE), returns it directly (skips detection).
# When AUTO, reads atlas axis size and maps 1→ONE/2→TWO/.../5→FIVE; 0/6+ → AUTO (caller
# treats as malformed and renders nothing).
# AUTO_STRIP returns AUTO_STRIP itself; strip-by-strip resolution lives in resolve_strip_modes.
func resolve_active_mode(tile_set: TileSet, source_id: int) -> TileCountMode:
	if tile_count != TileCountMode.AUTO and tile_count != TileCountMode.AUTO_STRIP:
		return tile_count
	if tile_count == TileCountMode.AUTO_STRIP:
		return TileCountMode.AUTO_STRIP
	if tile_set == null or source_id < 0:
		return TileCountMode.AUTO       # caller renders nothing
	var src := tile_set.get_source(source_id) as TileSetAtlasSource
	if src == null:
		return TileCountMode.AUTO
	var grid_size := src.get_atlas_grid_size()
	var axis_size: int = grid_size.x if axis == Axis.HORIZONTAL else grid_size.y
	match axis_size:
		1: return TileCountMode.ONE
		2: return TileCountMode.TWO
		3: return TileCountMode.THREE
		4: return TileCountMode.FOUR
		5: return TileCountMode.FIVE
		_: return TileCountMode.AUTO    # 0 or 6+ → unresolved; caller renders nothing


# PENTA-SYNTH-03: AUTO_STRIP per-strip detection. O(strips × axis_size).
# Returns one TileCountMode per strip in source-axis order. Strip indices match
# the OPPOSITE axis from `axis` (HORIZONTAL strips run along X within a Y-row;
# so for HORIZONTAL there are atlas_grid_size.y strips, each of length .x).
func resolve_strip_modes(tile_set: TileSet, source_id: int) -> Array:
	var modes: Array = []
	if tile_set == null or source_id < 0:
		return modes
	var src := tile_set.get_source(source_id) as TileSetAtlasSource
	if src == null:
		return modes
	var grid_size := src.get_atlas_grid_size()
	var strip_axis_size: int = grid_size.x if axis == Axis.HORIZONTAL else grid_size.y
	var strip_count: int = grid_size.y if axis == Axis.HORIZONTAL else grid_size.x
	for strip_index in range(strip_count):
		# Gap detection per the locked spec:
		#   populated [1,1,1,0,0] → THREE  (trailing empties OK — short strip in a
		#                                     wider atlas where other strips are longer)
		#   populated [1,1,0,1,0] → AUTO   (gap: empty followed by populated)
		#
		# Algorithm: count consecutive populated slots from slot 0. Once we see an
		# empty slot, we mark `seen_empty = true`. If we then see ANY populated slot
		# while `seen_empty` is true, that's a gap → AUTO. Otherwise the
		# `populated_count` we accumulated before the first empty IS the strip's mode.
		var populated_count := 0
		var seen_empty := false
		var gap_detected := false
		for slot in range(strip_axis_size):
			var atlas_coords: Vector2i = (
				Vector2i(slot, strip_index) if axis == Axis.HORIZONTAL
				else Vector2i(strip_index, slot)
			)
			var populated := src.has_tile(atlas_coords)
			if populated:
				if seen_empty:
					# Empty THEN populated = gap. Strip is malformed.
					gap_detected = true
					break
				populated_count += 1
			else:
				seen_empty = true
		if gap_detected:
			modes.append(TileCountMode.AUTO)
		else:
			match populated_count:
				1: modes.append(TileCountMode.ONE)
				2: modes.append(TileCountMode.TWO)
				3: modes.append(TileCountMode.THREE)
				4: modes.append(TileCountMode.FOUR)
				5: modes.append(TileCountMode.FIVE)
				_: modes.append(TileCountMode.AUTO)    # 0 / 6+ → unresolved
	return modes


# PENTA-SYNTH-08: emit configuration warnings. Called by PentaTileMapLayer's
# _get_configuration_warnings hook to surface issues in the inspector's warning panel.
# Returns one PackedStringArray of human-readable warnings covering three failure modes:
#   A — atlas axis size 0 or 6+ in AUTO / AUTO_STRIP (cannot detect; will not render)
#   B — explicit tile_count and atlas axis size disagree (mismatch; partial render)
#   C — AUTO_STRIP gap (slot N populated but slot N-1 empty; strip renders empty)
func get_configuration_warnings_for(tile_set: TileSet, source_id: int) -> PackedStringArray:
	var out := PackedStringArray()
	if tile_set == null or source_id < 0:
		return out
	var src := tile_set.get_source(source_id) as TileSetAtlasSource
	if src == null:
		return out
	var grid_size := src.get_atlas_grid_size()
	var axis_size: int = grid_size.x if axis == Axis.HORIZONTAL else grid_size.y

	# Warning A — atlas axis size out of supported range in AUTO / AUTO_STRIP
	if tile_count == TileCountMode.AUTO or tile_count == TileCountMode.AUTO_STRIP:
		if axis_size == 0 or axis_size >= 6:
			out.append("PentaTileLayoutPenta: atlas %s-axis size is %d; AUTO/AUTO_STRIP supports 1..5. Atlas will not render." % ["X" if axis == Axis.HORIZONTAL else "Y", axis_size])

	# Warning B — explicit tile_count and atlas axis size disagree
	if tile_count >= TileCountMode.ONE and tile_count <= TileCountMode.FIVE:
		if axis_size != int(tile_count):
			out.append("PentaTileLayoutPenta: explicit tile_count = %d but atlas %s-axis size is %d. Atlas slots beyond the tile_count will be ignored; missing archetypes synthesized from slot 0." % [int(tile_count), "X" if axis == Axis.HORIZONTAL else "Y", axis_size])

	# Warning C — AUTO_STRIP gappy strip
	if tile_count == TileCountMode.AUTO_STRIP:
		var strip_count: int = grid_size.y if axis == Axis.HORIZONTAL else grid_size.x
		for strip_index in range(strip_count):
			var prev_populated := true
			for slot in range(axis_size):
				var atlas_coords: Vector2i = (
					Vector2i(slot, strip_index) if axis == Axis.HORIZONTAL
					else Vector2i(strip_index, slot)
				)
				var populated := src.has_tile(atlas_coords)
				if not prev_populated and populated:
					out.append("PentaTileLayoutPenta: AUTO_STRIP detected gap in strip %d (slot %d empty but slot %d populated). Strip will render empty." % [strip_index, slot - 1, slot])
					break
				prev_populated = populated
	return out


# bitmask_template is VISIBLE in the inspector for PentaTileLayoutPenta. Auto-populated
# from `_BITMASK_TEMPLATE_LOOKUP[axis × tile_count]` so users see the canonical preset
# silhouette as soon as they pick a layout, AND can override with their own art (the
# override flips `_bitmask_is_preset = false` so axis/tile_count changes stop overwriting).


# Track whether bitmask_template assignment came from a manual user action vs the
# auto-preset path. Suppressed during the preset write so internal assignments do not
# flip the flag.
var _suppress_preset_override := false


# Intercepts inspector / scripted assignments to bitmask_template. Returning false
# lets the default property handler proceed AFTER our hook records the override.
# This is the canonical Godot 4 pattern for "observe writes to an existing @export var".
func _set(property: StringName, value: Variant) -> bool:
	if property == "bitmask_template" and not _suppress_preset_override:
		if value != bitmask_template:
			_bitmask_is_preset = false                                                # user picked their own art
	return false


# Auto-populate bitmask_template from the (axis × tile_count) preset PNG. No-op when
# the user has overridden with their own texture. Called from axis/tile_count setters
# and from _init for fresh resources.
func _refresh_preset_bitmask() -> void:
	if not _bitmask_is_preset:
		return
	var resolved := tile_count
	if resolved == TileCountMode.AUTO or resolved == TileCountMode.AUTO_STRIP:
		resolved = TileCountMode.FOUR                                                 # inspector preview default
	var path: String = _bundled_png_path(axis, resolved)
	if path.is_empty():
		return
	var tex := load(path) as Texture2D
	if tex == null:
		return
	_suppress_preset_override = true
	bitmask_template = tex
	_suppress_preset_override = false


func _init() -> void:
	# Fires for both fresh-in-inspector instantiation AND .tres-loaded resources. For
	# .tres-loaded the property loader runs AFTER _init and overwrites with saved state
	# (correct: saved bitmask wins). For fresh inspector instantiation, _init's preset
	# binding makes the canonical FOUR-mode silhouette visible immediately.
	_refresh_preset_bitmask()


# WR-04 FIX: typed accessor for the axis × mode → bundled PNG lookup. Enforces the
# precondition that `m` is a concrete ONE..FIVE before keying — AUTO (0) and AUTO_STRIP
# (-1) are caller bugs at this layer (the inspector preview / fallback path resolves
# AUTO/AUTO_STRIP to a concrete mode upstream). The assertion fails loud rather than
# silently returning the empty default that an unguarded `.get(key, "")` would mask.
# Numerically the Axis enum (HORIZONTAL=0, VERTICAL=1) overlaps TileCountMode in range
# (AUTO=0, ONE=1) — Vector2i field POSITION distinguishes them, but the assertion
# documents AND enforces the contract at the call site.
func _bundled_png_path(a: Axis, m: TileCountMode) -> String:
	assert(m >= TileCountMode.ONE and m <= TileCountMode.FIVE,
		"_bundled_png_path requires concrete TileCountMode.ONE..FIVE; got %d (resolve AUTO/AUTO_STRIP upstream)" % int(m))
	var key := Vector2i(a, m)
	return _BITMASK_TEMPLATE_LOOKUP.get(key, "")


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
	# WR-04 FIX: route the lookup through _bundled_png_path so the AUTO/AUTO_STRIP
	# (mode <= 0) misuse class fails LOUD at the assert rather than silently returning
	# the empty default. Vector2i(axis, mode) keys collide with axis values numerically
	# (HORIZONTAL=0 == AUTO=0; VERTICAL=1 == ONE=1) — the typed accessor enforces the
	# precondition that mode is always a concrete ONE..FIVE before keying.
	var path: String = _bundled_png_path(axis, resolved_mode)
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
