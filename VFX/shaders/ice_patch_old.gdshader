shader_type canvas_item;

vec2 rotateOnOrigin(vec2 v, float theta)
{
    mat2 rot = mat2( vec2( cos(theta), sin(theta)),
                     vec2(-sin(theta), cos(theta)));
    return rot * v;
}

float sdfCirc_guy(vec2 uv, vec2 pos)
{
    float radius_disp = 0.1 * sin(2. * TIME);
	return length(uv - pos) +  radius_disp * cos( 10.0 * atan(uv.y / uv.x) - TIME);
}

uniform sampler2D color_grad_tex;
uniform sampler2D noise_tex;

void fragment() {
	vec2 uv = 2. * UV - 1.;
	//rotateOnOrigin(UV - vec2(0.5), PI/6.)
	vec4 noise_tex_sample = texture(noise_tex, UV);
	float angle = atan(UV.y / UV.x);
	float rad_1 = length(UV) -  0.2 * noise_tex_sample.r * cos( 9. * angle);
	float mask_1 = 1. - smoothstep(1., 1.01, rad_1);
	float rad_2 = length(UV) -  1. * noise_tex_sample.r * cos( 0.8 * angle);
	float mask_2 = 1. - smoothstep(0.2, 0.24, rad_2);
	float rad_3 = length(UV) -  0.5 * noise_tex_sample.r * cos( 0.7 * angle);
	float mask_3 = 1. - smoothstep(0.01, 0.02, rad_3);

	float center_noise = 0.4 * length(uv) * noise_tex_sample.r;
	vec3 col_1    = texture(color_grad_tex, vec2(0.04) + center_noise).xyz * mask_1;
	vec3 last_col = texture(color_grad_tex,
	                        vec2(length(noise_tex_sample.gg) + 0.2 * noise_tex_sample.r)).xyz * (1. - mask_1);
	last_col += col_1;
	vec3 col = last_col * (1. - mask_2) + 0.9 * mask_2 * texture(color_grad_tex, vec2(0.05 + center_noise * noise_tex_sample.rr)).xyz;
	col *= (1. - mask_3);
	col += texture(color_grad_tex, vec2(0.05) * noise_tex_sample.rr).xyz * mask_3;
	col += 0.56 * noise_tex_sample.r * length( 2. * SCREEN_UV - 1.);
	COLOR = vec4(col * 0.9, 1.);
}