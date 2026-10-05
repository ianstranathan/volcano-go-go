shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

mat2 rot( float angle){
	return mat2( vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
}
uniform sampler2D noise_tex;
void fragment() {
	vec2 uv = 2. * UV - 1.;
	uv = rot(0.1 * TIME) * uv;
	vec2 polar = vec2(length(uv), atan(uv.y, uv.x));
	
	float mask = smoothstep( 0.5, 0.5 + 2. * fwidth(polar.x), 
		polar.x + (0.2 * cos( 2. * polar.y + TIME)) * 0.434 * sin(5. * polar.y - 0.45 * TIME));
	COLOR = vec4(vec3(mask), 1. - mask);
	// Called for every pixel the material is visible on.
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
