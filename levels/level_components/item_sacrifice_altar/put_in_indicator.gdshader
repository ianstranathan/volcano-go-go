shader_type canvas_item;

uniform float pulse_speed : hint_range(0.0, 20.0) = 6.0;
uniform float pulse_intensity : hint_range(-0.5, 0.5) = 0.08;
uniform vec4 arrow_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform float line_width : hint_range(0.001, 0.1) = 0.015;
uniform float arrow_head_length : hint_range(0.01, 0.3) = 0.08;
uniform float arrow_head_width : hint_range(0.01, 0.5) = 0.15; // Independent width control
uniform float aspect_ratio = 1.0; 

// 2D Box SDF for a crisp, flat-ended shaft
float sdBox(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// 2D Triangle SDF (Inigo Quilez)
float sdTriangle(vec2 p, vec2 p0, vec2 p1, vec2 p2) {
	vec2 e0 = p1 - p0, v0 = p - p0;
	vec2 e1 = p2 - p1, v1 = p - p1;
	vec2 e2 = p0 - p2, v2 = p - p2;
	vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
	vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
	vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
	float s = sign(e0.x * e2.y - e0.y * e2.x);
	vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
	                 vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
	                 vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
	return -sqrt(d.x) * sign(d.y);
}

void fragment() {
	vec2 uv = UV;
	uv.x *= 3.0;
	uv.x = fract(uv.x);
	uv.x = (uv.x - 0.5) * aspect_ratio + 0.5;
	
	// 2. Sinusoidal pulsing scale factor centered at (0.5, 0.5)
	float pulse =sin(8. * TIME) * 0.1;
	float scale = 1.0 + pulse;
	vec2 p = scale * (uv - vec2(0.5, 0.5)) + vec2(0.5, 0.5);
	
	// Arrow layout coordinates
	vec2 tip = vec2(0.5, 0.7);
	vec2 start = vec2(0.5, 0.2);
	vec2 dir = vec2(0.0, 1.0); // Pointing straight down
	
	// 3. Shaft defined as a true Box SDF
	vec2 shaft_end = tip - dir * arrow_head_length;
	vec2 shaft_center = (start + shaft_end) * 0.5;
	vec2 shaft_half_size = vec2(line_width * 0.5, length(shaft_end - start) * 0.5);
	float d_shaft = sdBox(p - shaft_center, shaft_half_size);
	
	// 4. Triangle SDF for the arrowhead with decoupled length and width
	vec2 head_tip = tip;
	vec2 head_base_center = tip - dir * arrow_head_length;
	vec2 perp = vec2(1.0, 0.0); // Horizontal axis vector
	vec2 head_left = head_base_center + perp * (arrow_head_width * 0.5);
	vec2 head_right = head_base_center - perp * (arrow_head_width * 0.5);
	
	float d_tri = sdTriangle(p, head_tip, head_left, head_right);
	
	// Combine shapes via union (min)
	float d = min(d_shaft, d_tri);
	
	// Smooth antialiasing mask using fwidth
	float aa = fwidth(d);
	float mask = 1.0 - smoothstep(0.0, aa, d);
	
	COLOR = arrow_color;
	COLOR.a *= mask;
}