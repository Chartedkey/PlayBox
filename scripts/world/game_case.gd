class_name GameCase
extends Node3D
## Коробка игры с обложкой и диском внутри.

const DEPTH := 0.05
const DISC_SHADER := preload("res://scripts/world/disc.gdshader")

var game: Dictionary
var disc: MeshInstance3D
var _cover_mesh: MeshInstance3D
var _case_size: Vector2
var _disc_mat: ShaderMaterial
var _title_label: Label3D


func setup(g: Dictionary, cover: Texture2D, disc_image: Texture2D) -> void:
	game = g
	var info := Consoles.info(g["console"])
	_case_size = info["case_size"]
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(_case_size.x, _case_size.y, DEPTH)
	body.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = info["case_color"]
	bmat.roughness = 0.35
	body.material_override = bmat
	add_child(body)
	_cover_mesh = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = _case_size * 0.975
	_cover_mesh.mesh = q
	_cover_mesh.position.z = DEPTH / 2 + 0.001
	add_child(_cover_mesh)
	disc = MeshInstance3D.new()
	var dq := QuadMesh.new()
	dq.size = Vector2.ONE * minf(_case_size.x, _case_size.y) * 0.84
	disc.mesh = dq
	_disc_mat = ShaderMaterial.new()
	_disc_mat.shader = DISC_SHADER
	_disc_mat.set_shader_parameter("base_color", info["disc_base"])
	disc.material_override = _disc_mat
	disc.position.z = -0.002
	disc.visible = false
	add_child(disc)
	_title_label = Label3D.new()
	_title_label.text = info["name"]
	_title_label.font_size = 26
	_title_label.pixel_size = 0.0016
	_title_label.position = Vector3(0, -dq.size.y * 0.38, 0.003)
	_title_label.modulate = Color(0.94, 0.94, 0.94)
	disc.add_child(_title_label)
	set_images(cover, disc_image)


func set_images(cover: Texture2D, disc_image: Texture2D) -> void:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.4
	if cover:
		mat.albedo_texture = cover
	else:
		mat.albedo_color = Color(0.2, 0.21, 0.24)
	_cover_mesh.material_override = mat
	_clear_placeholder()
	if cover == null:
		var l := Label3D.new()
		l.name = "PlaceholderTitle"
		l.text = game["title"]
		l.font_size = 40
		l.pixel_size = 0.0018
		l.width = 340.0
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.position = Vector3(0, 0, DEPTH / 2 + 0.003)
		add_child(l)
	var art := disc_image if disc_image else cover
	_disc_mat.set_shader_parameter("use_art", art != null)
	_disc_mat.set_shader_parameter("full_image", disc_image != null)
	if art:
		_disc_mat.set_shader_parameter("art", art)
		var s := art.get_size()
		_disc_mat.set_shader_parameter("art_aspect", s.x / maxf(s.y, 1.0))
	_title_label.text = Consoles.info(game["console"])["name"] if art else game["title"]


func _clear_placeholder() -> void:
	var old := get_node_or_null("PlaceholderTitle")
	if old:
		old.free()


func reset_disc() -> void:
	disc.scale = Vector3.ONE
	disc.position = Vector3(0, 0, -0.002)
	disc.rotation = Vector3.ZERO
	disc.visible = false


func case_size() -> Vector2:
	return _case_size


## t: 0 — диск в коробке, 1 — полностью выехал.
func set_disc_out(t: float) -> void:
	disc.visible = t > 0.001
	disc.position.x = lerp(0.0, _case_size.x * 0.82, t)
	disc.rotation.z = -TAU * t
