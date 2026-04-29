@tool
## Abstract base for all PentaTile layout topologies.
##
## Subclasses implement compute_mask + mask_to_atlas + is_dual_grid. Each layout
## owns its mask topology (which neighbors / corners / edges feed bits) and its
## slot resolution (mask -> AtlasSlot).
##
## See:
##   - .planning/research/layouts/MASK_UNIFICATION.md §3 (Approach B selection)
##   - .planning/research/layouts/TEMPLATE_CONVENTIONS.md §5 (dual-grid declaration)
##   - .planning/research/PITFALLS.md §3 (_pack_alternative recipe)
##
## @experimental
class_name PentaTileLayout
extends Resource

## Single PNG that serves as both the inspector preview and the source pixels
## for [method get_fallback_tile_set]. Renamed from Phase 1's
## [code]template_image[/code] per LAYOUT-03.
@export var bitmask_template: Texture2D:
	set(value):
		if bitmask_template == value:
			return
		bitmask_template = value
		emit_changed()                                                                # propagates to PentaTileMapLayer._on_layout_changed which refreshes auto-filled tile_set fallbacks

## Multiline description of the layout's mask topology, atlas grid shape, and
## intended use case. Surfaces in inspector help.
@export_multiline var description: String = ""


# Auto-fill seam for `bitmask_template`. Subclasses with a single bundled preview
# PNG (DualGrid16, Wang2Edge, Wang2Corner, Min3x3) override this to return the
# `res://...` path; the base `_init` loads it into `bitmask_template` if the
# property is still null (so users see the inspector preview the moment they
# instantiate the resource, AND the value serializes into .tres on save).
# Returns "" when the layout has no single canonical PNG (e.g. Penta which
# has 10 PNGs across axis × mode and uses its own _refresh_preset_bitmask).
func _default_bitmask_template_path() -> String:
	return ""


func _init() -> void:
	if bitmask_template != null:
		return                                                                        # user-supplied or already serialized — don't overwrite
	var path := _default_bitmask_template_path()
	if path.is_empty():
		return
	var tex := load(path) as Texture2D
	if tex != null:
		bitmask_template = tex


## Compute the layout-specific mask for [param _coord] using [param _sample_fn]
## as the neighbor-presence query.
##
## Returns the mask integer the layout's [method mask_to_atlas] consumes.
## Subclasses must override this abstract base implementation.
func compute_mask(_coord: Vector2i, _sample_fn: Callable) -> int:
	push_error("PentaTileLayout.compute_mask is abstract; subclass must override.")
	return 0


## Convert [param _mask] into the [PentaTileAtlasSlot] to paint.
##
## [param _strip_index] selects which Y-row of the synthesized atlas to dispatch
## to (default 0 = single-strip atlas, matching AUTO/explicit modes for Penta
## and all non-Penta layouts). Subclasses must override this abstract base
## implementation.
# `strip_index` selects which Y-row of the synthesized atlas to dispatch to
# (default 0 = single-strip atlas, matches AUTO/explicit modes for Penta and
# all non-Penta layouts). PentaTileLayoutPenta in AUTO_STRIP mode passes a
# resolved strip_index from `resolve_display_strip` so per-strip dispatch lands
# at Vector2i(slot, strip_index). Layouts that don't use multi-strip atlases
# inherit the default 0 and ignore the parameter.
func mask_to_atlas(_mask: int, _strip_index: int = 0) -> PentaTileAtlasSlot:
	push_error("PentaTileLayout.mask_to_atlas is abstract; subclass must override.")
	return null


## Return [code]true[/code] if this layout paints at the dual-grid half-cell
## offset, or [code]false[/code] if it paints directly at the logic cell. See
## [b]Critical Pitfall #8[/b] for the single-grid logic-painted gate.
func is_dual_grid() -> bool:
	push_error("PentaTileLayout.is_dual_grid is abstract; subclass must override.")
	return true


