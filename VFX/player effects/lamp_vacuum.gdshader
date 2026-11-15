shader_type canvas_item;

uniform vec2 lamp_pos = vec2(0.5, -0.5);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float stretch_amount = 2.0;
uniform float squeeze_amount = 1.5;

uniform vec2 frame_offset = vec2(0.0);
uniform vec2 frame_size = vec2(1.0);

// Outline uniforms
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0) = 1.0;

// Pass TEXTURE as a sampler2D parameter so the helper function can sample it
bool is_pixel_opaque(vec2 current_uv, sampler2D source_tex) {
	vec2 local_uv = (current_uv - frame_offset) / frame_size;

	if (any(lessThan(local_uv, vec2(0.0))) || any(greaterThan(local_uv, vec2(1.0)))) {
		return false;
	}

	float k = max(1.0 - progress, 0.001);
	float R = length(max(abs(lamp_pos), abs(lamp_pos - 1.0)));
	vec2 axis = normalize(vec2(0.5) - lamp_pos);
	vec2 perp = vec2(-axis.y, axis.x);

	vec2 d = local_uv - lamp_pos;
	float r = length(d);
	float x = r / (R * k);
	if (x > 1.) {
		return false;
	}

	float q = 1.0 / (1.0 + stretch_amount * progress);
	vec2 ds = d / max(r, 1e-5) * R * pow(x, q);

	float pinch = max(mix(1.0, pow(x, squeeze_amount), progress), 0.02);
	float a = dot(ds, axis);
	float l = dot(ds, perp) / pinch;

	vec2 src_local = lamp_pos + axis * a + perp * l;

	if (any(lessThan(src_local, vec2(0.0))) || any(greaterThan(src_local, vec2(1.0)))) {
		return false;
	}

	vec2 src_sheet = src_local * frame_size + frame_offset;
	return texture(source_tex, src_sheet).a > 0.1;
}

void fragment() {
	// 1. Map global sprite-sheet UV to local frame UV (0.0 to 1.0 within the current frame)
	vec2 local_uv = (UV - frame_offset) / frame_size;

	bool inside = true;
	// Discard/mark outside the current frame bounds
	if (any(lessThan(local_uv, vec2(0.0))) || any(greaterThan(local_uv, vec2(1.0)))) {
		inside = false;
	}

	float k = max(1.0 - progress, 0.001);         // uniform shrink about the lamp

	// Distance from the lamp to the farthest frame corner
	float R = length(max(abs(lamp_pos), abs(lamp_pos - 1.0)));

	// One fixed funnel axis (lamp -> frame center)
	vec2 axis = normalize(vec2(0.5) - lamp_pos);
	vec2 perp = vec2(-axis.y, axis.x);

	vec2 d = local_uv - lamp_pos;
	float r = length(d);
	float x = r / (R * k);                        // radius relative to the shrinking envelope
	if (inside && x > 1.) {
		inside = false;
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

	if (inside && (any(lessThan(src_local, vec2(0.0))) || any(greaterThan(src_local, vec2(1.0))))) {
		inside = false;
	}

	if (inside) {
		// 2. Convert local source UV back to global sprite-sheet space before sampling texture
		vec2 src_sheet = src_local * frame_size + frame_offset;
		vec4 tex_color = texture(TEXTURE, src_sheet);

		if (tex_color.a > 0.1) {
			COLOR = tex_color;
		} else {
			inside = false;
		}
	}

	// If the pixel is transparent, check neighboring pixels to render the outline
	if (!inside) {
		vec2 pixel_size = TEXTURE_PIXEL_SIZE * outline_width;
		bool outline = false;

		// 8-directional neighbor checks for a smooth outline
		vec2 offsets[8] = vec2[](
			vec2(pixel_size.x, 0.0),
			vec2(-pixel_size.x, 0.0),
			vec2(0.0, pixel_size.y),
			vec2(0.0, -pixel_size.y),
			vec2(pixel_size.x, pixel_size.y),
			vec2(-pixel_size.x, pixel_size.y),
			vec2(pixel_size.x, -pixel_size.y),
			vec2(-pixel_size.x, -pixel_size.y)
		);

		for (int i = 0; i < 8; i++) {
			// Supply TEXTURE explicitly to the helper function here
			if (is_pixel_opaque(UV + offsets[i], TEXTURE)) {
				outline = true;
				break;
			}
		}

		if (outline) {
			COLOR = outline_color;
		} else {
			COLOR = vec4(0.0);
		}
	}
}
//shader_type canvas_item;
//
//uniform vec2 lamp_pos = vec2(0.5, -0.5);
//uniform float progress : hint_range(0.0, 1.0) = 0.0;
//uniform float stretch_amount = 2.0;
//uniform float squeeze_amount = 1.5;
//
//uniform vec2 frame_offset = vec2(0.0);
//uniform vec2 frame_size = vec2(1.0);
//
//void fragment() {
	//// 1. Map global sprite-sheet UV to local frame UV (0.0 to 1.0 within the current frame)
	//vec2 local_uv = (UV - frame_offset) / frame_size;
//
	//// Discard pixels outside the current frame bounds
	//if (any(lessThan(local_uv, vec2(0.0))) || any(greaterThan(local_uv, vec2(1.0)))) {
		//discard;
	//}
//
	//float k = max(1.0 - progress, 0.001);         // uniform shrink about the lamp
//
	//// Distance from the lamp to the farthest frame corner (using local frame coordinates)
	//float R = length(max(abs(lamp_pos), abs(lamp_pos - 1.0)));
//
	//// One fixed funnel axis (lamp -> frame center)
	//vec2 axis = normalize(vec2(0.5) - lamp_pos);
	//vec2 perp = vec2(-axis.y, axis.x);
//
	//vec2 d = local_uv - lamp_pos;
	//float r = length(d);
	//float x = r / (R * k);                        // radius relative to the shrinking envelope
	//if (x > 0.8) {
		//COLOR = vec4(0.0);
		////return;
	//}
//
	//// Tail stretch
	//float q = 1.0 / (1.0 + stretch_amount * progress);
	//vec2 ds = d / max(r, 1e-5) * R * pow(x, q);
//
	//// Nozzle pinch
	//float pinch = max(mix(1.0, pow(x, squeeze_amount), progress), 0.02);
	//float a = dot(ds, axis);
	//float l = dot(ds, perp) / pinch;
//
	//// Calculated source point in local frame space
	//vec2 src_local = lamp_pos + axis * a + perp * l;
//
	//if (any(lessThan(src_local, vec2(0.0))) || any(greaterThan(src_local, vec2(1.0))))
	//{
		//COLOR = vec4(0.0);
	//} else {
		//// 2. Convert local source UV back to global sprite-sheet space before sampling texture
		//vec2 src_sheet = src_local * frame_size + frame_offset;
		//COLOR = texture(TEXTURE, src_sheet);
	//}
//}