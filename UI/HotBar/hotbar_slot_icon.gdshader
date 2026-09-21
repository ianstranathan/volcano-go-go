shader_type canvas_item;

//float avg( vec3 c){
	//return (c.x + c.y + c.z)/3.;
//}
uniform float available = 1.;
void fragment() {
	COLOR = step(0., available) * COLOR  +  (1. - step(0., available)) * COLOR * 0.5;
}

