shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

uniform vec4 src_col: source_color;

// this was just a hand rolled way to remove  a textures unwanted
// colors or bg
// can throw this way if not being used
void fragment() {
	vec2 uv = 2. * UV - 1.;
	COLOR = vec4( COLOR.r * src_col.xyz, COLOR.r);
	COLOR.a *= src_col.w;
}

