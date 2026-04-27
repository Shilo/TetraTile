@tool
@icon("res://icon.svg")
class_name PentaTileMapLayer
extends TileMapLayer

const _PRIMARY_LAYER_NAME := "_PentaTileVisual"

# Preload synthesis utility to avoid class_name symbol-table ordering failures
# in headless / --script mode where the global class registry is not pre-built.
# Using preload() guarantees the script is resolved at parse time regardless of
# registry state (Rule 1 fix — bare class_name references break outside editor).
const _PentaTileSynthesis = preload("res://addons/penta_tile/penta_tile_synthesis.gd")

@export var atlas_source_id: int = -1:
	set(value):
		atlas_source_id = value
		_queue_rebuild()

# LAYER-01: layout lives directly on PentaTileMapLayer (no PentaTileAtlasContract wrapper).
# Setter: idempotence guard first, then disconnect-before-reconnect on layout.changed.
# PITFALLS §5 — no signal-storm risk; _queue_rebuild coalesces via call_deferred.
@export var layout: PentaTileLayout:
	set(value):
		if layout == value:
			return                                                                  # idempotence (PITFALLS §5)
		if layout != null and layout.changed.is_connected(_on_layout_changed):
			layout.changed.disconnect(_on_layout_changed)
		layout = value
		_abstract_base_warning_emitted = false                                     # re-arm one-shot warning on rebind
		if layout != null:
			layout.changed.connect(_on_layout_changed)
		_queue_rebuild()
		update_configuration_warnings()                                            # H-3 trigger

@export_range(0.0, 1.0, 0.01) var logic_layer_opacity: float = 0.0:
	set(value):
		logic_layer_opacity = value
		_apply_logic_layer_opacity()

@export var visual_z_index_offset: int = 0:
	set(value):
		visual_z_index_offset = value
		_sync_visual_layers()

@export var generated_collision_enabled: bool = true:
	set(value):
		generated_collision_enabled = value
		_sync_visual_layers()

@export var logic_collision_enabled: bool = false:
	set(value):
		logic_collision_enabled = value
		_apply_logic_collision()

var _primary_layer: TileMapLayer

# Debug-build instrumentation (Phase 1 Wave 0 — verifies CONTRACT-05 idempotence).
# Counts every _queue_rebuild() call in debug builds. Read by verification recipes
# (Plan 05 idempotence + signal-storm checks). Excluded from release builds via
# OS.is_debug_build() gate inside _queue_rebuild.
var _rebuild_count: int = 0

# Wave 2 Task 2.3: synthesized TileSet cache for PentaTileLayoutPenta. Built lazily
# when (layout, axis, tile_count, source tile_set instance_id, source_id) changes;
# null when layout is not Penta or synthesis is not yet invoked.
# PENTA-SYNTH-06 invariant: re-runs only on input change → deterministic output.
var _synthesized_tile_set: TileSet = null
var _synthesis_signature: int = 0


func _ready() -> void:
	_ensure_visual_layers()
	_apply_logic_layer_opacity()
	_apply_logic_collision()
	rebuild.call_deferred()


func _update_cells(coords: Array[Vector2i], forced_cleanup: bool) -> void:
	_ensure_visual_layers()
	if forced_cleanup or tile_set == null:
		_clear_visual_layers()
		return

	_sync_visual_layers()
	if coords.is_empty():
		rebuild()
		return

	var active_layout := _resolve_layout()
	if active_layout == null:
		return
	var source := _resolve_source_id()
	if source == -1:
		return
	var sample_fn := Callable(self, "_has_logic_cell")

	var affected: Dictionary = {}
	if active_layout.is_dual_grid():
		for logic_cell: Vector2i in coords:
			_mark_affected_display_cells(affected, logic_cell)
	else:
		for logic_cell: Vector2i in coords:
			_mark_affected_single_grid_cells(affected, logic_cell)

	for display_cell: Vector2i in affected.keys():
		_paint_via_layout(display_cell, active_layout, source, sample_fn)


