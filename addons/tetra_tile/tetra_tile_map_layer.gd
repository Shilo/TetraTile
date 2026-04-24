@tool
@icon("res://icon.svg")
class_name TetraTileMapLayer
extends TileMapLayer

enum AtlasLayout { HORIZONTAL, VERTICAL }

const _PRIMARY_LAYER_NAME := "_TetraTileVisual"
const _OVERLAY_LAYER_NAME := "_TetraTileDiagonalOverlay"

const _FILL := 0
const _INNER_CORNER := 1
const _BORDER := 2
const _OUTER_CORNER := 3

const _ROTATE_0 := 0
const _ROTATE_90 := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H
const _ROTATE_180 := TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
const _ROTATE_270 := TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_V

const _TL := Vector2i(-1, -1)
const _TR := Vector2i(0, -1)
const _BL := Vector2i(-1, 0)
const _BR := Vector2i(0, 0)

@export var atlas_source_id: int = -1:
	set(value):
		atlas_source_id = value
		_queue_rebuild()

@export var atlas_layout: AtlasLayout = AtlasLayout.HORIZONTAL:
	set(value):
		atlas_layout = value
		_queue_rebuild()

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
var _overlay_layer: TileMapLayer


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

	var affected: Dictionary = {}
	for logic_cell: Vector2i in coords:
		_mark_affected_display_cells(affected, logic_cell)

	for display_cell: Vector2i in affected.keys():
		_paint_display_cell(display_cell)


func rebuild() -> void:
	_ensure_visual_layers()
	_clear_visual_layers()
	if tile_set == null:
		return

	_sync_visual_layers()
	var affected: Dictionary = {}
	for logic_cell: Vector2i in get_used_cells():
		_mark_affected_display_cells(affected, logic_cell)

	for display_cell: Vector2i in affected.keys():
		_paint_display_cell(display_cell)


func _mark_affected_display_cells(affected: Dictionary, logic_cell: Vector2i) -> void:
	affected[logic_cell] = true
	affected[logic_cell + Vector2i.RIGHT] = true
	affected[logic_cell + Vector2i.DOWN] = true
	affected[logic_cell + Vector2i(1, 1)] = true


func _paint_display_cell(display_cell: Vector2i) -> void:
	_primary_layer.erase_cell(display_cell)
	_overlay_layer.erase_cell(display_cell)

	var source := _resolve_source_id()
	if source == -1:
		return

	match _mask_at(display_cell):
		0:
			return
		1:
			_set_visual_cell(_primary_layer, display_cell, source, _OUTER_CORNER, _ROTATE_90)
		2:
			_set_visual_cell(_primary_layer, display_cell, source, _OUTER_CORNER, _ROTATE_180)
		3:
			_set_visual_cell(_primary_layer, display_cell, source, _BORDER, _ROTATE_180)
		4:
			_set_visual_cell(_primary_layer, display_cell, source, _OUTER_CORNER, _ROTATE_0)
		5:
			_set_visual_cell(_primary_layer, display_cell, source, _BORDER, _ROTATE_90)
		6:
			# Diagonal masks are two disconnected quadrants, so compose them with the overlay layer.
			_set_visual_cell(_primary_layer, display_cell, source, _OUTER_CORNER, _ROTATE_180)
			_set_visual_cell(_overlay_layer, display_cell, source, _OUTER_CORNER, _ROTATE_0)
		7:
			_set_visual_cell(_primary_layer, display_cell, source, _INNER_CORNER, _ROTATE_90)
		8:
			_set_visual_cell(_primary_layer, display_cell, source, _OUTER_CORNER, _ROTATE_270)
		9:
			# Diagonal masks are two disconnected quadrants, so compose them with the overlay layer.
			_set_visual_cell(_primary_layer, display_cell, source, _OUTER_CORNER, _ROTATE_90)
			_set_visual_cell(_overlay_layer, display_cell, source, _OUTER_CORNER, _ROTATE_270)
		10:
			_set_visual_cell(_primary_layer, display_cell, source, _BORDER, _ROTATE_270)
		11:
			_set_visual_cell(_primary_layer, display_cell, source, _INNER_CORNER, _ROTATE_180)
		12:
			_set_visual_cell(_primary_layer, display_cell, source, _BORDER, _ROTATE_0)
		13:
			_set_visual_cell(_primary_layer, display_cell, source, _INNER_CORNER, _ROTATE_0)
		14:
			_set_visual_cell(_primary_layer, display_cell, source, _INNER_CORNER, _ROTATE_270)
		15:
			_set_visual_cell(_primary_layer, display_cell, source, _FILL, _ROTATE_0)


func _mask_at(display_cell: Vector2i) -> int:
	var mask := 0
	if _has_logic_cell(display_cell + _TL):
		mask |= 1
	if _has_logic_cell(display_cell + _TR):
		mask |= 2
	if _has_logic_cell(display_cell + _BL):
		mask |= 4
	if _has_logic_cell(display_cell + _BR):
		mask |= 8
	return mask


func _has_logic_cell(logic_cell: Vector2i) -> bool:
	return get_cell_source_id(logic_cell) != -1


func _set_visual_cell(
		layer: TileMapLayer,
		display_cell: Vector2i,
		source: int,
		tile_index: int,
		transform: int,
) -> void:
	layer.set_cell(display_cell, source, _atlas_coords(tile_index), transform)


func _atlas_coords(tile_index: int) -> Vector2i:
	if atlas_layout == AtlasLayout.VERTICAL:
		return Vector2i(0, tile_index)
	return Vector2i(tile_index, 0)


func _resolve_source_id() -> int:
	if tile_set == null:
		return -1
	if atlas_source_id >= 0:
		return atlas_source_id
	if tile_set.get_source_count() == 0:
		return -1
	return tile_set.get_source_id(0)


func _ensure_visual_layers() -> void:
	if _primary_layer == null or not is_instance_valid(_primary_layer):
		_primary_layer = _get_or_create_visual_layer(_PRIMARY_LAYER_NAME)
	if _overlay_layer == null or not is_instance_valid(_overlay_layer):
		_overlay_layer = _get_or_create_visual_layer(_OVERLAY_LAYER_NAME)
	_sync_visual_layers()


func _get_or_create_visual_layer(layer_name: StringName) -> TileMapLayer:
	var existing := get_node_or_null(NodePath(layer_name))
	if existing is TileMapLayer:
		return existing

	var layer := TileMapLayer.new()
	layer.name = layer_name
	add_child(layer, false, Node.INTERNAL_MODE_FRONT)
	return layer


func _sync_visual_layers() -> void:
	_apply_logic_collision()
	for layer: TileMapLayer in [_primary_layer, _overlay_layer]:
		if layer == null or not is_instance_valid(layer):
			continue
		layer.tile_set = tile_set
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


func _visual_layer_offset() -> Vector2:
	if tile_set == null:
		return Vector2.ZERO
	return Vector2(tile_set.tile_size) * -0.5


func _clear_visual_layers() -> void:
	for layer: TileMapLayer in [_primary_layer, _overlay_layer]:
		if layer != null and is_instance_valid(layer):
			layer.clear()


func _apply_logic_layer_opacity() -> void:
	var color := self_modulate
	color.a = logic_layer_opacity
	self_modulate = color


func _apply_logic_collision() -> void:
	collision_enabled = logic_collision_enabled


func _queue_rebuild() -> void:
	if is_inside_tree():
		rebuild.call_deferred()
