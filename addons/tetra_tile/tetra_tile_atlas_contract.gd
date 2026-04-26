@tool
## The TetraTile atlas contract: a typed Resource that bundles
## (a) a layout strategy (TetraTileLayout subclass), (b) a version
## marker for forward compatibility, and (c) a variation_seed used
## by Phase 3.5 layouts that have multi-cell mask resolution.
##
## Setter discipline (D-08, PITFALLS §5):
##   - idempotence guard FIRST (so `obj.layout = obj.layout` is a no-op)
##   - disconnect OLD before assign
##   - assign
##   - connect NEW after assign
##   - emit_changed() last
##
## Back-reference: when `layout` is assigned, this contract calls
## `layout._set_contract(self)` so Phase 3.5's PixelLab variation pick
## can read `_contract.get_ref().variation_seed`.
class_name TetraTileAtlasContract
extends Resource

@export var version: int = 1
@export var layout: TetraTileLayout:
	set(value):
		if layout == value:
			return                                                                  # idempotence (D-08, PITFALLS §5)
		if layout != null:
			if layout.changed.is_connected(_on_layout_changed):
				layout.changed.disconnect(_on_layout_changed)
			layout._set_contract(null)                                              # clear back-ref on old
		layout = value
		if layout != null:
			layout.changed.connect(_on_layout_changed)
			layout._set_contract(self)                                              # set back-ref on new
		emit_changed()                                                              # propagates to TetraTileMapLayer._on_contract_changed
@export var variation_seed: int = 0


func _on_layout_changed() -> void:
	# Bubble layout's `changed` up; receiver (TetraTileMapLayer) coalesces via _queue_rebuild.
	# Do NOT call `layout = layout` or any setter here — signal storm risk per PITFALLS §5.
	emit_changed()