func rebuild() -> void:
	_ensure_visual_layers()
	_clear_visual_layers()
	if tile_set == null:
		return

	_sync_visual_layers()
	var active_layout := _resolve_layout()
	if active_layout == null:
		return
	var source := _resolve_source_id()
	if source == -1:
		return
	var sample_fn := Callable(self, "_has_logic_cell")

	var affected: Dictionary = {}
	if active_layout.is_dual_grid():
		for logic_cell: Vector2i in get_used_cells():
			_mark_affected_display_cells(affected, logic_cell)
	else:
		for logic_cell: Vector2i in get_used_cells():
			_mark_affected_single_grid_cells(affected, logic_cell)

	for display_cell: Vector2i in affected.keys():
		_paint_via_layout(display_cell, active_layout, source, sample_fn)


# PRESERVED from v0.1 (line 101-105). Dual-grid affected-cells: 4 corner offsets.
func _mark_affected_display_cells(affected: Dictionary, logic_cell: Vector2i) -> void:
	affected[logic_cell] = true
	affected[logic_cell + Vector2i.RIGHT] = true
	affected[logic_cell + Vector2i.DOWN] = true
	affected[logic_cell + Vector2i(1, 1)] = true


# NEW for D-06: Single-grid pipeline (logic and visual share the same grid).
# Marks cell + 4 cardinal neighbors. Phase 1 has no consumer (Penta H/V are dual-grid);
# Phase 2's Wang2Corner is the first consumer. Locked planner option (a) — ship the
# pipeline fully wired so Phase 2 layouts are pure subclass adds.
func _mark_affected_single_grid_cells(affected: Dictionary, logic_cell: Vector2i) -> void:
	affected[logic_cell] = true
	affected[logic_cell + Vector2i.UP] = true
	affected[logic_cell + Vector2i.DOWN] = true
	affected[logic_cell + Vector2i.LEFT] = true
	affected[logic_cell + Vector2i.RIGHT] = true


# The dispatcher per affected display cell. Computes mask once, short-circuits
# on 0 (universal cleanup per PITFALLS §4), resolves slot, paints primary layer.
# Overlay-layer path deleted in Wave 2 — single-layer dispatch only.
#
# AUTO_STRIP extension: resolve_display_strip selects the per-cell strip_index
# from the first non-empty TL/TR/BL/BR neighbor's source-atlas coords (Penta-only;
# base PentaTileLayout returns 0). Threaded into mask_to_atlas so per-strip
# dispatch lands at Vector2i(slot, strip_index) in the synthesized atlas.
func _paint_via_layout(display_cell: Vector2i, active_layout: PentaTileLayout, source: int, sample_fn: Callable) -> void:
	_primary_layer.erase_cell(display_cell)

	var mask := active_layout.compute_mask(display_cell, sample_fn)
	if mask == 0:
		return                                                                      # universal short-circuit (PITFALLS §4)

	var atlas_sample_fn := Callable(self, "_sample_logic_atlas_coords")
	var strip_index := active_layout.resolve_display_strip(display_cell, atlas_sample_fn)

	var slot := active_layout.mask_to_atlas(mask, strip_index)
	if slot == null:
		return
	_paint_with_slot(_primary_layer, slot, display_cell, source)


# Paints the primary slot. The slot carries atlas_coords directly (no _atlas_coords
# axis dispatch — D-19 removed that helper; the layout owns the axis via _make_slot).
func _paint_with_slot(layer: TileMapLayer, slot: PentaTileAtlasSlot, display_cell: Vector2i, source: int) -> void:
	if slot == null:
		layer.erase_cell(display_cell)
		return
	layer.set_cell(display_cell, source, slot.atlas_coords, slot.transform_flags)


# PRESERVED from v0.1 (line 168-169). Logic-cell sampling for the layout's
# compute_mask Callable.
func _has_logic_cell(logic_cell: Vector2i) -> bool:
	return get_cell_source_id(logic_cell) != -1


# AUTO_STRIP per-strip dispatch helper. Returns the source atlas_coords the user
# painted at `logic_cell` on the LOGIC layer (this PentaTileMapLayer itself, NOT
# the synthesized display layer). Returns Vector2i(-1, -1) when the cell is empty.
# Threaded into PentaTileLayoutPenta.resolve_display_strip via Callable.
func _sample_logic_atlas_coords(logic_cell: Vector2i) -> Vector2i:
	if get_cell_source_id(logic_cell) == -1:
		return Vector2i(-1, -1)
	return get_cell_atlas_coords(logic_cell)


