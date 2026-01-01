shader_type canvas_item;


uniform sampler2D noise_tex: repeat_enable;
uniform float distortion_uv_height;
uniform float distortion_thickness: hint_range(0.0, 1.0, 0.1);
uniform float ss_blur: hint_range(0.0, 0.5, 0.01);
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment()
{
	vec2 uv = 2. * UV - 1.;
	float a = smoothstep(distortion_uv_height - 0.5, distortion_uv_height, uv.y);
	float b = 1. - smoothstep(distortion_uv_height, distortion_uv_height + 0.5, uv.y);
	float mask = a * b;
	vec4 noise = texture(noise_tex, UV + vec2(0.1, 0.4) * TIME);
	vec3 c = textureLod(screen_texture, SCREEN_UV + 0.02 * noise.r * mask, 0.0).rgb;
	//vec3 col = noise.xyz;
	COLOR = vec4(c, 1.);
}
