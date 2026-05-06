@tool
extends Button
class_name FlyoutButton

signal item_selected(index: int)

enum PopupDirection { RIGHT, LEFT, UP, DOWN }
enum ContentDirection { HORIZONTAL, VERTICAL }

const EDITOR_ICONS_TYPE := &"EditorIcons"

@export var popup_direction := PopupDirection.DOWN
@export var content_direction := ContentDirection.VERTICAL

@export var options: Array[FlyoutButtonItem] = []:
	set(value):
		options = value
		if selected_index >= options.size():
			selected_index = max(options.size() - 1, 0)
		_refresh_selected()

@export var selected_index := 0:
	set(value):
		selected_index = max(value, 0)
		_refresh_selected()

var selected_title: StringName:
	get:
		return get_selected_title()

var _popup: PopupPanel
var _content: BoxContainer
var _popup_buttons: Array[Button] = []


func _init() -> void:
	flat = true
	toggle_mode = true
	text = ""
	alignment = HORIZONTAL_ALIGNMENT_CENTER


func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	_refresh_selected()


func _exit_tree() -> void:
	_free_popup()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event is InputEventKey and not event.pressed:
		return
	if disabled or not is_visible_in_tree():
		return

	for index in range(options.size()):
		var item := options[index]
		if item != null and item.shortcut != null and item.shortcut.matches_event(event):
			select_index(index)
			get_viewport().set_input_as_handled()
			return


func _process(_delta: float) -> void:
	if is_popup_open():
		_position_popup()
	else:
		set_process(false)


func open_popup() -> void:
	if options.is_empty():
		return

	if _popup == null:
		_build_popup()
	else:
		_rebuild_popup_items()

	_popup.popup()
	_popup.reset_size()
	_position_popup()
	set_process(true)


func close_popup() -> void:
	if is_popup_open():
		_popup.hide()


func is_popup_open() -> bool:
	return is_instance_valid(_popup) and _popup.visible


func select_index(index: int) -> void:
	if index < 0 or index >= options.size():
		return

	selected_index = index
	button_pressed = true
	_refresh_popup_button_states()
	item_selected.emit(index)
	close_popup()


func get_selected_item() -> FlyoutButtonItem:
	if selected_index < 0 or selected_index >= options.size():
		return null
	return options[selected_index]


func get_selected_title() -> StringName:
	var item := get_selected_item()
	if item == null:
		return &""
	return item.title


func _on_pressed() -> void:
	button_pressed = true
	if is_popup_open():
		close_popup()
	else:
		open_popup()


func _refresh_selected() -> void:
	if not is_inside_tree():
		return

	var item := get_selected_item()
	if item == null:
		icon = null
		text = ""
		tooltip_text = ""
		shortcut = null
		return

	icon = _resolve_icon(item)
	text = "" if icon != null else String(item.title)
	tooltip_text = item.tooltip
	shortcut = item.shortcut
	shortcut_in_tooltip = _get_shortcut_in_tooltip(item)
	_refresh_popup_button_states()


func _build_popup() -> void:
	_free_popup()

	_popup = PopupPanel.new()
	_popup.name = "%sPopup" % name
	_popup.wrap_controls = true
	_popup.exclusive = false
	_popup.transient = true
	_popup.unresizable = true
	_popup.borderless = true
	get_tree().root.add_child(_popup)

	_rebuild_popup_items()


func _rebuild_popup_items() -> void:
	if _popup == null:
		return

	for child in _popup.get_children():
		child.queue_free()
	_popup_buttons.clear()

	if content_direction == ContentDirection.HORIZONTAL:
		_content = HBoxContainer.new()
	else:
		_content = VBoxContainer.new()

	_content.name = "Content"
	_content.add_theme_constant_override(&"separation", 0)
	_popup.add_child(_content)

	for index in range(options.size()):
		var item_button := _make_item_button(index)
		_content.add_child(item_button)
		_popup_buttons.append(item_button)

	_refresh_popup_button_states()


func _make_item_button(index: int) -> Button:
	var item := options[index]
	var item_button := Button.new()
	item_button.name = "Item%d" % index
	item_button.flat = true
	item_button.toggle_mode = true
	item_button.focus_mode = Control.FOCUS_NONE
	item_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item_button.tooltip_text = item.tooltip
	item_button.icon = _resolve_icon(item)
	item_button.text = "" if item_button.icon != null else String(item.title)
	item_button.shortcut = item.shortcut
	item_button.shortcut_in_tooltip = _get_shortcut_in_tooltip(item)
	item_button.pressed.connect(select_index.bind(index))
	return item_button