# LAYER-02: read self.layout directly (one fewer hop than the prior contract chain).
# Returns null when layout is unassigned — the layer renders nothing in that case
# (no v0.1 hardcoded fallback per Phase 2 Breaking Changes Policy).
#
# Also returns null when `layout` is exactly the abstract `PentaTileLayout` base class
# (no subclass picked yet). The user can hit this state by selecting "New PentaTileLayout"
# in the inspector dropdown — without this guard, every paint would call abstract
# compute_mask / is_dual_grid and spam the console with `push_error` lines.
func _resolve_layout() -> PentaTileLayout:
	if layout == null:
		return null
	# Abstract-base guard. Direct script comparison (not is_class) — only the EXACT
	# base class is rejected; any subclass passes through.
	var script := layout.get_script()
	if script != null and script.resource_path == "res://addons/penta_tile/layouts/penta_tile_layout.gd":
		if not _abstract_base_warning_emitted:
			push_warning("PentaTileMapLayer: `layout` is the abstract `PentaTileLayout` base class — pick a concrete subclass (PentaTileLayoutPenta / DualGrid16 / Wang2Edge / Wang2Corner / Minimal3x3). Painting suppressed until a subclass is bound.")
			_abstract_base_warning_emitted = true
		return null
	return layout


# One-shot warning gate for the abstract-base layout case. Reset on layout setter so
# fixing the binding re-arms the warning if the user ever re-introduces the bug.
var _abstract_base_warning_emitted: bool = false


func _resolve_source_id() -> int:
	if tile_set == null:
		return -1
	if atlas_source_id >= 0:
		return atlas_source_id
	if tile_set.get_source_count() == 0:
		return -1
	return tile_set.get_source_id(0)


# Wave 2 overlay deletion: _ensure_visual_layers now creates only _primary_layer.
# Synthesis trigger wired in Task 2.3 — invokes PentaTileSynthesis before _sync.
func _ensure_visual_layers() -> void:
	if _primary_layer == null or not is_instance_valid(_primary_layer):
		_primary_layer = _get_or_create_visual_layer(_PRIMARY_LAYER_NAME)
	# Synthesis trigger: if the active layout needs synthesis (PentaTileLayoutPenta),
	# build/refresh the synthesized TileSet before routing it to the visual layer.
	# Uses needs_synthesis() virtual to avoid a forward type reference to Wave 3's class.
	var resolved_layout := _resolve_layout()
	if resolved_layout != null and resolved_layout.needs_synthesis():
		var source_id := _resolve_source_id()
		_ensure_synthesized_tile_set(resolved_layout, source_id)
	_sync_visual_layers()


# PRESERVED from v0.1 (line 206-214). Helper for visual layer instantiation.
func _get_or_create_visual_layer(layer_name: StringName) -> TileMapLayer:
	var existing := get_node_or_null(NodePath(layer_name))
	if existing is TileMapLayer:
		return existing

	var layer := TileMapLayer.new()
	layer.name = layer_name
	add_child(layer, false, Node.INTERNAL_MODE_FRONT)
	return layer


# Single-layer dispatch: iterate only [_primary_layer].
# Routes _primary_layer.tile_set through _synthesized_tile_set when synthesis is active
# (PENTA-SYNTH-06 + ROADMAP success criterion 13).
func _sync_visual_layers() -> void:
	_apply_logic_collision()
	var effective_tile_set: TileSet = _synthesized_tile_set if _synthesized_tile_set != null else tile_set
	for layer: TileMapLayer in [_primary_layer]:
		if layer == null or not is_instance_valid(layer):
			continue
		layer.tile_set = effective_tile_set
		layer.enabled = enabled
		layer.visible = true
		layer.z_index = visual_z_index_offset
		layer.rendering_quadrant_size = rendering_quadrant_size
		layer.y_sort_enabled = y_sort_enabled
		layer.y_sort_origin = y_sort_origin
		layer.x_draw_order_reversed = x_draw_order_reversed
		layer.collision_enabled = generated_collision_enabled
		layer.navigation_enabled = false
		layer.occlusion_enabled = false
		layer.position = _visual_layer_offset()


