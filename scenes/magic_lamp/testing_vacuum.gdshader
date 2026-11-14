shader_type canvas_item;

// Fixed 4-element array for the 4 corners:
// [0] = Top Left, [1] = Top Right, [2] = Bottom Left, [3] = Bottom Right
uniform float corner_weights[4];

// The singular target position in world coordinates
uniform vec2 target_world_pos;

void vertex() {
    int current_corner = -1;
    if (UV.x < 0.1 && UV.y < 0.1) current_corner = 0; // Top Left
    else if (UV.x > 0.9 && UV.y < 0.1) current_corner = 1; // Top Right
    else if (UV.x < 0.1 && UV.y > 0.9) current_corner = 2; // Bottom Left
    else if (UV.x > 0.9 && UV.y > 0.9) current_corner = 3; // Bottom Right

    // If it's a corner vertex, check its weight from the array
    if (current_corner != -1) {
        float weight = corner_weights[current_corner];

        if (weight > 0.0) {
            vec4 local_pos = inverse(MODEL_MATRIX) * vec4(target_world_pos, 0.0, 1.0);
            // Mix between the original vertex position and the target based on the weight (0.0 to 1.0)
            VERTEX = mix(VERTEX, local_pos.xy, weight);
        }
    }
}