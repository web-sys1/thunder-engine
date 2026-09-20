extends Node

const USE_EXPERIMENTAL_FEATURE: bool = true
const RESURRECTION_TIME: float = 8.0
const WARNING_DURATION: float = 1.0

const UID_MAP = {
	"green": "uid://cno8qn60lpnvv",
	"red": "uid://b24hnsctae1a0",
	"blue": "uid://c7ndajwed1l1n",
	"yellow": "uid://cit8vdoqn0xoo"
}

var tracked_shells: Dictionary = {}

func _physics_process(delta: float) -> void:
	if !USE_EXPERIMENTAL_FEATURE: return
	
	for shell in tracked_shells.keys():
		if !is_instance_valid(shell):
			tracked_shells.erase(shell)
			continue
			
		if !shell.stopping:
			_cancel_shell_resurrect(shell)
			continue
			
		var data = tracked_shells[shell]
		data.elapsed += delta
		
		var warning_start = max(0.0, RESURRECTION_TIME - WARNING_DURATION)
		if data.elapsed >= warning_start:
			data.is_blinking = true
			
		if data.elapsed >= RESURRECTION_TIME:
			_execute_resurrection(shell)
			continue
			
		if data.is_blinking && shell.animation:
			data.blink_timer += delta
			if data.blink_timer >= 0.06:
				shell.animation.visible = !shell.animation.visible
				data.blink_timer = 0.0

func register_shell(shell: CharacterBody2D) -> void:
	if !USE_EXPERIMENTAL_FEATURE: return
	
	if is_instance_valid(shell):
		if shell.has_meta(&"born_from_scene") or shell.name.begins_with("@") or !shell.scene_file_path.is_empty():
			if !shell.has_meta(&"was_stomped") and get_tree().get_frame() > 1:
				shell.set_meta(&"was_stomped", true)

		var shell_path: String = shell.scene_file_path.to_lower()
		var node_name: String = shell.name.to_lower()
		var texture_path: String = ""
		if shell.animation && shell.animation.sprite_frames:
			texture_path = shell.animation.sprite_frames.resource_path.to_lower()
			
		if "buzzle" in shell_path or "buzzy" in shell_path or \
		   "buzzle" in node_name or "buzzy" in node_name or \
		   "buzzle" in texture_path or "buzzy" in texture_path:
			return 
			
	if !shell in tracked_shells:
		tracked_shells[shell] = {
			"elapsed": 0.0,
			"is_blinking": false,
			"blink_timer": 0.0
		}

func unregister_shell(shell: CharacterBody2D) -> void:
	_cancel_shell_resurrect(shell)

func _cancel_shell_resurrect(shell: CharacterBody2D) -> void:
	if shell in tracked_shells:
		tracked_shells[shell] = {
			"elapsed": 0.0,
			"is_blinking": false,
			"blink_timer": 0.0
		}
		tracked_shells.erase(shell)
		if is_instance_valid(shell) && shell.animation:
			shell.animation.visible = true

func _execute_resurrection(shell: CharacterBody2D) -> void:
	tracked_shells.erase(shell)
	
	var spawned_scene: PackedScene = _get_alive_scene(shell)
	if !spawned_scene || !spawned_scene.can_instantiate():
		return
		
	var alive_enemy = spawned_scene.instantiate() as Node2D
	if alive_enemy && is_instance_valid(shell) && shell.get_parent():
		shell.get_parent().add_child(alive_enemy)
		alive_enemy.global_position = shell.global_position
		
		if "dir" in alive_enemy:
			alive_enemy.dir = shell.dir
			
		var turner = alive_enemy.get_node_or_null("Turner") as RayCast2D
		if turner:
			turner.position.x = abs(turner.position.x) * shell.dir
			turner.force_raycast_update()
			
		shell.queue_free()

func _get_alive_scene(node: Node) -> PackedScene:
	if !node: return null
	
	var file_check = node.scene_file_path.to_lower()
	var name_lower = node.name.to_lower()
	if "buzzle" in file_check or "buzzy" in file_check or "buzzle" in name_lower or "buzzy" in name_lower:
		return null 
		
	var target_uid: String = ""
	
	if node.has_meta(&"shell_color_id"):
		match node.get_meta(&"shell_color_id"):
			0: target_uid = UID_MAP["green"]
			1: target_uid = UID_MAP["red"]
			2: target_uid = UID_MAP["blue"]
			3: target_uid = UID_MAP["yellow"]

	if target_uid.is_empty(): return null
	
	var id: int = ResourceUID.text_to_id(target_uid)
	if ResourceUID.has_id(id):
		return load(ResourceUID.get_id_path(id)) as PackedScene
	return null
