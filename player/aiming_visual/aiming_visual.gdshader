shader_type canvas_item;


uniform sampler2D tex;

uniform vec4 glow_color: source_color;
void fragment() {
	vec2 uv = 2. * UV - 1.;
	uv *= 0.2;
	float x = abs(uv.y) + uv.x;
	float mask = 2. * abs(fract(x) - 0.5);
	mask = smoothstep(0.6, 0.65, mask);
	vec3 col = vec3(1., 0., 1.) * mask + 0.3 * sin(4. * TIME);
	COLOR = vec4(col, mask);
}
