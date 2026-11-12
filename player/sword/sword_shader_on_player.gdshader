shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

//uniform sampler2D noise_tex: repeat_enable;
uniform float num_swings;

uniform sampler2D second_slash_tex;


void fragment() {
	//vec4 noise_s = texture(noise_tex, UV - vec2(0., TIME));
	vec2 uv = UV - vec2(0.2);
    vec4 first_tex = texture(TEXTURE, UV);
	vec4 second_tex = texture(second_slash_tex, UV);
	
	vec4 tex =  first_tex * step(2., num_swings) + (1. -  step(2., num_swings)) * second_tex;
    vec3 final_color = tex.rgb + 0.1 * (flash_amount * flash_amount);
	
    COLOR = vec4(final_color, tex.a * step(0.05, flash_amount));

}