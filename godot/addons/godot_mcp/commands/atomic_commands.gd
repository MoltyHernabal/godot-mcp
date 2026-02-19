@tool
extends MCPBaseCommand
class_name MCPAtomic_Commands

# Fix #4: Tooling Polling — Atomic operations and frame sync
var _operation_mutex := Mutex.new()
var _pending_operations := {}


func get_commands() -> Dictionary:
	return {
		"synchronize": synchronize_command,
		"atomic_find_and_get": atomic_find_and_get_command,
		"atomic_update_and_get": atomic_update_and_get_command
	}


# Frame synchronization
func synchronize_command(params: Dictionary) -> Dictionary:
	var wait_for_physics: bool = params.get("wait_for_physics", true)
	var wait_for_frames: int = params.get("wait_for_frames", 2)

	if wait_for_physics:
		await Engine.get_main_loop().physics_frame

	for i in range(wait_for_frames):
		await Engine.get_main_loop().process_frame

	return _success({
		"synced": true,
		"physics_frame": Engine.get_physics_frames(),
		"process_frame": Engine.get_process_frames(),
		"timestamp": Time.get_ticks_msec()
	})


# Atomic operations
func atomic_find_and_get_command(params: Dictionary) -> Dictionary:
	var root_path: String = params.get("root_path", "")
	var name_pattern: String = params.get("name_pattern", "")

	if name_pattern.is_empty():
		return _error("INVALID_PARAMS", "name_pattern is required")

	# Start atomic operation
	var op_id := _start_atomic_operation("find_get")

	# Find nodes
	var find_result := find_nodes({ "name_pattern": name_pattern, "root_path": root_path })

	# Get properties for all found nodes
	var get_result := {}
	if find_result.status == "success":
		var matches := find_result.result.matches

		for match_info in matches:
			var node_path := match_info.path
			var node := _get_node(node_path)

			if node:
				var props := get_node_properties({ "node_path": node_path })

				if props.status == "success":
					get_result[node_path] = props.result.properties

	# End atomic operation
	_end_atomic_operation(op_id, { "find": find_result.result, "get": get_result })

	return _success({
		"find": find_result.result,
		"get": get_result
	})


func atomic_update_and_get_command(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var properties: Dictionary = params.get("properties", {})

	if node_path.is_empty():
		return _error("INVALID_PARAMS", "node_path is required")
	if properties.is_empty():
		return _error("INVALID_PARAMS", "properties is required")

	# Start atomic operation
	var op_id := _start_atomic_operation("update_get")

	# Get properties before update
	var before := get_node_properties({ "node_path": node_path })

	# Update node
	var update_result := update_node({ "node_path": node_path, "properties": properties })

	# Get properties after update
	var after := get_node_properties({ "node_path": node_path })

	# End atomic operation
	_end_atomic_operation(op_id, { "before": before.result, "update": update_result.result, "after": after.result })

	return _success({
		"before": before.result,
		"update": update_result.result,
		"after": after.result
	})


# Internal helpers
func _start_atomic_operation(operation_id: String) -> Dictionary:
	_operation_mutex.lock()
	_pending_operations[operation_id] = {
		"started_at": Time.get_ticks_msec(),
		"steps": []
	}
	_operation_mutex.unlock()

	return { "started": operation_id }


func _end_atomic_operation(operation_id: String, result: Dictionary) -> Dictionary:
	_operation_mutex.lock()
	if _pending_operations.has(operation_id):
		_pending_operations[operation_id]["completed"] = true
		_pending_operations[operation_id]["result"] = result
		_pending_operations[operation_id]["completed_at"] = Time.get_ticks_msec()
	_operation_mutex.unlock()

	return { "completed": operation_id }


func find_nodes(params: Dictionary) -> Dictionary:
	var name_pattern: String = params.get("name_pattern", "")
	var root_path: String = params.get("root_path", "")

	var scene_root := EditorInterface.get_edited_scene_root()
	var search_root: Node = scene_root

	if not root_path.is_empty():
		search_root = _get_node(root_path)
		if not search_root:
			return _error("NODE_NOT_FOUND", "Root node not found")

	var matches: Array = []
	_find_recursive(search_root, scene_root, name_pattern, "", matches)

	return _success({ "matches": matches, "count": matches.size() })


func get_node_properties(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		return _error("INVALID_PARAMS", "node_path is required")

	var node := _get_node(node_path)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found")

	var properties := {}
	for prop in node.get_property_list():
		var name: String = prop["name"]
		if name.begins_with("_") or prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			if prop["usage"] & PROPERTY_USAGE_EDITOR == 0:
				continue

		var value = node.get(name)
		properties[name] = _serialize_value(value)

	return _success({ "properties": properties })


func update_node(params: Dictionary) -> Dictionary:
	var node_path: String = params.get("node_path", "")
	var properties: Dictionary = params.get("properties", {})

	if node_path.is_empty():
		return _error("INVALID_PARAMS", "node_path is required")
	if properties.is_empty():
		return _error("INVALID_PARAMS", "properties is required")

	var node := _get_node(node_path)
	if not node:
		return _error("NODE_NOT_FOUND", "Node not found")

	for key in properties:
		if key in node:
			var deserialized := MCPUtils.deserialize_value(properties[key])
			node.set(key, deserialized)

	return _success({})


func _find_recursive(node: Node, scene_root: Node, name_pattern: String, type_filter: String, results: Array) -> void:
	var name_matches := name_pattern.is_empty() or node.name.matchn(name_pattern)
	var type_matches := type_filter.is_empty() or node.is_class(type_filter)

	if name_matches and type_matches:
		var relative_path := scene_root.get_path_to(node)
		var usable_path := "/root/" + scene_root.name
		if relative_path != NodePath("."):
			usable_path += "/" + str(relative_path)

		results.append({
			"path": usable_path,
			"type": node.get_class()
		})

	for child in node.get_children():
		_find_recursive(child, scene_root, name_pattern, type_filter, results)


func _serialize_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR2I:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR3:
			return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_VECTOR3I:
			return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_COLOR:
			return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_OBJECT:
			if value == null:
				return null
			if value is Resource:
				return value.resource_path if value.resource_path else str(value)
			return str(value)
		_:
			return value
