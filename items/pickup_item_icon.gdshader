shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

uniform vec4 src_col: source_color;

void fragment() {
	vec2 uv = 2. * UV - 1.;
	vec4 tex_sample = texture(TEXTURE, UV);
	float mask = 1. - smoothstep(0.95, 0.99, length(uv));
	COLOR = tex_sample + (1. - smoothstep(0.1,0.5, tex_sample.r)) * src_col;
	COLOR.a = mask;
}


