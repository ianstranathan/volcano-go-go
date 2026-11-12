shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

uniform float blur_radius : hint_range(0.0, 10.0) = 6.0;

void fragment() {
    vec2 tex_size = TEXTURE_PIXEL_SIZE * blur_radius;
    vec4 color = vec4(0.0);
    
    // Center tap
    color += texture(TEXTURE, UV) * 0.227027;
    
    // Axis taps
    color += texture(TEXTURE, UV + vec2(tex_size.x, 0.0)) * 0.157305;
    color += texture(TEXTURE, UV - vec2(tex_size.x, 0.0)) * 0.157305;
    color += texture(TEXTURE, UV + vec2(0.0, tex_size.y)) * 0.157305;
    color += texture(TEXTURE, UV - vec2(0.0, tex_size.y)) * 0.157305;
    
    // Diagonal taps
    color += texture(TEXTURE, UV + vec2(tex_size.x, tex_size.y)) * 0.035939;
    color += texture(TEXTURE, UV - vec2(tex_size.x, tex_size.y)) * 0.035939;
    color += texture(TEXTURE, UV + vec2(tex_size.x, -tex_size.y)) * 0.035939;
    color += texture(TEXTURE, UV - vec2(tex_size.x, -tex_size.y)) * 0.035939;
	
	float gray = dot(color, vec4(0.299, 0.587, 0.114, 1.));
	vec4 final_color = mix(vec4(vec3(gray), 1.), color, 0.8);
    COLOR = final_color;
}

