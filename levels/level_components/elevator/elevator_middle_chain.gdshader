shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

mat2 rotate(float _angle){
    return mat2(vec2(cos(_angle), -sin(_angle)),
                vec2(sin(_angle), cos(_angle)));
}

uniform sampler2D chain_tex: repeat_enable, filter_nearest;
uniform vec3 ratio_and_dir = vec3(0., 0., 1.);

// just an upside down parabola for testing
float easing_fn(float x){
	return (1. - pow(2. * x - 1., 2.0));
}

void fragment() {
	vec2 uv = UV;
	uv.x -= TIME * ratio_and_dir.y;
	float down_shake_ampl = smoothstep(0., 1., ratio_and_dir.x) * (1. - step(0., ratio_and_dir.y));
	float up_shake_ampl = (-1. * smoothstep(0., 1., ratio_and_dir.x) + 1.) * step(0., ratio_and_dir.y);
	float t = down_shake_ampl + up_shake_ampl;
	uv.y += (0.25 * t) * sin(1. * uv.x - 30. * TIME) * ratio_and_dir.z;
	COLOR = texture(chain_tex, rotate(PI/2.) * uv);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
