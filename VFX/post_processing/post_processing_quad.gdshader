shader_type canvas_item;

varying vec2 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D noise_tex : repeat_enable;

uniform float lava_level;
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.02;
uniform float heat_range : hint_range(0.0, 1000.0) = 600.0;
uniform float t;
uniform vec3 sc[1];
uniform vec2 transition_data; // t, relative vec2, is_transitioning
uniform vec2 rel_pos_portal;
uniform float race_started = 0.;

uniform float fade_progress = 1.;

void fragment() {
    vec2 uv = SCREEN_UV * 2.0 - 1.0;

	vec2 dims = 1.0 / SCREEN_PIXEL_SIZE;
    uv.x *= dims.x / dims.y;
    vec2 world_pos = world_position + uv;

    vec2 p = vec2(world_position.x, -world_position.y);
    //float world_freq = 0.001;
    //float world_amp = 100.0;
    //float fn = world_amp * sin(world_freq * p.x - (speed * TIME));

	float fn = 0.0;
	for (int i = 0; i < 1; i++)
	{
		fn -=  sc[i].x * sin((sc[i].y * p.x) - t);
	}
    float surface = p.y + lava_level + fn;
    float heat_mask = clamp(1.0 - (surface / heat_range), 0.0, 1.0);
    heat_mask = pow(heat_mask, 2.0);

    vec4 noise = texture(noise_tex, 0.001 * world_pos + vec2(0., 0.1 * TIME));
    vec2 distortion = vec2(0.5 * noise.r, 0.5 * noise.r) * distortion_strength * heat_mask;
    vec4 scene_color = textureLod(screen_texture,
	// -- only distort if we're in the lava area: race_started
	SCREEN_UV + (distortion * race_started), 0.0);
    //vec3 heat_tint = vec3(1.0, 0.4, 0.0);
    //scene_color.rgb = mix(scene_color.rgb, heat_tint, heat_mask * 0.15);

	// -- transition stuffa 
	vec2 rel = rel_pos_portal / dims;
	rel.x *= dims.x / dims.y;
	float r = length(uv - rel);
	float _t = mix(0., 3.0, transition_data.x * transition_data.x);
	float mask = 1. - smoothstep( _t, _t + fwidth( r), r);
	
	float is_transitioning = transition_data.y;
	vec3 transition_col = vec3(0.2) * mask;

	// scene color has to remove whatever the mask is if the transition mask is
	// active, so scene_color.xyz * (1. - (mask * is_transitioning))
	vec3 col = scene_color.xyz * (1. - (mask * is_transitioning)) + 
			   (is_transitioning * transition_col);
	//vec4 transition_col = vec4( , 1.);
	
	//vec3 col = (1. - transition_data.y) * scene_color.xyz;
	//COLOR = textureLod(screen_texture, SCREEN_UV, 0.);
	COLOR = vec4(col * (1. - fade_progress), 1.);
}
