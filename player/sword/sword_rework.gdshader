shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

uniform sampler2D noise_tex;
uniform float scroll;
uniform float swing_param: hint_range(0.0, 1.0, 0.1);
void fragment() {
	vec2 uv = UV;
	
	// -- alpha the "mesh" based on swing interpolation
	float alpha = 1. - smoothstep(swing_param, swing_param + 0.2, uv.x);
	
	uv.x -= scroll;
	
	vec4 noise_sample = texture(noise_tex, 0.32 * vec2(pow(UV.y, 0.5)));
	
	float y = uv.x - mix(0.05, 0.25, uv.y * uv.x) * cos(2. * pow(3. * noise_sample.r, 1.4));
	
    float mask = 1. - smoothstep( y-fwidth(uv.y), y + fwidth(uv.y), uv.y);;
	
    COLOR = vec4(vec3(mask), 0.5 * alpha * mask);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
