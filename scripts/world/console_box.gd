class_name ConsoleBox
extends Node3D
## Коробка приставки: стенки, клапаны и приставка внутри.

const TILT := Vector3(deg_to_rad(-4), deg_to_rad(-27), 0)

var console_id: String
var size: Vector3
var _top: MeshInstance3D
var _front_flap: Node3D
var _back_flap: Node3D
var _left_flap: Node3D
var _right_flap: Node3D
var _flaps: Array[Node3D] = []
var _console: Sprite3D
var _body: Node3D
var _rise := 0.0
var _rise_height := 1.0


func setup(id: String) -> void:
	console_id = id
	var info := Consoles.info(id)
	size = info["box_size"]
	_body = Node3D.new()
	_body.rotation = TILT
	add_child(_body)
	var ready_art := AssetStore.texture(id + "/box_front.png") != null
	var col: Color = info["box_color"]
	_face(Vector3(0, 0, size.z / 2), Vector3.ZERO, Vector2(size.x, size.y), id + "/box_front.png", col)
	_face(Vector3(size.x / 2, 0, 0), Vector3(0, PI / 2, 0), Vector2(size.z, size.y), id + "/box_side.png", col)
	_face(Vector3(-size.x / 2, 0, 0), Vector3(0, -PI / 2, 0), Vector2(size.z, size.y), id + "/box_side.png", col)
	_face(Vector3(0, 0, -size.z / 2), Vector3(0, PI, 0), Vector2(size.x, size.y), "", col)
	_top = _face(Vector3(0, size.y / 2, 0), Vector3(-PI / 2, 0, 0), Vector2(size.x, size.z), id + "/box_top.png", col)
	_face(Vector3(0, -size.y / 2, 0), Vector3(PI / 2, 0, 0), Vector2(size.x, size.z), "", col)
	# Внутренность: куб, видимый только изнутри.
	var inner := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size * 0.995
	inner.mesh = bm
	var im := StandardMaterial3D.new()
	im.albedo_color = info["box_inner"]
	im.cull_mode = BaseMaterial3D.CULL_FRONT
	inner.material_override = im
	_body.add_child(inner)
	var inner_col: Color = info["box_inner"]
	_front_flap = _flap(Vector3(0, size.y / 2, size.z / 2), Vector2(size.x, 0.14), inner_col)
	_back_flap = _flap(Vector3(0, size.y / 2, -size.z / 2), Vector2(size.x, size.z * 0.55), inner_col)
	_left_flap = _flap(Vector3(-size.x / 2, size.y / 2, 0), Vector2(size.z, 0.24), inner_col, true)
	_right_flap = _flap(Vector3(size.x / 2, size.y / 2, 0), Vector2(size.z, 0.24), inner_col, true)
	_flaps = [_front_flap, _back_flap, _left_flap, _right_flap]
	if not ready_art:
		_add_placeholder_label(info["name"])
	_console = Sprite3D.new()
	var tex := AssetStore.texture(id + "/console.png")
	_console.texture = tex if tex else _placeholder_console()
	_console.pixel_size = 1.2 / float(_console.texture.get_width())
	_console.shaded = false
	_console.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_console.visible = false
	add_child(_console)
	set_open(0.0)
	set_rise(0.0)


func _face(pos: Vector3, rot: Vector3, dims: Vector2, art: String, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = dims
	m.mesh = q
	var mat := StandardMaterial3D.new()
	var tex := AssetStore.texture(art) if art != "" else null
	if tex:
		mat.albedo_texture = tex
	else:
		mat.albedo_color = col
	mat.roughness = 0.55
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	_body.add_child(m)
	return m


func _flap(hinge: Vector3, dims: Vector2, col: Color, sideways := false) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = hinge
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = dims
	m.mesh = q
	m.position = Vector3(0, dims.y / 2, 0)
	if sideways:
		m.rotation.y = PI / 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.8
	m.material_override = mat
	pivot.add_child(m)
	_body.add_child(pivot)
	return pivot


func _add_placeholder_label(text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.002
	l.position = Vector3(0, 0, size.z / 2 + 0.002)
	_body.add_child(l)


func _placeholder_console() -> Texture2D:
	var img := Image.create(420, 200, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.45, 0.46, 0.5))
	return ImageTexture.create_from_image(img)


## 0 — закрыта, 1 — открыта.
func set_open(t: float) -> void:
	_top.visible = t <= 0.001
	for f in _flaps:
		f.visible = t > 0.001
	_front_flap.rotation.x = lerp(-PI / 2, deg_to_rad(168), t)
	_back_flap.rotation.x = lerp(PI / 2, deg_to_rad(-35), t)
	_left_flap.rotation.z = lerp(-PI / 2, deg_to_rad(112), t)
	_right_flap.rotation.z = lerp(PI / 2, deg_to_rad(-112), t)


## 0 — приставка внутри, 1 — над коробкой.
func set_rise(t: float) -> void:
	_rise = t
	_console.visible = t > 0.001
	var h: float = _console.texture.get_height() * _console.pixel_size
	_console.position = Vector3(0, lerp(size.y * 0.1 - h * 0.2, size.y / 2 + h / 2 + 0.2, t), lerp(0.0, 0.35, t))
	_console.scale = Vector3.ONE * lerp(0.82, 1.12, t)


## Приставка остаётся на месте, пока коробка уезжает вниз.
func hold_console_at(world_pos: Vector3, box_target: Vector3) -> void:
	_console.top_level = false
	_console.position = (world_pos - box_target) / scale.x


func console_sprite() -> Sprite3D:
	return _console
