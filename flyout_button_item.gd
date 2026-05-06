@tool
extends Resource
class_name FlyoutButtonItem

@export var title: StringName
@export var icon: Texture2D
@export var editor_icon: StringName
@export var tooltip := ""
@export var shortcut: Shortcut
@export var shortcut_in_tooltip: bool = true
