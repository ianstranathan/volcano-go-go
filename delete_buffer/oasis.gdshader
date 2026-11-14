shader_type canvas_item;

uniform sampler2D noise_tex:repeat_enable;

void vertex() {
	// Called for every vertex the material is visible on.
}
float avg(vec4 v){
	return (v.x + v.y + v.z + v.w) / 4.0;
}
//mat2 rotate(float _angle){
    //return mat2(vec2(cos(_angle), -sin(_angle)),
                //vec2(sin(_angle), cos(_angle)));
//}
uniform float fuzziness : hint_range(0.0, 0.1) = 0.03;
uniform float amt: hint_range(0.0, 1.0, 0.1);
void fragment() {
	vec2 moving_uv = UV + vec2(TIME * 0.1);
	vec4 noise_sample = texture(noise_tex, moving_uv);
	// --
	vec2 distorted_uv = UV + (noise_sample.xy - 0.5) * fuzziness;

	vec4 noise = texture(noise_tex, distorted_uv);
	COLOR.a *= smoothstep(amt, amt + fwidth(noise.r), noise.r);

	//
	vec4 tex_color = texture(TEXTURE, UV);
	vec4 target_color = vec4(0.145, 0.588, 0.745, 1.);

    float mask = step(avg(target_color), avg(tex_color));

	float angle = atan(UV.y+10., UV.x + 3.);
	float fn_1 = 1.76 * sin(300. * angle + 0.345 * TIME);
	float fn_2 = 1.53 * cos(203. * angle - 0.345 * TIME);
	float ret = fn_1 * fn_2 * (1. - smoothstep(vec4(0.), vec4(0.), fwidth(COLOR)).r);
	COLOR.xyz += mask * 0.3 *vec3(clamp(ret, 0., 1));
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
