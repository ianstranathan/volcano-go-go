shader_type canvas_item;

uniform float atlas_cols = 4.0;
uniform float atlas_rows = 2.0;

uniform vec2 player_global_position; 
uniform float current_time;

varying flat float v_gem_type;
varying float v_collect_time;
varying float v_idle_offset;

void vertex() {
    v_gem_type = round(INSTANCE_CUSTOM.r * 7.0);
    v_idle_offset = INSTANCE_CUSTOM.g * 6.28318; // 0 to 2PI phase offset
    v_collect_time = INSTANCE_CUSTOM.b;          // 0 = resting, >0 = collected timestamp

    vec2 local_vertex = VERTEX;

    if (v_collect_time == 0.0) {
        // 1. IDLE STATE: Gentle floating/bobbing bounce on the ground
        float float_anim = sin(current_time * 4.0 + v_idle_offset) * 4.0;
        VERTEX.y += float_anim;
    } 
    else {
        // 2. ABSORPTION STATE: Arced Bézier path towards the player
        float elapsed = current_time - v_collect_time;
        float duration = 0.45; // Total flight duration in seconds
        float t = clamp(elapsed / duration, 0.0, 1.0);
        
        if (t >= 1.0) {
            // Collapse scale to zero once arrived
            VERTEX = vec2(0.0);
        } else {
            // Apply custom easing: starts slow/bursts out, then hyper-accelerates into the player
            // Using a modified cubic/parabolic curve for the progress factor 'u'
            float u = smoothstep(0., 1., t);//t * t * (3.0 - 2.0 * t); // Smoothstep or custom curve
            
            // Get local model space origins
            vec2 local_player_pos = (inverse(MODEL_MATRIX) * vec4(player_global_position, 0.0, 1.0)).xy;
            
            // Define Bézier Points in Local Space:
            // P0: Original spawn/rest position (0,0 in local space of this vertex relative to its instance origin)
            vec2 p0 = vec2(0.0);
            
            // P2: The target player position
            vec2 p2 = local_player_pos;
            
            // P1: The Control Point (creates the arc/pop-away effect)
            // We calculate a vector from player to gem, and push the control point *outward* 
            // combined with a randomized directional flare based on v_idle_offset
            vec2 dir_to_gem = normalize(p0 - p2 + vec2(0.001)); // prevent zero vector division
            float flare_angle = v_idle_offset; // unique per gem
            vec2 flare_dir = clamp(v_idle_offset, 1., 10.) * vec2(cos(flare_angle), sin(flare_angle));
            
            // Control point sits midway, but offset outward away from the player plus a random flare
            vec2 p1 = mix(p0, p2, 0.3) + (dir_to_gem * 60.0) + (flare_dir * 40.0);
            
            // Quadratic Bézier Curve formula: B(u) = (1-u)^2 * P0 + 2(1-u)u * P1 + u^2 * P2
            vec2 bezier_pos = pow(1.0 - u, 2.0) * p0 + 2.0 * (1.0 - u) * u * p1 + pow(u, 2.0) * p2;
            
            // Apply vertex position shift plus local vertex geometry layout
            VERTEX = bezier_pos + (local_vertex * mix(1.0, 0.2, t));
        }
    }
}

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
    COLOR = tex_color;
}
//shader_type canvas_item;
//
//uniform float atlas_cols = 4.0;
//uniform float atlas_rows = 2.0;
//
//// Update this uniform from your GDScript every frame (or via a global script) with player position
//uniform vec2 player_global_position; 
//uniform float current_time;
//
//varying flat float v_gem_type;
//varying float v_collect_time;
//varying float v_idle_offset;
//
//void vertex() {
    //v_gem_type = round(INSTANCE_CUSTOM.r * 7.0);
    //v_idle_offset = INSTANCE_CUSTOM.g * 6.28318; // 0 to 2PI phase offset
    //v_collect_time = INSTANCE_CUSTOM.b;          // 0 = resting, >0 = collected timestamp
//
    //vec2 local_vertex = VERTEX;
//
    //if (v_collect_time == 0.0) {
        //// 1. IDLE STATE: Gentle floating/bobbing bounce on the ground
        //float float_anim = 5. * sin(current_time * 4.0 + v_idle_offset) * 4.0; //sin(current_time * 4.0 + v_idle_offset) * 4.0;
        //VERTEX.y += float_anim;
    //} 
    //else {
        //// 2. ABSORPTION STATE: Suck towards the player's position over time
        //float elapsed = current_time - v_collect_time;
        //float duration = 0.35; // Flight duration in seconds
        //float t = clamp(elapsed / duration, 0.0, 1.0);
        //
        //if (t >= 1.0) {
            //// Shrink completely to zero once arrived
            //VERTEX = vec2(0.0);
        //} else {
            //// Ease-in quadratic curve acceleration
            //t = t * t; 
            //
            //// Get the current mesh instance's world origin point
            //vec2 instance_world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
            //
            //// Transform player global position into local space relative to this MultiMeshInstance2D node
            //vec2 local_player_pos = (inverse(MODEL_MATRIX) * vec4(player_global_position, 0.0, 1.0)).xy;
            //
            //// Interpolate vertex position from its origin straight to the player
            //vec2 fly_pos = mix(local_vertex, local_player_pos + local_vertex, t);
            //
            //// Scale down smoothly as it flies into the player
            //float scale_factor = mix(1.0, 0.1, t);
            //VERTEX = fly_pos * scale_factor;
        //}
    //}
//}
//
//void fragment() {
    //vec2 sub_uv = UV / vec2(atlas_cols, atlas_rows);
    //float col = mod(v_gem_type, atlas_cols);
    //float row = floor(v_gem_type / atlas_cols);
    //
    //vec2 atlas_offset = vec2(col / atlas_cols, row / atlas_rows);
    //vec2 final_uv = sub_uv + atlas_offset;
    //
    //vec4 tex_color = texture(TEXTURE, final_uv);
    //if (tex_color.a < 0.1) {
        //discard;
    //}
    //COLOR = tex_color;
//}

// -----------------------------------------------------------------
//shader_type canvas_item;
//
//// Uniforms to define your sprite atlas layout (e.g., 4 columns, 2 rows for 8 gems)
//uniform float atlas_cols = 4.0;
//uniform float atlas_rows = 2.0;
//
//varying flat float v_gem_type;
//varying float v_anim_offset;
//
//void vertex() {
    //// INSTANCE_CUSTOM extracts the Color data sent via set_instance_custom_data
    //// r = gem type, g = animation offset
    //v_gem_type = round(INSTANCE_CUSTOM.r * 7.0); // Recover the integer ID (0 to 7)
    //v_anim_offset = INSTANCE_CUSTOM.g;
//}
//
//void fragment() {
    //// 1. Calculate UV coordinates for a single sub-rect in the atlas
    //vec2 sub_uv = UV / vec2(atlas_cols, atlas_rows);
    //
    //// 2. Find column and row index for this specific gem type
    //float col = mod(v_gem_type, atlas_cols);
    //float row = floor(v_gem_type / atlas_cols);
    //
    //// 3. Offset the UV to point to the correct sub-texture in the atlas
    //vec2 atlas_offset = vec2(col / atlas_cols, row / atlas_rows);
    //vec2 final_uv = sub_uv + atlas_offset;
    //
    //// 4. Sample the texture atlas
    //vec4 tex_color = texture(TEXTURE, final_uv);
    //
    //// Optional: handle transparent cutout bounds
    //if (tex_color.a < 0.1) {
        //discard;
    //}
    //
    //COLOR = tex_color;
//}