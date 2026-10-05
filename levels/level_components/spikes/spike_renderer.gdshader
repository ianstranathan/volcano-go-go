shader_type canvas_item;

varying vec2 uv_scale;
void vertex() {
	uv_scale = INSTANCE_CUSTOM.rg;
	// Called for every vertex the material is visible on.
}

uniform sampler2D spike_tex: repeat_enable, filter_nearest;
void fragment() {
	vec2 uv = UV * uv_scale;	
	vec4 spike_tex_sample = texture(spike_tex, vec2(uv.x, -uv.y));
	COLOR = spike_tex_sample;
}
