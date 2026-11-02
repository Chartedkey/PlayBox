class_name Studio
extends Node3D
## Тёмная студия: пол, свет и камера.

var camera: Camera3D


func _ready() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0c0d10")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.74, 0.8)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_mesh.mesh = pm
	var fm := ShaderMaterial.new()
	fm.shader = preload("res://scripts/world/floor.gdshader")
	fm.set_shader_parameter("color", Color("24252b"))
	floor_mesh.material_override = fm
	floor_mesh.position.y = -0.62
	add_child(floor_mesh)
	var key := SpotLight3D.new()
	key.position = Vector3(-1.5, 5.2, 3.6)
	key.look_at_from_position(key.position, Vector3(0, -0.2, 0))
	key.spot_range = 12.0
	key.spot_angle = 50.0
	key.spot_attenuation = 0.7
	key.light_energy = 4.8
	key.shadow_enabled = true
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 35, 0)
	fill.light_energy = 0.18
	add_child(fill)
	camera = Camera3D.new()
	camera.fov = 32.0
	camera.position = Vector3(0, 0.55, 5.6)
	camera.rotation_degrees.x = -3.0
	add_child(camera)
	camera.make_current()
