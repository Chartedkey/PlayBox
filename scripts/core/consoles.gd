class_name Consoles
## Описание поддерживаемых консолей.

const IDS: Array[String] = ["ps1", "ps2", "ps3"]

const INFO := {
	"ps1": {
		"name": "PlayStation",
		"emulator_hint": "DuckStation",
		"extensions": ["m3u", "cue", "chd", "pbp", "iso", "img", "ecm", "bin"],
		"args": ["-batch", "-fullscreen", "--", "{path}"],
		"libretro": "Sony - PlayStation",
		"case_size": Vector2(0.71, 0.625),
		"case_color": Color("17181a"),
		"box_color": Color("101114"),
		"box_inner": Color("25272b"),
		"box_size": Vector3(1.0, 0.8, 0.58),
		"disc_base": Color("0a0a0c"),
	},
	"ps2": {
		"name": "PlayStation 2",
		"emulator_hint": "PCSX2",
		"extensions": ["m3u", "cue", "chd", "iso", "cso", "gz", "bin"],
		"args": ["-batch", "-fullscreen", "--", "{path}"],
		"libretro": "Sony - PlayStation 2",
		"case_size": Vector2(0.675, 0.95),
		"case_color": Color("0e0e10"),
		"box_color": Color("e9d400"),
		"box_inner": Color("c4b200"),
		"box_size": Vector3(1.0, 0.8, 0.38),
		"disc_base": Color("c9ccd0"),
	},
	"ps3": {
		"name": "PlayStation 3",
		"emulator_hint": "RPCS3",
		"extensions": [],
		"args": ["--no-gui", "{path}"],
		"libretro": "Sony - PlayStation 3",
		"case_size": Vector2(0.675, 0.85),
		"case_color": Color("c7ccd2"),
		"box_color": Color("a9b2b4"),
		"box_inner": Color("7f888a"),
		"box_size": Vector3(1.0, 0.82, 0.5),
		"disc_base": Color("dfe2e6"),
	},
}


static func info(id: String) -> Dictionary:
	return INFO[id]
