shader_type canvas_item;

uniform vec2 lamp_pos = vec2(0.5, -0.5);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float stretch_amount = 2.0;
uniform float squeeze_amount = 1.5;

void fragment() {
	// 1. Map global sprite-sheet UV to local frame UV (0.0 to 1.0 within the current frame)
	vec2 local_uv = UV;

	// Discard pixels outside the current frame bounds
	if (any(lessThan(local_uv, vec2(0.0))) || any(greaterThan(local_uv, vec2(1.0)))) {
		discard;
	}

	float k = max(1.0 - progress, 0.001);         // uniform shrink about the lamp

	// Distance from the lamp to the farthest frame corner (using local frame coordinates)
	float R = length(max(abs(lamp_pos), abs(lamp_pos - 1.0)));

	// One fixed funnel axis (lamp -> frame center)
	vec2 axis = normalize(vec2(0.5) - lamp_pos);
	vec2 perp = vec2(-axis.y, axis.x);

	vec2 d = local_uv - lamp_pos;
	float r = length(d);
	float x = r / (R * k);                        // radius relative to the shrinking envelope
	if (x > 0.8) { 
		COLOR = vec4(0.0);
		//return;
	}

	// Tail stretch
	float q = 1.0 / (1.0 + stretch_amount * progress);
	vec2 ds = d / max(r, 1e-5) * R * pow(x, q);

	// Nozzle pinch
	float pinch = max(mix(1.0, pow(x, squeeze_amount), progress), 0.02);
	float a = dot(ds, axis);
	float l = dot(ds, perp) / pinch;

	// Calculated source point in local frame space
	vec2 src_local = lamp_pos + axis * a + perp * l;

	if (any(lessThan(src_local, vec2(0.0))) || any(greaterThan(src_local, vec2(1.0)))) 
	{
		COLOR = vec4(0.0);
	} else {
		// 2. Convert local source UV back to sprite-sheet space before sampling texture
		vec2 src_sheet = src_local;
		COLOR = texture(TEXTURE, src_sheet);
	}
}