# CHANGED from v0.1: branches on the active layout's is_dual_grid().
# Dual-grid: -tile_size/2 (preserves v0.1 behavior).
# Single-grid: Vector2.ZERO (no half-tile shift; the cell lives at its own logic position).
func _visual_layer_offset() -> Vector2:
	if tile_set == null:
		return Vector2.ZERO
	var active_layout := _resolve_layout()
	if active_layout == null:
		return Vector2.ZERO
	if not active_layout.is_dual_grid():
		return Vector2.ZERO
	return Vector2(tile_set.tile_size) * -0.5


# Single-layer dispatch: iterate only [_primary_layer].
func _clear_visual_layers() -> void:
	for layer: TileMapLayer in [_primary_layer]:
		if layer != null and is_instance_valid(layer):
			layer.clear()


# PRESERVED VERBATIM from v0.1 (line 248-251). PITFALLS §7 mitigation —
# logic layer is hidden via self_modulate.a, never `visible = false`.
func _apply_logic_layer_opacity() -> void:
	var color := self_modulate
	color.a = logic_layer_opacity
	self_modulate = color


# PRESERVED from v0.1 (line 254-255).
func _apply_logic_collision() -> void:
	collision_enabled = logic_collision_enabled


# PRESERVED from Plan 01 Task 0.3 (Wave 0 instrumentation).
func _queue_rebuild() -> void:
	if OS.is_debug_build():
		_rebuild_count += 1
	if is_inside_tree():
		rebuild.call_deferred()


# PENTA-SYNTH-02 / 03 / 06: Build (or rebuild) the synthesized TileSet for a Penta layout.
# Re-runs only when the cache signature changes — same inputs produce bit-identical output.
# The user's source `tile_set` is never mutated.
#
# Wave 6 extension over Wave 2: AUTO and AUTO_STRIP resolve to a concrete int 1..5 via
# penta.resolve_active_mode (added in Task 6.1 step A) before invoking synthesize_strip.
# Explicit ONE..FIVE pass through unchanged.
#
# Forward-type note: penta is typed as PentaTileLayout (base); axis/tile_count accessed
# via dynamic get() (same Wave 2 pattern). resolve_active_mode called via has_method check.
func _ensure_synthesized_tile_set(penta: PentaTileLayout, source_id: int) -> void:
	# Access axis/tile_count via dynamic get() — avoids forward type reference to PentaTileLayoutPenta.
	var penta_axis: int = penta.get("axis") if penta.get("axis") != null else 0
	var penta_tile_count: int = penta.get("tile_count") if penta.get("tile_count") != null else 0
	var source_tile_set_id := tile_set.get_instance_id() if tile_set != null else 0

	# AUTO_STRIP enum value is -1 (TileCountMode.AUTO_STRIP). Branch on the RAW
	# tile_count, not the resolve_active_mode result (which returns AUTO_STRIP
	# unchanged for AUTO_STRIP). Per-strip path: call resolve_strip_modes,
	# loop strips, fold into a 5×N atlas via build_tile_set_from_synthesis(Array).
	const _AUTO_STRIP := -1
	if penta_tile_count == _AUTO_STRIP:
		# Cache key: hash strip_modes vector (recomputed every coalesced rebuild,
		# matches WR-02 pattern for AUTO mode drift detection).
		var strip_modes: Array = []
		if penta.has_method("resolve_strip_modes") and tile_set != null and source_id >= 0:
			strip_modes = penta.call("resolve_strip_modes", tile_set, source_id)
		var sig_strip := hash([
			penta.get_instance_id(),
			penta_axis,
			penta_tile_count,
			source_tile_set_id,
			source_id,
			strip_modes,
		])
		if sig_strip == _synthesis_signature and _synthesized_tile_set != null:
			return
		_synthesis_signature = sig_strip
		_synthesized_tile_set = null
		if tile_set == null or source_id < 0 or strip_modes.is_empty():
			return
		# Synthesize per-strip with the default strip_origin sentinel
		# (synthesize_strip now uses Interpretation A: HORIZONTAL → (0, i), VERTICAL → (i, 0)).
		# Empty/unresolved strips append null → row stays empty in the output atlas.
		var strip_results: Array = []
		for i in range(strip_modes.size()):
			var strip_mode: int = int(strip_modes[i])
			if strip_mode < 1 or strip_mode > 5:
				strip_results.append(null)
				continue
			var r: Dictionary = _PentaTileSynthesis.synthesize_strip(tile_set, source_id, penta_axis, i, strip_mode)
			strip_results.append(r)
		var synthesized_strip: TileSet = _PentaTileSynthesis.build_tile_set_from_synthesis(strip_results)
		if synthesized_strip == null:
			push_warning("PentaTileMapLayer: AUTO_STRIP synthesis produced no atlas (strip_modes=%s)" % str(strip_modes))
			return
		_synthesized_tile_set = synthesized_strip
		return

	# AUTO + explicit ONE..FIVE path (single-strip output atlas).
	# WR-02 FIX: resolve AUTO/AUTO_STRIP → concrete mode BEFORE building the cache
	# signature so AUTO drift (e.g., user mutates atlas to add a 5th tile while AUTO is
	# active) re-triggers synthesis. The prior order built the signature from the raw
	# (unresolved) tile_count, so AUTO + 4-tile atlas and AUTO + 5-tile atlas hashed
	# identically and the second paint reused the stale FOUR-mode synthesized TileSet.
	var mode := penta_tile_count
	if penta.has_method("resolve_active_mode") and tile_set != null and source_id >= 0:
		var active_mode_enum = penta.call("resolve_active_mode", tile_set, source_id)
		mode = int(active_mode_enum)
	var sig := hash([
		penta.get_instance_id(),
		penta_axis,
		penta_tile_count,
		source_tile_set_id,
		source_id,
		mode,                              # WR-02: resolved mode in signature catches AUTO drift
	])
	if sig == _synthesis_signature and _synthesized_tile_set != null:
		return   # cache hit — PENTA-SYNTH-06 deterministic re-run guard
	_synthesis_signature = sig
	_synthesized_tile_set = null
	if tile_set == null or source_id < 0:
		return   # no source — Phase 4 fallback path (PREVIEW-03/04) handles null tile_set
	if mode < 1 or mode > 5:
		# Unresolved AUTO with axis_size 0 or 6+. NO stub fallback — caller renders nothing.
		return
	var result: Dictionary = _PentaTileSynthesis.synthesize_strip(tile_set, source_id, penta_axis, 0, mode)
	if result.is_empty() or not result.has("slots"):
		push_warning("PentaTileMapLayer: synthesize_strip returned no slots for mode=%d axis=%d" % [mode, penta_axis])
		return
	var synthesized: TileSet = _PentaTileSynthesis.build_tile_set_from_synthesis(result)
	if synthesized == null:
		push_warning("PentaTileMapLayer: build_tile_set_from_synthesis returned null for mode=%d" % mode)
		return
	_synthesized_tile_set = synthesized


