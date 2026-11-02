class_name SfoParser
## Читает PARAM.SFO игр PS3: название, ID и категорию.


static func parse(bytes: PackedByteArray) -> Dictionary:
	var out := {}
	if bytes.size() < 20 or bytes.slice(0, 4) != PackedByteArray([0, 0x50, 0x53, 0x46]):
		return out
	var key_table := bytes.decode_u32(8)
	var data_table := bytes.decode_u32(12)
	var count := bytes.decode_u32(16)
	for i in count:
		var e := 20 + i * 16
		if e + 16 > bytes.size():
			break
		var key_off := key_table + bytes.decode_u16(e)
		var fmt := bytes.decode_u16(e + 2)
		var length := bytes.decode_u32(e + 4)
		var data_off := data_table + bytes.decode_u32(e + 12)
		if data_off + length > bytes.size():
			continue
		var end := key_off
		while end < bytes.size() and bytes[end] != 0:
			end += 1
		var key := bytes.slice(key_off, end).get_string_from_utf8()
		if fmt == 0x0404:
			out[key] = bytes.decode_u32(data_off)
		else:
			out[key] = bytes.slice(data_off, data_off + length).get_string_from_utf8()
	return out


static func parse_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	return parse(FileAccess.get_file_as_bytes(file_path))
