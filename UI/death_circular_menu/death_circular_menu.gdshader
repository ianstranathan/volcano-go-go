shader_type canvas_item;

uniform int segment_count = 8;
uniform float inner_radius = 0.3;
uniform float outer_radius = 0.7;
uniform float hover_radius_expand = 0.08;
uniform float gap = 0.02;

uniform int hovered_index = -1; // Passed directly from GDScript
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 hover_color : source_color = vec4(1.0, 0.3, 0.2, 1.0);

float get_angle(vec2 pos) {
    float a = atan(pos.y, pos.x);
    return a < 0.0 ? a + TAU : a;
}

void fragment() {
    vec2 p = 2.0 * UV - 1.0;
    float dist = length(p);
    float angle = get_angle(p);
    
    float step_angle = TAU / float(segment_count);
    int index = int(floor(angle / step_angle));
    
    // Check if this fragment belongs to the active segment
    bool is_hovered = (index == hovered_index);
    float current_outer_radius = outer_radius + (is_hovered ? hover_radius_expand : 0.0);
    
    // --- SEGMENT SHAPE & GAPS ---
    float segment_center = (float(index) + 0.5) * step_angle;
    float delta = atan(sin(angle - segment_center), cos(angle - segment_center));
    float half_step = step_angle * 0.5;
    float side_distance = dist * sin(half_step - abs(delta));
    
    // --- ANTI-ALIASED RENDERING ---
    float aa = fwidth(dist);
    float ring = smoothstep(inner_radius - aa, inner_radius + aa, dist) * 
                 (1.0 - smoothstep(current_outer_radius - aa, current_outer_radius + aa, dist));
                 
    float angle_aa = fwidth(angle);
    float sector = smoothstep((gap * 0.5), (gap * 0.5) + angle_aa, side_distance);
    float alpha = ring * sector;
    
    // Color Output
    vec3 final_color = mix(base_color.rgb, hover_color.rgb, is_hovered ? 1.0 : 0.0);
    COLOR = vec4(final_color, alpha * base_color.a);
}