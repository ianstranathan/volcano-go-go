shader_type canvas_item;

uniform float hit_modulation = 0.;
uniform vec4 src_col: source_color;
void fragment() {
	vec2 uv = 2. * UV - 1.;
	uv.x -= 0.1 * TIME;
	uv *= 0.2;
	float x = abs(uv.y) + uv.x;
	float mask = 2. * abs(fract(x) - 0.5);
	mask = smoothstep(0.6, 0.65, mask);
	vec3 col = src_col.xyz * mask;
	float a = (0.3 * mask) * (1. - hit_modulation) + mask * hit_modulation;
	COLOR = vec4(col, a);
}
