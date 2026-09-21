shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float thickness : hint_range(0.001, 0.5) = 0.05;
//uniform vec4 color : source_color = vec4(1.0);
uniform float selected = 0.;
uniform float recharging = 0.;

const vec3 selected_col = vec3(1.0);
const vec3 deselected_col = vec3(0.2);

void fragment() {
	vec2 p = UV;
	vec2 q = p - 0.5;

	// Distance to the square boundary.
	float d = 0.5 - max(abs(q.x), abs(q.y));

	// Smooth outline.
	float outline = 1.0 - smoothstep(
		thickness,
		thickness + fwidth(d),
		d
	);

	// Distances to the four sides.
	float top_dist    = abs(q.y + 0.5);
	float right_dist  = abs(q.x - 0.5);
	float bottom_dist = abs(q.y - 0.5);
	float left_dist   = abs(q.x + 0.5);

	// Identify which side is closest using step functions instead of branches.
	// 1.0 where the condition is true, 0.0 otherwise.
	float is_top    = step(top_dist, min(min(right_dist, bottom_dist), left_dist));
	float is_right  = step(right_dist, min(min(top_dist, bottom_dist), left_dist));
	float is_bottom = step(bottom_dist, min(min(top_dist, right_dist), left_dist));
	float is_left   = 1.0 - min(1.0, is_top + is_right + is_bottom); // Fallback for safety

	// Calculate the perimeter coordinates for each individual side.
	float p_top    = (q.x + 0.5) * 0.25;
	float p_right  = 0.25 + (q.y + 0.5) * 0.25;
	float p_bottom = 0.50 + (0.5 - q.x) * 0.25;
	float p_left   = 0.75 + (0.5 - q.y) * 0.25;

	// Blend them together branchlessly based on the active side weights.
	float perimeter = (p_top * is_top) +
	                  (p_right * is_right) +
	                  (p_bottom * is_bottom) +
	                  (p_left * is_left);

	// Smooth progression along the perimeter.
	float aa = fwidth(perimeter);

	float fill = 1.0 - smoothstep(
		progress,
		progress + aa,
		perimeter
	);
	vec3 col = (selected_col * selected  + deselected_col * (1. - selected)) + 0.5 * abs(sin(4. * TIME)) * recharging;
	COLOR = vec4(col * outline * fill, 1.) ;
}




// ------------------------------------------------------- cool

//shader_type canvas_item;
//
//uniform float progress : hint_range(0.0, 1.0) = 0.0;
//uniform float thickness : hint_range(0.0, 0.5) = 0.05;
//uniform vec4 color : source_color = vec4(1.0);
//
//void fragment() {
    //vec2 p = UV;
//
    //// Distance to the nearest edge.
    //float edge = min(
        //min(p.x, 1.0 - p.x),
        //min(p.y, 1.0 - p.y)
    //);
//
    //// Square outline.
    //float outline = step(edge, thickness);
//
    //// ------------------------------------------------------------
    //// Distance along the perimeter.
    ////
    //// Top:    0.00 -> 0.25
    //// Right:  0.25 -> 0.50
    //// Bottom: 0.50 -> 0.75
    //// Left:   0.75 -> 1.00
    ////
    //// Reflecting the coordinates lets us express the four sides
    //// without branching.
    //// ------------------------------------------------------------
//
    //vec2 q = p;
//
    //// Determine which quadrant/side we're on using step().
    //vec2 side = step(vec2(0.5), p);
//
    //// Fold the square so that each side can be treated uniformly.
    //vec2 f = mix(q, 1.0 - q, side);
//
    //// Pick the coordinate running along the current side.
    //float along = mix(f.x, f.y, step(f.x, f.y));
//
    //// This gives the perimeter position around the square.
    //float perimeter = (
        //min(p.x, 1.0 - p.x) < min(p.y, 1.0 - p.y)
            //? p.y
            //: p.x
    //);
//
    //float fill = step(perimeter, progress);
//
    //COLOR = color * outline * fill;
//}