## Resolve which synthesized strip [param _coord] should dispatch to.
##
## [param _sample_atlas_fn] returns source atlas coords for a logic cell, or
## [code]Vector2i(-1, -1)[/code] when empty. Base layouts use a single strip and
## always return 0.
# Resolves which strip a painted display cell should dispatch to. Default 0
# (single-strip atlas). Penta in AUTO_STRIP overrides to pick the strip from
# the first non-empty TL/TR/BL/BR neighbor's source-atlas coords (per
# Interpretation A: HORIZONTAL → coords.y, VERTICAL → coords.x).
#
# `sample_atlas_fn(coord: Vector2i) -> Vector2i` returns the source atlas_coords
# of the logic cell at `coord`, or Vector2i(-1, -1) if empty.
func resolve_display_strip(_coord: Vector2i, _sample_atlas_fn: Callable) -> int:
	return 0


## Return [code]true[/code] when a layout needs runtime synthesis before visual
## dispatch. Only [PentaTileLayoutPenta] does this in v0.2.
# Returns true if this layout needs synthesis (i.e. is a PentaTileLayoutPenta instance).
# Default false. PentaTileLayoutPenta overrides to return true in Wave 3.
# Used by PentaTileMapLayer._ensure_visual_layers to branch without a forward type reference.
func needs_synthesis() -> bool:
	return false


## Combine alt-id and [code]TRANSFORM_FLIP_*[/code] flags via bitwise OR.
##
## Asserts [param alt_id] < 4096 so transform flags cannot collide with the
## low-bit alternative id storage; see [b]Critical Pitfall #1[/b].
# PITFALLS.md §3 + LAYOUT-05: alt-id and TRANSFORM_FLIP_* flags share one int.
# `alternative_tile` low bits go below 4096; transform flags are >= 4096.
# Always OR via this helper; assert prevents silent collision.
func _pack_alternative(alt_id: int, transform_flags: int) -> int:
	assert(alt_id < 4096, "alternative_tile alt_id must be < 4096; flags share the int")
	return alt_id | transform_flags


# Subclasses override to declare their fallback atlas grid (cols × rows of tiles).
# The base get_fallback_tile_set uses this + bitmask_template to build the TileSet.
# Returns Vector2i.ZERO for layouts without a single canonical grid (caller treats
# as "no fallback available" and renders nothing).
func _fallback_atlas_grid_size() -> Vector2i:
	return Vector2i.ZERO


## Return a runtime [Class TileSet] built from [member bitmask_template].
##
## Consumed by [PentaTileMapLayer] when [member PentaTileMapLayer.tile_set] is
## [code]null[/code] (PREVIEW-03). The default implementation builds one atlas
## source from the bundled PNG; subclasses may override when their fallback grid
## is not static.
# LAYOUT-06 / PREVIEW-02: build a fresh TileSet from `bitmask_template` on each call.
# No cache — bitmask_template can change at runtime (inspector drag, script assign)
# and PentaTileMapLayer's auto-fill flow rebuilds the tile_set on layout.changed.
# Tile size derived from bitmask_template dimensions / grid size.
# Consumer (PentaTileMapLayer.layout setter + _on_layout_changed) calls this to
# auto-fill / refresh tile_set when no user-supplied tile_set is bound.
func get_fallback_tile_set() -> TileSet:
	if bitmask_template == null:
		return null
	var grid := _fallback_atlas_grid_size()
	if grid.x <= 0 or grid.y <= 0:
		return null
	var tile_w: int = bitmask_template.get_width() / grid.x
	var tile_h: int = bitmask_template.get_height() / grid.y
	if tile_w <= 0 or tile_h <= 0:
		return null
	var tile_size := Vector2i(tile_w, tile_h)
	var ts := TileSet.new()
	var src := TileSetAtlasSource.new()
	src.texture = bitmask_template
	src.texture_region_size = tile_size
	for y in range(grid.y):
		for x in range(grid.x):
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	ts.tile_size = tile_size
	return ts
