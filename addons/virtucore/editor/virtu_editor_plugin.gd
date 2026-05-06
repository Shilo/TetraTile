@tool
class_name VirtuEditorPlugin extends EditorPlugin

const _ADDONS_PATH := "res://addons/"
static var _processing_sub_plugins := false


func _enter_tree() -> void: enter_tree.call_deferred()
func _ready() -> void: ready.call_deferred()
func enter_tree() -> void: pass
func ready() -> void: pass


func _enable_plugin() -> void:
	if not _processing_sub_plugins:
		set_sub_plugins_enabled(true)


func _disable_plugin() -> void:
	if not _processing_sub_plugins:
		set_sub_plugins_enabled(false)


func set_sub_plugins_enabled(enabled: bool) -> void:
	var script: Script = get_script()
	if script == null:
		push_error("VirtuEditorPlugin: plugin script is missing.")
		return

	var plugin_dir := script.resource_path.get_base_dir()
	if not plugin_dir.begins_with(_ADDONS_PATH):
		push_error("VirtuEditorPlugin: %s is not under %s." % [plugin_dir, _ADDONS_PATH])
		return

	_processing_sub_plugins = true

	var sub_plugin_ids: Array[String] = []
	var queue: Array[String] = [plugin_dir]
	while not queue.is_empty():
		var dir_path: String = queue.pop_front()
		var dir_access := DirAccess.open(dir_path)
		if dir_access == null:
			continue
		for sub_dir in dir_access.get_directories():
			var sub_path := dir_path.path_join(sub_dir)
			queue.append(sub_path)
			if dir_access.file_exists(sub_dir.path_join("plugin.cfg")):
				sub_plugin_ids.append(sub_path.trim_prefix(_ADDONS_PATH))

	if enabled:
		sub_plugin_ids.reverse()

	for sub_id in sub_plugin_ids:
		if EditorInterface.is_plugin_enabled(sub_id) != enabled:
			EditorInterface.set_plugin_enabled(sub_id, enabled)

	_processing_sub_plugins = false
