extends Node

const CEL_SHADER_PATH := "res://Scenes/Shaders/cel_post_process.gdshader"
const OVERLAY_NAME := "CelStyleOverlay"
const OVERLAY_LAYER := -30
const CEL_STYLED_MESH_META := "cel_styled_mesh"
const CEL_STYLED_MATERIAL_META := "cel_styled_material"

var _cel_shader: Shader = null

func _ready() -> void:
	_cel_shader = load(CEL_SHADER_PATH) as Shader
	if _cel_shader == null:
		push_warning("[VisualStyleManager] Could not load cel shader at %s" % CEL_SHADER_PATH)
		return

	if not get_tree().scene_changed.is_connected(_on_scene_changed):
		get_tree().scene_changed.connect(_on_scene_changed)

	# Wait one frame to ensure current_scene is fully instantiated.
	await get_tree().process_frame
	_apply_to_current_scene()


func _on_scene_changed() -> void:
	_apply_to_current_scene.call_deferred()


func _apply_to_current_scene() -> void:
	if _cel_shader == null:
		return

	var scene_root := get_tree().current_scene
	if scene_root == null:
		return

	if not _scene_uses_3d(scene_root):
		return

	_apply_toon_material_style(scene_root)

	if scene_root.get_node_or_null(OVERLAY_NAME) != null:
		return

	var layer := CanvasLayer.new()
	layer.name = OVERLAY_NAME
	layer.layer = OVERLAY_LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS

	var post_rect := ColorRect.new()
	post_rect.name = "CelPostRect"
	post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_rect.color = Color(1, 1, 1, 1)

	var shader_material := ShaderMaterial.new()
	shader_material.shader = _cel_shader
	post_rect.material = shader_material

	layer.add_child(post_rect)
	scene_root.add_child(layer)


func _apply_toon_material_style(root: Node) -> void:
	for child in root.get_children():
		if not (child is Node):
			continue

		var child_node := child as Node
		if child_node is MeshInstance3D:
			_stylize_mesh_instance(child_node as MeshInstance3D)

		_apply_toon_material_style(child_node)


func _stylize_mesh_instance(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.has_meta(CEL_STYLED_MESH_META):
		return

	if _should_skip_mesh(mesh_instance):
		return

	if mesh_instance.material_override is BaseMaterial3D:
		mesh_instance.material_override = _stylize_base_material(mesh_instance.material_override as BaseMaterial3D)

	if mesh_instance.mesh != null:
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var source_material := mesh_instance.get_surface_override_material(surface_index)
			if source_material == null:
				source_material = mesh_instance.mesh.surface_get_material(surface_index)

			if source_material is BaseMaterial3D:
				mesh_instance.set_surface_override_material(surface_index, _stylize_base_material(source_material as BaseMaterial3D))

	mesh_instance.set_meta(CEL_STYLED_MESH_META, true)


func _stylize_base_material(material: BaseMaterial3D) -> BaseMaterial3D:
	if material == null:
		return null

	if material.has_meta(CEL_STYLED_MATERIAL_META):
		return material

	var stylized := material.duplicate() as BaseMaterial3D
	if stylized == null:
		return material

	stylized.resource_local_to_scene = true
	stylized.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	stylized.specular_mode = BaseMaterial3D.SPECULAR_TOON
	stylized.metallic = stylized.metallic * 0.35
	stylized.roughness = clampf(stylized.roughness + 0.12, 0.0, 1.0)
	stylized.rim_enabled = false
	stylized.clearcoat_enabled = false
	stylized.set_meta(CEL_STYLED_MATERIAL_META, true)
	return stylized


func _should_skip_mesh(mesh_instance: MeshInstance3D) -> bool:
	var node_name := mesh_instance.name.to_lower()
	if node_name.contains("monitor"):
		return true

	if _material_uses_viewport_texture(mesh_instance.material_override):
		return true

	if mesh_instance.mesh == null:
		return false

	for surface_index in range(mesh_instance.mesh.get_surface_count()):
		if _material_uses_viewport_texture(mesh_instance.get_surface_override_material(surface_index)):
			return true

		if _material_uses_viewport_texture(mesh_instance.mesh.surface_get_material(surface_index)):
			return true

	return false


func _material_uses_viewport_texture(material: Material) -> bool:
	if not (material is StandardMaterial3D):
		return false

	var standard_material := material as StandardMaterial3D
	return standard_material.albedo_texture is ViewportTexture


func _scene_uses_3d(root: Node) -> bool:
	if root is Node3D:
		return true

	return _has_camera_3d(root)


func _has_camera_3d(node: Node) -> bool:
	if node is Camera3D:
		return true

	for child in node.get_children():
		if child is Node and _has_camera_3d(child):
			return true

	return false
