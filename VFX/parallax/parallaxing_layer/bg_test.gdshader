shader_type canvas_item;


varying vec2 local_position;

// 1 UV is 1000 pixels
uniform float texture_scale = 0.001;

uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D magma_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D magma_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D arabesque_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

// presumably we're going to be sampling at an LoD from the parallaxing
// layer data
uniform float lod;

// ----------------------------------------------------------------- light stuff
uniform float cel_steps = 6.0;
uniform float light_strength = 1.0;
const vec3 light_dir = vec3(0.0, 1.0, 0.0);

mat2 rotate(float _angle){
    return mat2(vec2(cos(_angle), -sin(_angle)),
                vec2(sin(_angle), cos(_angle)));
}
// we're passing real world vertex positions across the shader (interpolating
// the real world position per fragment)
void vertex() {
    local_position = VERTEX;
}
// just returns a copy of the rotated uv
vec2 rotated_UV(vec2 uv, mat2 rota){
	return rota* (uv - vec2(0.5)) + vec2(0.5);
}
void fragment() 
{
    // texture follows the parallax layer.
    vec2 _UV = local_position * texture_scale;

	// -- rock and diffuse light

	vec3 normal = textureLod(rock_normal, _UV, lod).xyz;
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
	uv = rotate(3.14 / 2.) * uv;
	uv *= 3.0;

	// -- bg patter
	vec3 bg_pattern_sample = textureLod(arabesque_tex, uv, lod).xyz;
	vec3 bg_pattern =  bg_pattern_sample * pattern_mask;

	// cel shading y/n  -----------------
	brightness = floor(brightness * 6.) / 6.;
	//
	vec3 rock_tex_sample = textureLod(rock_tex, 2. * _UV, lod).xyz;
	vec3 bg_rock = rock_tex_sample * rock_mask;


	vec4 noise_sample = textureLod(noise_tex, _UV + vec2(0., 0.01 * TIME), lod);
	vec4 magma_sample = textureLod(magma_tex, rotated_UV(_UV, rotate(0.1 * TIME)) * noise_sample.r, lod);

	vec3 bg_magma = magma_sample.xyz * (1. - (pattern_mask + rock_mask));

	float magma_glow = 1. / magma_mask;
	magma_glow *= 0.1;
	magma_glow = pow(magma_glow, 0.8);
	vec3 magma_glow_col = magma_glow * vec3(1.0, 0.5, 0.25);

	vec3 col = bg_pattern + bg_rock;
	vec3 out_col = col * brightness + 0.7 * bg_magma + magma_glow_col;

	out_col = 1.0 - exp( -out_col );
	COLOR = vec4(out_col, 1.);
}