# Receives Resource.changed from layout via the disconnect-before-reconnect pattern.
# Invalidates the synthesis cache so next rebuild re-runs synthesize_strip with fresh inputs.
# Coalesces via _queue_rebuild's call_deferred — multiple emissions per frame collapse to one rebuild.
func _on_layout_changed() -> void:
	# PENTA-SYNTH-06: invalidate synthesis cache on any layout change.
	_synthesized_tile_set = null
	_synthesis_signature = 0
	_queue_rebuild()
	update_configuration_warnings()                                                # H-3 trigger


# PENTA-SYNTH-08: Inspector warning panel hook (@tool). Forwards layout-side warnings
# to the layer's inspector panel so they are visible directly on the node.
# H-3: this is the OVERRIDE (returns the warning strings). update_configuration_warnings()
# is the TRIGGER (asks Godot to refresh); it is called from the layout setter and
# _on_layout_changed, not here.
# Forward-type note: PentaTileLayoutPenta is resolved dynamically via needs_synthesis() +
# has_method("get_configuration_warnings_for") to avoid a class-level forward reference
# (same pattern as _ensure_synthesized_tile_set in Wave 2 Task 2.3).
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if layout == null:
		return warnings   # null layout is a valid intermediate state (renders nothing); no warning
	if tile_set == null:
		return warnings   # tile_set null is also valid (Phase 4 wires fallback path)
	var source_id := _resolve_source_id()
	if source_id < 0:
		return warnings
	if layout.needs_synthesis() and layout.has_method("get_configuration_warnings_for"):
		var result = layout.call("get_configuration_warnings_for", tile_set, source_id)
		if result is PackedStringArray:
			warnings.append_array(result)
	return warnings
