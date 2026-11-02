shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

// Пол плавно растворяется в тёмном фоне, чтобы не было линии горизонта.
uniform vec3 color : source_color = vec3(0.1);
uniform float fade_start = 2.5;
uniform float fade_end = 7.5;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = color;
	ROUGHNESS = 0.8;
	ALPHA = 1.0 - smoothstep(fade_start, fade_end, length(world_pos.xz));
}
