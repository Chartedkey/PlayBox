shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

// Диск без отверстия: рисунок из обложки, блик и нижняя полоса.
uniform sampler2D art : source_color, filter_linear_mipmap;
uniform bool use_art = false;
uniform bool full_image = false;
uniform float art_aspect = 1.0;
uniform vec3 base_color : source_color = vec3(0.1);

void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p) * 2.0;
	if (r > 1.0) { discard; }
	vec3 c = base_color;
	if (use_art) {
		vec2 uv = UV;
		if (!full_image) {
			// Верхний квадрат обложки: там обычно есть название игры.
			if (art_aspect < 1.0) {
				uv.y = uv.y * art_aspect + 0.13;
			} else {
				uv.x = (uv.x - 0.5) / art_aspect + 0.5;
			}
		}
		c = texture(art, uv).rgb;
		float g = dot(c, vec3(0.33));
		c = mix(vec3(g), c, 0.9);
	}
	c *= 1.0 - 0.28 * smoothstep(0.6, 1.0, r);
	if (!full_image && UV.y > 0.82) {
		c = mix(c, vec3(0.03), 0.9);
	}
	float a = atan(p.y, p.x);
	float sheen = pow(abs(cos(a * 2.0 + 0.7)), 10.0) + 0.6 * pow(abs(cos(a * 2.0 - 1.0)), 18.0);
	c += 0.11 * sheen * smoothstep(0.15, 0.55, r);
	c *= 1.0 - 0.45 * smoothstep(0.965, 0.995, r);
	ALBEDO = c;
}
