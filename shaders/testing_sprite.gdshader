shader_type canvas_item;


uniform sampler2D noise_tex;
uniform float distortion_uv_height;
uniform float distortion_thickness: hint_range(0.0, 1.0, 0.1);
uniform float ss_blur: hint_range(0.0, 0.2, 0.01);

void fragment()
{
	vec2 uv = 2. * UV - 1.;
	vec4 noise = texture(noise_tex, UV);
	float mask = (1. - smoothstep(distortion_uv_height, distortion_uv_height + ss_blur, uv.y)) * 
				 (smoothstep( distortion_uv_height - distortion_thickness, 
							  (distortion_uv_height - distortion_thickness) + ss_blur, 
				 uv.y));
	vec3 col = vec3(mask);
	COLOR = vec4(col, mask);
}


