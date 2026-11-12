shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 10.0) = 2.0;
uniform float tiling_scale = 0.001; // Scale down world coords to fit texture frequency
varying vec2 world_position;

uniform vec2 camera_pos;
uniform vec2 parallax_offset;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

uniform sampler2D noise_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal_map : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D magma_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_that_maps_ontop_of_rock : source_color, filter_linear_mipmap, repeat_enable;

uniform vec2 level_origin;
uniform vec2 level_dims;

const vec3 light_dir = vec3(0., 1., 0.);

const float distance_factor = 1.;

mat2 rot( float angle){
	return mat2(
		vec2(cos(angle), -sin(angle)),
		vec2(sin(angle), cos(angle))
	);
}

vec2 rotated_UV(vec2 uv, mat2 rota){
	return rota* (uv - vec2(0.5)) + vec2(0.5);
}

uniform float max_blur_level = 4.0;
void fragment(){
	//vec2 adjusted_world_pos = world_position - TIME;
    vec2 _UV = (world_position - vec2(0.8 * camera_pos.x, camera_pos.y)) / (level_dims / 2.0);
	//vec2 _UV = (world_position - parallax_offset) / (level_dims / 2.);
	//_UV = UV;
	// -- rock and diffuse light
	float lod = distance_factor * max_blur_level;
	
	vec3 normal = textureLod(rock_normal_map, _UV, lod).xyz;
	float diffuse_raw        = dot(normal,  light_dir); //normalize(light_pos)); 
	float diffuse_normalized = diffuse_raw * 0.5 + 0.5;
	float diffuse_clamped    = max( 0., diffuse_raw);
	float brightness         = mix(diffuse_clamped, diffuse_normalized, .1);
	
		//--------- making my own splatmap
	vec4 splat_map_from_noise_tex = textureLod(noise_tex, _UV, lod);
	float pattern_mask = smoothstep(0.1 + 0.2 * _UV.y, 0.32, splat_map_from_noise_tex.r);
	float rock_mask = pattern_mask * smoothstep(0.55, 0.67, splat_map_from_noise_tex.r);
	pattern_mask *= (1. - rock_mask);
	float m = (1. - (pattern_mask + rock_mask));
	float magma_mask = 1. - (m * (1. - smoothstep(0.95, 1., m)));
	
	COLOR = vec4( vec3(magma_mask), 1.);
	
	//--------- rotating for pattern to look better
	vec2 uv = 2. * _UV - 1.;
	uv = rot(3.14 / 2.) * uv;
	uv *= 3.0;

	// -- bg patter
	vec3 bg_pattern_sample = textureLod(tex_that_maps_ontop_of_rock, uv, lod).xyz;
	vec3 bg_pattern =  bg_pattern_sample * pattern_mask;

	// cel shading y/n  -----------------
	brightness = floor(brightness * 6.) / 6.;
	//
	vec3 rock_tex_sample = textureLod(rock_tex, 2. * _UV, lod).xyz;
	vec3 bg_rock = rock_tex_sample * rock_mask;


	vec4 noise_sample = textureLod(noise_tex, _UV + vec2(0., 0.01 * TIME), lod);
	vec4 magma_sample = textureLod(magma_tex, rotated_UV(_UV, rot(0.1 * TIME)) * noise_sample.r, lod);

	vec3 bg_magma = magma_sample.xyz * (1. - (pattern_mask + rock_mask));

	float magma_glow = 1. / magma_mask;
	magma_glow *= 0.1;
	magma_glow = pow(magma_glow, 0.8);
	vec3 magma_glow_col = magma_glow * vec3(1.0, 0.5, 0.25);

	vec3 col = bg_pattern + bg_rock;
	vec3 out_col = col * brightness + 0.7 * bg_magma + magma_glow_col;

	out_col = 1.0 - exp( -out_col );
	COLOR = vec4(out_col, 1.);
	//COLOR = vec4(vec3(UV, 0.), 1.);
}

//void fragment() {
    //COLOR = vec4(UV, 0.0, 1.0);
//}

//void fragment() {
	//// texture repeats every (1.0 / tiling_scale) world units
	//
    //vec2 world_uv = world_position * tiling_scale;
    //vec2 ps = TEXTURE_PIXEL_SIZE * blur_amount;
    //
    //vec4 col = vec4(0.0);
    //col += texture(TEXTURE, world_uv + vec2(-ps.x, -ps.y));
    //col += texture(TEXTURE, world_uv + vec2( ps.x, -ps.y));
    //col += texture(TEXTURE, world_uv + vec2(-ps.x,  ps.y));
    //col += texture(TEXTURE, world_uv + vec2( ps.x,  ps.y));
    //col += texture(TEXTURE, world_uv) * 2.0;
    //
    //COLOR = col / 6.0;
//}