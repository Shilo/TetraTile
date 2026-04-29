extends Node2D

## Demo runtime painter — drag-paint across a grid of PentaTileMapLayer
## instances. Resolves the cursor to whichever instance's footprint
## contains it; left-click paints, right-click erases. Kept generic so
## any number of PentaTileMapLayer children works (1 to N).

@export var paint_source_id: int = 0
@export var paint_atlas_coords: Vector2i = Vector2i(0, 0)

## Generous cursor margin (in tile units) added to each layer's used_rect.
## Lets the user paint into empty layers (used_rect is empty until first
## paint, so we need a non-zero margin). Discretion: 32 cells × 32 px =
## 1024 px — covers the per-instance pre-allocated footprint at 32px tiles.
const _HOVER_MARGIN_CELLS: int = 32

var _active_button := MOUSE_BUTTON_NONE
var _last_hit_layer: PentaTileMapLayer = null
var _last_cell := Vector2i(1073741823, 1073741823)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _handle_mouse_button(mouse_event: InputEventMouseButton) -> void:
	if mouse_event.button_index != MOUSE_BUTTON_LEFT and mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return

	if mouse_event.pressed:
		_active_button = mouse_event.button_index
		_last_hit_layer = null
		_last_cell = Vector2i(1073741823, 1073741823)
		_apply_at_event_position(mouse_event.position, _active_button)
	elif mouse_event.button_index == _active_button:
		_active_button = MOUSE_BUTTON_NONE
		_last_hit_layer = null
		_last_cell = Vector2i(1073741823, 1073741823)


func _handle_mouse_motion(mouse_event: InputEventMouseMotion) -> void:
	if _active_button == MOUSE_BUTTON_NONE:
		return
	_apply_at_event_position(mouse_event.position, _active_button)


func _apply_at_event_position(event_position: Vector2, button: MouseButton) -> void:
	var canvas_position := get_canvas_transform().affine_inverse() * event_position
	var hit_layer := _resolve_hit_layer(canvas_position)
	if hit_layer == null:
		return

	var cell := hit_layer.local_to_map(hit_layer.to_local(canvas_position))
	if hit_layer == _last_hit_layer and cell == _last_cell:
		return
	_last_hit_layer = hit_layer
	_last_cell = cell

	_apply_cell(hit_layer, cell, button)


## Walk children for the PentaTileMapLayer whose used_rect (in cell space,
## grown by _HOVER_MARGIN_CELLS) contains the cursor. Returns the first
## match in scene-tree order. Returns null if no instance matches.
func _resolve_hit_layer(canvas_position: Vector2) -> PentaTileMapLayer:
	for child in get_children():
		if not child is PentaTileMapLayer:
			continue
		var layer := child as PentaTileMapLayer
		var local := layer.to_local(canvas_position)
		var cell := layer.local_to_map(local)
		var rect := layer.get_used_rect().grow(_HOVER_MARGIN_CELLS)
		if rect.has_point(cell):
			return layer
	return null


func _apply_cell(layer: PentaTileMapLayer, cell: Vector2i, button: MouseButton) -> void:
	match button:
		MOUSE_BUTTON_LEFT:
			layer.set_cell(cell, paint_source_id, paint_atlas_coords)
		MOUSE_BUTTON_RIGHT:
			layer.erase_cell(cell)
