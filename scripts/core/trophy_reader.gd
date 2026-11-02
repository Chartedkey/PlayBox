class_name TrophyReader
## Читает локальные трофеи RPCS3 из TROPUSR.DAT.

const MAGIC := 0x818F54AD
const HEADER := 48
const TABLE := 32
const ENTRY_STATE_OFFSET := 20


static func _u32(b: PackedByteArray, o: int) -> int:
	return (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3]


static func _u64(b: PackedByteArray, o: int) -> int:
	return (_u32(b, o) << 32) | _u32(b, o + 4)


## Возвращает {"earned": n, "total": m} или пустой словарь.
static func parse(b: PackedByteArray) -> Dictionary:
	if b.size() < HEADER or _u32(b, 0) != MAGIC:
		return {}
	var tables := _u32(b, 8)
	for i in tables:
		var t := HEADER + i * TABLE
		if t + TABLE > b.size():
			return {}
		if _u32(b, t) != 6:
			continue
		var size := _u32(b, t + 4) + 16
		var count := _u32(b, t + 12)
		var offset := _u64(b, t + 16)
		var earned := 0
		for n in count:
			var e := offset + n * size
			if e + ENTRY_STATE_OFFSET + 4 > b.size():
				return {}
			if _u32(b, e + ENTRY_STATE_OFFSET) != 0:
				earned += 1
		return {"earned": earned, "total": count}
	return {}


## Имя папки трофеев игры, например NPWR01234_00.
static func comm_id(game_path: String) -> String:
	var root := game_path.get_base_dir().get_base_dir()
	var d := DirAccess.open(root.path_join("TROPDIR"))
	if d == null:
		return ""
	var dirs := d.get_directories()
	return dirs[0] if dirs.size() > 0 else ""


static func read_for_game(emulator_exe: String, game_path: String) -> Dictionary:
	var id := comm_id(game_path)
	if id == "":
		return {}
	var home := emulator_exe.get_base_dir().path_join("dev_hdd0/home")
	var d := DirAccess.open(home)
	if d == null:
		return {}
	for user in d.get_directories():
		var f := home.path_join(user).path_join("trophy").path_join(id).path_join("TROPUSR.DAT")
		if FileAccess.file_exists(f):
			return parse(FileAccess.get_file_as_bytes(f))
	return {}
