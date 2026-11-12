shader_type canvas_item;
render_mode unshaded;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

// ═══════════════════════════════════════════════════════════
// TEXTURES & UNIFORMS
// ═══════════════════════════════════════════════════════════

group_uniforms textures;
//uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;

varying vec2 local_position;

void vertex() {
    local_position = VERTEX;
}

uniform float texture_scale = 0.001;

uniform float density : hint_range(0.1, 0.9) = 0.5;
uniform float column_stretch_y : hint_range(0.1, 10.0) = 0.2;
uniform float column_sharpness : hint_range(0.1, 5.0) = 1.2;
uniform sampler2D rock_normal : hint_roughness_normal, filter_linear_mipmap, repeat_enable;

uniform float lod = 0.0;
uniform float cel_steps = 6.0;

const vec3 light_dir = vec3(0.0, 1.0, 0.0);

void fragment() {
    vec2 _UV = local_position * 0.01;
    float base = texture(noise_tex, _UV).r;
    
	float n0 = texture(noise_tex, _UV).r;
    vec2 column_uv = vec2(_UV.x, _UV.y * column_stretch_y + 0.02 * n0);
    vec2 warped_column_uv = column_uv;
    
    float n1 = texture(noise_tex, warped_column_uv).r;
    float n2 = texture(noise_tex, warped_column_uv * 2.0).r;
    
    float ridge1 = 1.0 - abs(n1 * 2.0 - 1.0);
    float ridge2 = 1.0 - abs(n2 * 2.0 - 1.0);
    float cavern_columns = pow(ridge1 * ridge2, column_sharpness);
    float combined = mix(base, cavern_columns, 0.8);
    float fw = fwidth(combined);
    float rock_mask = smoothstep(density - fw, density + fw, combined);

	// -------------------------------------------------------------------------
	
	vec3 normal = textureLod(rock_normal, _UV, lod).xyz;
	float diffuse_raw        = dot(normal,  light_dir); //normalize(light_pos)); 
	float diffuse_normalized = diffuse_raw * 0.5 + 0.5;
	float diffuse_clamped    = max( 0., diffuse_raw);
	float brightness         = mix(diffuse_clamped, diffuse_normalized, .1);
	brightness = floor(brightness * 6.) / 6.;
	
	// -------------------------------------------------------------------------
	float magma_glow = 1. / smoothstep(0., 1.05 , pow(combined + 0.02 * abs(sin(1. * TIME - 0.1 * n0 * TIME)), 1.1));
	magma_glow = smoothstep(1.8, 2.5, magma_glow);
	magma_glow = pow(magma_glow, 0.5);
	vec3 magma_glow_col = magma_glow * 4. * vec3(1.0, 0.5, 0.25);

    COLOR = vec4(magma_glow_col * brightness, rock_mask);
	//COLOR = vec4(vec3(1.), 1.);
}