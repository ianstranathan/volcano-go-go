//shader_type canvas_item;
//
//uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
//uniform float blur_amount : hint_range(0.0, 5.0) = 2.0;
//
//void fragment() {
    //// Samples the texture with a level of detail (LOD) blur
    //vec4 col = textureLod(TEXTURE, UV, blur_amount);
    //COLOR = col;
//}

shader_type canvas_item;

// Adjust the blur radius. Higher numbers spread it out more, 
// but too high will cause banding/artifacts in a 9-tap.
uniform float blur_radius : hint_range(0.0, 10.0) = 2.0;

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

    COLOR = color;
}