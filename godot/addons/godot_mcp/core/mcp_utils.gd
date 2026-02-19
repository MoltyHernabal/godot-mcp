@tool
class_name MCPUtils
extends RefCounted

# Path resolution cache for Fix #0: Path Resolution
var _instance_id_cache := {}  # Maps instance_id to path
var _path_to_instance_id := {}  # Maps path to instance_id
var _node_cache := {}
var _cache_time := {}
var _cache_duration := 5.0  # Cache for 5 seconds
var _scene_tree_mutex := Mutex.new()


static func success(result: Dictionary) -> Dictionary:
	return {
		"status": "success",
		"result": result
	}


static func error(code: String, message: String) -> Dictionary:
	return {
		"status": "error",
		"error": {
			"code": code,
			"message": message
		}
	}


static func get_node_from_path(path: String) -> Node:
	var root := EditorInterface.get_edited_scene_root()
	if not root:
		return null

	if path == "/root" or path == "/" or path == str(root.get_path()):
		return root

	if path.begins_with("/root/"):
		var parts := path.split("/")
		if parts.size() >= 3:
			if parts[2] == root.name:
				var relative_path := "/".join(parts.slice(3))
				if relative_path.is_empty():
					return root
				return root.get_node_or_null(relative_path)

	if path.begins_with("/"):
		path = path.substr(1)

	return root.get_node_or_null(path)


# Fix #0: Path Resolution - Dual resolution with caching
static func get_node_with_cache(path_or_id: String) -> Node:
	# First try as path
	var node := get_cached_node(path_or_id)

	# If not found, try as instance ID
	if not node and path_or_id.to_int() > 0:
		var utils := MCPUtils.new()
		if utils._instance_id_cache.has(path_or_id):
			var cached_path = utils._instance_id_cache[path_or_id]
			node = get_cached_node(cached_path)

	return node


static func get_cached_node(path: String) -> Node:
	var utils := MCPUtils.new()
	var now := Time.get_ticks_msec()

	# Check cache
	if utils._node_cache.has(path):
		if now - utils._cache_time[path] < utils._cache_duration * 1000:
			return utils._node_cache[path]

	# Cache miss - fetch fresh
	utils._scene_tree_mutex.lock()
	var node := get_node_from_path(path)
	utils._scene_tree_mutex.unlock()

	# Update cache
	if node:
		utils._node_cache[path] = node
		utils._cache_time[path] = now

		# Map instance ID
		var instance_id := str(node.get_instance_id())
		utils._instance_id_cache[instance_id] = node.get_path()
		utils._path_to_instance_id[node.get_path()] = instance_id

	return node


static func clear_node_cache(path: String = "") -> void:
	var utils := MCPUtils.new()

	if path.is_empty():
		# Clear entire cache
		utils._instance_id_cache.clear()
		utils._path_to_instance_id.clear()
		utils._node_cache.clear()
		utils._cache_time.clear()
	else:
		# Clear specific entry
		if utils._path_to_instance_id.has(path):
			var instance_id = utils._path_to_instance_id[path]
			utils._instance_id_cache.erase(instance_id)
			utils._path_to_instance_id.erase(path)
			utils._node_cache.erase(path)
			utils._cache_time.erase(path)


static func get_node_with_retry(path: String, max_retries: int = 3, retry_delay: int = 50) -> Node:
	for attempt in range(max_retries):
		var node := get_cached_node(path)
		if node:
			return node

		# Retry after delay
		if attempt < max_retries - 1:
			OS.delay_msec(retry_delay)
			await Engine.get_main_loop().process_frame
			await Engine.get_main_loop().process_frame

	return null


static func serialize_value(value: Variant) -> Variant:
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


static func deserialize_value(value: Variant) -> Variant:
	if value is String and value.begins_with("res://"):
		var resource := load(value)
		if resource:
			return resource
	if value is Dictionary:
		if value.has("_resource"):
			return _create_resource(value)
		if value.has("x") and value.has("y"):
			if value.has("z"):
				return Vector3(value.x, value.y, value.z)
			return Vector2(value.x, value.y)
		if value.has("r") and value.has("g") and value.has("b"):
			return Color(value.r, value.g, value.b, value.get("a", 1.0))
	return value


static func _create_resource(spec: Dictionary) -> Resource:
	var resource_type: String = spec.get("_resource", "")
	if not ClassDB.class_exists(resource_type):
		MCPLog.error("Unknown resource type: %s" % resource_type)
		return null
	if not ClassDB.is_parent_class(resource_type, "Resource"):
		MCPLog.error("Type is not a Resource: %s" % resource_type)
		return null

	var resource: Resource = ClassDB.instantiate(resource_type)
	if not resource:
		MCPLog.error("Failed to create resource: %s" % resource_type)
		return null

	for key in spec:
		if key == "_resource":
			continue
		if key in resource:
			resource.set(key, deserialize_value(spec[key]))

	return resource


static func is_resource_path(path: String) -> bool:
	return path.begins_with("res://")


static func dir_exists(path: String) -> bool:
	if path.is_empty():
		return false
	if is_resource_path(path):
		var dir := DirAccess.open("res://")
		return dir != null and dir.dir_exists(path.trim_prefix("res://"))
	return DirAccess.dir_exists_absolute(path)


static func ensure_dir_exists(path: String) -> Error:
	if dir_exists(path):
		return OK
	if is_resource_path(path):
		var dir := DirAccess.open("res://")
		if not dir:
			return ERR_CANT_OPEN
		return dir.make_dir_recursive(path.trim_prefix("res://"))
	return DirAccess.make_dir_recursive_absolute(path)