func _get_shortcut_in_tooltip(item: FlyoutButtonItem) -> bool:
	var value = item.get(&"shortcut_in_tooltip")
	return true if value == null else bool(value)


func _refresh_popup_button_states() -> void:
	for index in range(_popup_buttons.size()):
		_popup_buttons[index].set_pressed_no_signal(index == selected_index)


func _position_popup() -> void:
	if not is_instance_valid(_popup):
		return

	var popup_size := Vector2(_popup.size)
	if popup_size.x <= 0.0 or popup_size.y <= 0.0:
		popup_size = Vector2(_popup.get_contents_minimum_size())

	var button_rect := get_global_rect()
	var viewport_rect := get_viewport_rect()
	var direction := _choose_direction(button_rect, popup_size)
	var popup_position := button_rect.position

	match direction:
		PopupDirection.RIGHT:
			popup_position.x = button_rect.end.x
		PopupDirection.LEFT:
			popup_position.x = button_rect.position.x - popup_size.x
		PopupDirection.UP:
			popup_position.y = button_rect.position.y - popup_size.y
		PopupDirection.DOWN:
			popup_position.y = button_rect.end.y

	if direction == PopupDirection.RIGHT or direction == PopupDirection.LEFT:
		popup_position.y = button_rect.get_center().y - (popup_size.y * 0.5)
	else:
		popup_position.x = button_rect.get_center().x - (popup_size.x * 0.5)

	popup_position.x = clamp(popup_position.x, 0.0, max(0.0, viewport_rect.size.x - popup_size.x))
	popup_position.y = clamp(popup_position.y, 0.0, max(0.0, viewport_rect.size.y - popup_size.y))
	_popup.position = Vector2i(popup_position.round())
	_popup.size = Vector2i(popup_size.ceil())


func _choose_direction(button_rect: Rect2, popup_size: Vector2) -> int:
	if _direction_fits(popup_direction, button_rect, popup_size):
		return popup_direction

	var fallbacks := _fallback_directions(popup_direction)
	for fallback in fallbacks:
		if _direction_fits(fallback, button_rect, popup_size):
			return fallback

	return fallbacks[0] if not fallbacks.is_empty() else popup_direction


func _fallback_directions(preferred: int) -> Array[int]:
	match preferred:
		PopupDirection.DOWN:
			return [PopupDirection.UP, PopupDirection.RIGHT, PopupDirection.LEFT]
		PopupDirection.UP:
			return [PopupDirection.DOWN, PopupDirection.RIGHT, PopupDirection.LEFT]
		PopupDirection.LEFT:
			return [PopupDirection.RIGHT, PopupDirection.DOWN, PopupDirection.UP]
		PopupDirection.RIGHT:
			return [PopupDirection.LEFT, PopupDirection.DOWN, PopupDirection.UP]
	return [PopupDirection.DOWN, PopupDirection.UP, PopupDirection.RIGHT, PopupDirection.LEFT]


func _direction_fits(direction: int, button_rect: Rect2, popup_size: Vector2) -> bool:
	var viewport_size := get_viewport_rect().size
	match direction:
		PopupDirection.RIGHT:
			return button_rect.end.x + popup_size.x <= viewport_size.x
		PopupDirection.LEFT:
			return button_rect.position.x - popup_size.x >= 0.0
		PopupDirection.UP:
			return button_rect.position.y - popup_size.y >= 0.0
		PopupDirection.DOWN:
			return button_rect.end.y + popup_size.y <= viewport_size.y
	return false


func _resolve_icon(item: FlyoutButtonItem) -> Texture2D:
	if item == null:
		return null
	if item.icon != null:
		return item.icon
	if item.editor_icon != &"":
		return _get_editor_icon(item.editor_icon)
	return null


func _get_editor_icon(icon_name: StringName) -> Texture2D:
	if not Engine.is_editor_hint():
		return null
	if not Engine.has_singleton(&"EditorInterface"):
		return null

	var editor_interface := Engine.get_singleton(&"EditorInterface")
	if editor_interface == null:
		return null

	if editor_interface.has_method("get_editor_theme"):
		var editor_theme := editor_interface.call("get_editor_theme") as Theme
		if editor_theme != null and editor_theme.has_icon(icon_name, EDITOR_ICONS_TYPE):
			return editor_theme.get_icon(icon_name, EDITOR_ICONS_TYPE)

	if editor_interface.has_method("get_base_control"):
		var base_control := editor_interface.call("get_base_control") as Control
		if base_control != null and base_control.has_theme_icon(icon_name, EDITOR_ICONS_TYPE):
			return base_control.get_theme_icon(icon_name, EDITOR_ICONS_TYPE)

	return null


func _free_popup() -> void:
	if is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null
	_content = null
	_popup_buttons.clear()
