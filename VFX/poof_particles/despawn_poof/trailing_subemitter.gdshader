shader_type canvas_item;

varying float id;

const vec2 ATLAS_SIZE = vec2(2.0, 2.0);

float hash(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
    id = float(INSTANCE_ID);
}

mat2 rot( float angle){
	return mat2( vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
}

void fragment() {
    float r = hash(id);
	
    float frame = floor(r * 4.0);
	
    float column = mod(frame, 2.0);
    float row = floor(frame / 2.0);
	
	vec2 uv = rot(r * TAU) * UV;
    vec2 atlas_uv = (UV + vec2(column, row)) / vec2(2.0);

    vec4 tex_sample = texture(TEXTURE, atlas_uv);
	
	float grey_white_dilenation = smoothstep(0.7, 1. + fwidth(tex_sample.r), tex_sample.r);
	vec3 col = mix(vec3(0.5, 0., 0.5), vec3(0.0, 0., 0.0), 1. - COLOR.a) * grey_white_dilenation +
			   vec3(0.) * (1. - grey_white_dilenation);
    COLOR = vec4(col, tex_sample.a);
	
    COLOR = vec4(col, tex_sample.a);
}
