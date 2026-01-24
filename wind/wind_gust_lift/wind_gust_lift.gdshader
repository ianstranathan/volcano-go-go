shader_type canvas_item;

uniform sampler2D noise_tex: repeat_enable;

const float func_disp = 0.0225;
const float period_disp = 50.1;//46.5;

float energy(vec3 v){
	return (v.r + v.g + v.b) / 3.;
}
mat2 rot(float angle){
	return mat2(vec2(cos(angle), -sin(angle)),
				vec2(sin(angle), cos(angle)));
}

const vec2 sprite_dims = vec2(128, 128);
void fragment() {
	vec2 _uv = 2. * UV - 1.;
	vec2 uv =  sprite_dims * (rot(PI/2.) * (UV - vec2(0.5)) + vec2(0.5));
	//vec2 uv = rot(PI/.2) * sprite_dims * UV;
	vec2 res = sprite_dims;//1.0 / SCREEN_PIXEL_SIZE;
	vec2 v = (2.*uv - res)/res.y;
	float t = -2. * TIME;
    float c = 5.;
	float tc = t * c;

	uv /= res * vec2(6.,1.2);
    uv.x -= tc * func_disp;
	uv.y += cos(uv.x * period_disp + tc) * .05;
	vec4 tex = texture(noise_tex, uv, 3.5);

	v /= 5.;
	v.x /= 2.;
	v.x -= tc * func_disp;
	//v.y += sin(uv.x * period_disp + tc) * .05;
	tex += texture(noise_tex, v - vec2(0.1 * TIME, 0.), 2.75)*.7;
	tex = smoothstep(tex+0.5, tex, vec4(.71));

	//float a = 1. - length(_uv);

	COLOR = 2. * vec4(vec3(1.), (1. - length(_uv)) * (1. - tex.r));
}
