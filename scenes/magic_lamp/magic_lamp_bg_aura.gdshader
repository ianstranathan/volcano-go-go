shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.3, 1.0); // Warm magical gold
uniform float glow_thickness : hint_range(0.0, 20.0) = 4.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float pulse_intensity : hint_range(0.0, 1.0) = 0.4;

void vertex(){
	VERTEX.xy += 2. * sin(pulse_speed * TIME) * vec2(sign(VERTEX.x), sign(VERTEX.y));
}
void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);

    // Calculate smooth pulsing factor using sine wave and TIME
    float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_intensity;
    float current_thickness = glow_thickness * pulse;

    vec2 size = TEXTURE_PIXEL_SIZE * current_thickness;

    // Sample surrounding pixels to find the silhouette edge
    float max_alpha = 0.0;
    for (float x = -2.0; x <= 2.0; x += 1.0) {
        for (float y = -2.0; y <= 2.0; y += 1.0) {
            vec2 offset = vec2(x, y) * size * 0.25;
            max_alpha = max(max_alpha, texture(TEXTURE, UV + offset).a);
        }
    }

    // Branchless logic:
    // 1. Check if we are outside the original texture (tex_color.a < 0.1) -> step(tex_color.a, 0.1)
    // 2. Check if we are near the edge (max_alpha > 0.1) -> step(0.1, max_alpha)
    float is_outline = step(tex_color.a, 0.1) * step(0.1, max_alpha);

    // Prepare the outline color result
    vec4 outline_result = vec4(glow_color.rgb, glow_color.a * max_alpha);

    // Interpolate seamlessly between the original texture and the outline without any 'if' statements
    COLOR = mix(tex_color, outline_result, is_outline);
}