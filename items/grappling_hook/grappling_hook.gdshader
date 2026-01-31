shader_type canvas_item;

//void vertex() {
	//// Called for every vertex the material is visible on.
//}

uniform sampler2D tex: repeat_enable;
mat2 rot(float angle){
	return mat2(vec2(cos(angle), -sin(angle)),
				vec2(sin(angle), cos(angle)));
}
void fragment() {
	vec4 t = texture(tex, rot(PI/2.) * UV);
	COLOR = t;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
