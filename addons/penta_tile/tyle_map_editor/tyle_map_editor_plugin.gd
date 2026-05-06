@tool
extends VirtuEditorPlugin


var _panel: Control
var _button: Button
var _overlay: Control


const PANEL_SCENE_FILE := "tyle_map_editor_panel.tscn"
const DEFAULT_INPUT_BINDINGS := {
	"tyle_select": KEY_S,
	"tyle_draw": KEY_D,
	"tyle_line": KEY_L,
	"tyle_rect": KEY_R,
	"tyle_fill": KEY_B,
	"tyle_pick": KEY_P,
	"tyle_erase": KEY_E,
}

func _enter_tree() -> void:
	_setup_input_actions()
	var panel_scene := _load_panel_scene()
	if panel_scene == null:
		push_error("TyleMapEditorPlugin: failed to load panel scene from addon directory.")
		return
	_panel = panel_scene.instantiate()
	_panel.plugin = self
	_button = add_control_to_bottom_panel(_panel, "Tyle")
	_button.visible = false

	_panel.undo_manager = get_undo_redo()

	_panel.update_overlay.connect(update_overlays)
	_panel.close_requested.connect(_on_panel_close_requested)

	var main_screen := get_editor_interface().get_editor_main_screen()
	main_screen.mouse_exited.connect(_panel.canvas_mouse_exited)

	_button.toggled.connect(func(v: bool):
		if v:
			_panel.about_to_be_visible()
	)


func _load_panel_scene() -> PackedScene:
	var script := get_script() as Script
	if script == null or script.resource_path.is_empty():
		return null
	var scene_path := script.resource_path.get_base_dir().path_join(PANEL_SCENE_FILE)
	return load(scene_path) as PackedScene


func _exit_tree() -> void:
	_teardown_input_actions()
	if _panel:
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null
	_button = null


func _setup_input_actions() -> void:
	for action: String in DEFAULT_INPUT_BINDINGS:
		var path: String = "input/" + action
		if not ProjectSettings.has_setting(path):
			var ev := InputEventKey.new()
			ev.keycode = DEFAULT_INPUT_BINDINGS[action]
			ev.command_or_control_autoremap = false
			ProjectSettings.set_setting(path, {"deadzone": 0.5, "events": [ev]})
			InputMap.add_action(action)
			InputMap.action_add_event(action, ev)


func _teardown_input_actions() -> void:
	for action: String in DEFAULT_INPUT_BINDINGS:
		var path: String = "input/" + action
		if ProjectSettings.has_setting(path):
			ProjectSettings.clear(path)
		if InputMap.has_action(action):
			InputMap.erase_action(action)


func _handles(object: Object) -> bool:
	var result := object is TileMapLayer
	return result


func _edit(object: Object) -> void:
	if object is TileMapLayer:
		_panel.tilemap = object
		if _button and _button.button_pressed:
			_re_show.call_deferred()


func _make_visible(visible: bool) -> void:
	if visible and _button:
		_button.visible = true
		_button.button_pressed = true
		make_bottom_panel_item_visible(_panel)
		_re_show.call_deferred()
	elif _button:
		_button.visible = false
		_button.button_pressed = false


func _re_show() -> void:
	if _button and _button.button_pressed:
		make_bottom_panel_item_visible(_panel)
		_panel.about_to_be_visible()
		_re_show2.call_deferred()

func _re_show2() -> void:
	if _button and _button.button_pressed:
		make_bottom_panel_item_visible(_panel)
		_panel.about_to_be_visible()


func _clear() -> void:
	_panel.tilemap = null


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not _panel.is_visible_in_tree():
		return false
	return _panel.canvas_input(event)


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	_overlay = overlay
	if _panel.is_visible_in_tree():
		_panel.canvas_draw(overlay)


func _queue_overlay_redraw() -> void:
	if _overlay:
		_overlay.queue_redraw()


func _on_panel_close_requested() -> void:
	if _button:
		_button.button_pressed = false
	hide_bottom_panel()
