shader_type canvas_item;

const vec3 lava_top_col = vec3(1.0, 0.5, 0.25);
const vec3 lava_body_col = vec3(1., 0.1, 0.2);

uniform float fn_y_offset;
uniform float t;
//uniform vec2 resolution;

// function coefficients
uniform vec3 sc[1];
//uniform float fn_y_offset = -0.25;

uniform vec2 dummy_pos;
#define DEBUG

void fragment() {
	vec2 uv = 2. * UV - 1.;
	uv.y *= -1.0;


	float _time = t;
	//vec2 resolution = 1. / SCREEN_PIXEL_SIZE;
	//uv.x *= resolution.x / resolution.y;


	float func = 0.0;
	for (int i = 0; i < 1; i++)
	{
		func +=  sc[i].x * sin((sc[i].y * uv.x) - _time);
	}

	func += fn_y_offset;


	vec2 func_rel_pos = uv - vec2(uv.x, func);
	float dist_field = length(func_rel_pos);

	float dist = 1.0 / dist_field;
	dist *= 0.02;
	dist = pow(dist, 0.8);
	//dist += dist * prod * (1. - step(0.2, abs(uv.y - func)));// add the lava bubbles to the dist func
	vec3 col = mix(lava_body_col, lava_top_col, dist) * dist;
	col = 1.0 - exp( -col );
	vec4 top_lava_layer = vec4(col, dist * dist);

	// Lava body
	float body_mask = 1. - smoothstep(func - 0.01, func, uv.y);
	float gradient_from_bottom = smoothstep(-1., func, uv.y);

	vec4 lava_body = vec4( mix(lava_top_col, lava_body_col, gradient_from_bottom * body_mask), body_mask);

	COLOR = lava_body + top_lava_layer;
	//COLOR = vec4(vec3(func_rel_pos, 0.), 1.);


	//float circ = smoothstep(0.1, 0.11, length(uv - vec2(dummy_pos.x, func)));
	//float mask = 1. - smoothstep(func, func+ 0.01, uv.y);
	//COLOR = vec4(vec3(mask) * circ, mask);


}