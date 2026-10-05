shader_type canvas_item;

uniform float atlas_cols = 4.0;
uniform float atlas_rows = 2.0;

// Support up to 4 players simultaneously
uniform vec2 player_positions[4]; 
uniform float current_time;
uniform float is_path = 1.0;
uniform sampler2D normal_map;

varying flat float v_gem_type;
varying float v_collect_time;
varying float v_idle_offset;
varying flat float v_collector_index;

void vertex() {
    v_gem_type = round(INSTANCE_CUSTOM.r * 7.0);
    v_idle_offset = INSTANCE_CUSTOM.g * 6.28318; // 0 to 2PI phase offset
    v_collect_time = INSTANCE_CUSTOM.b;         // 0 = resting, >0 = collected timestamp
    v_collector_index = round(INSTANCE_CUSTOM.a * 3.0); // Which player collected it (0 to 3)

    vec2 local_vertex = VERTEX;

    if (v_collect_time == 0.0) {
        // 1. IDLE STATE: Gentle floating/bobbing bounce on the ground
        float float_anim = sin(current_time * 4.0 + v_idle_offset) * 4.0;
        VERTEX.y += float_anim * is_path;
    } 
    else {
        // 2. ABSORPTION STATE: Arced Bézier path towards the specific player
        float elapsed = current_time - v_collect_time;
        float duration = 0.45; 
        float t = clamp(elapsed / duration, 0.0, 1.0);
        
        if (t >= 1.0) {
            VERTEX = vec2(0.0);
        } else {
            float u = smoothstep(0., 1., t);
            
            // Select the correct player position based on the stored index
            int p_idx = int(v_collector_index);
            vec2 target_global_pos = player_positions[0]; // fallback
            
            // Unroll or select based on index (GLSL array index must be uniform or constant in older specs, 
            // but Godot's modern Vulkan/Compatibility backends handle dynamic indexing well. 
            // To be 100% safe across all hardware, use an if-chain:)
            if (p_idx == 1) target_global_pos = player_positions[1];
            else if (p_idx == 2) target_global_pos = player_positions[2];
            else if (p_idx == 3) target_global_pos = player_positions[3];
            else target_global_pos = player_positions[0];

            vec2 local_player_pos = (inverse(MODEL_MATRIX) * vec4(target_global_pos, 0.0, 1.0)).xy;
            
            vec2 p0 = vec2(0.0);
            vec2 p2 = local_player_pos;
            
            vec2 dir_to_gem = normalize(p0 - p2 + vec2(0.001));
            float flare_angle = v_idle_offset;
            vec2 flare_dir = clamp(v_idle_offset, 1., 10.) * vec2(cos(flare_angle), sin(flare_angle));
            
            vec2 p1 = mix(p0, p2, 0.3) + (dir_to_gem * 60.0) + (flare_dir * 40.0);
            vec2 bezier_pos = pow(1.0 - u, 2.0) * p0 + 2.0 * (1.0 - u) * u * p1 + pow(u, 2.0) * p2;
            
            VERTEX = bezier_pos + (local_vertex * mix(1.0, 0.2, t));
        }
    }
}

const vec3 light_direction = vec3(-0.4, -0.5, 1.0);
uniform vec4 specular_color : source_color = vec4(1.0);
uniform float shininess : hint_range(1.0, 256.0) = 64.0;
uniform float specular_strength : hint_range(0.0, 2.0) = 1.0;

void fragment() {
    vec2 sub_uv = UV / vec2(atlas_cols, atlas_rows);
    float col = mod(v_gem_type, atlas_cols);
    float row = floor(v_gem_type / atlas_cols);
    
    vec2 atlas_offset = vec2(col / atlas_cols, row / atlas_rows);
    vec2 final_uv = sub_uv + atlas_offset;
    
    vec4 tex_color = texture(TEXTURE, final_uv);
    if (tex_color.a < 0.1) {
        discard;
    }
	

    vec3 normal = texture(normal_map, final_uv).rgb * 2.0 - 1.0;
    normal = normalize(normal);

    vec3 light_dir = normalize(light_direction);
    vec3 view_dir = vec3(0.0, 0.0, 1.0);

    // Blinn-Phong half vector.
    vec3 half_dir = normalize(light_dir + view_dir);

    float specular = pow(
        max(dot(normal, half_dir), 0.0),
        shininess
    );

    vec3 highlight = specular_color.rgb *
                     specular *
                     specular_strength;

    COLOR = vec4(tex_color.rgb + highlight, tex_color.a);
}