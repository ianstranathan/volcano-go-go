shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

mat2 rotate(float _angle){
    return mat2(vec2(cos(_angle), -sin(_angle)),
                vec2(sin(_angle), cos(_angle)));
}

uniform sampler2D chain_tex: repeat_enable, filter_nearest;
uniform float scroll_speed = 5.0;
void fragment() {
	COLOR = texture(chain_tex, rotate(PI/2.) * UV - vec2(0., scroll_speed * TIME));
}


