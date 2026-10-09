shader_type canvas_item;
//render_mode blend_;

const vec2 ATLAS_SIZE = vec2(2.0, 2.0);

float hash(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

uniform sampler2D atlas;

float avg( vec3 c){
	return (c.r + c.g + c.b) / 3.;
}

void vertex(){
	INSTANCE_CUSTOM;
}
void fragment() 
{
    float sum = COLOR.r + COLOR.g + COLOR.b;
    float particle_id = COLOR.r / max(sum, 0.0001);
    float r = hash(particle_id);

    float frame = floor(r * 4.0);

    float column = mod(frame, 2.0);
    float row = floor(frame / 2.0);

    vec2 atlas_uv = (UV + vec2(column, row)) / ATLAS_SIZE;

    vec4 tex_sample = texture(atlas, atlas_uv);
	
	float grey_white_dilenation = smoothstep(0.7, 1. + fwidth(tex_sample.r), tex_sample.r);
	vec3 col = mix(vec3(0.5, 0., 0.5), vec3(0.0, 0., 0.0), 1. - COLOR.a) * grey_white_dilenation +
			   vec3(0.) * (1. - grey_white_dilenation);
    COLOR = vec4(col, tex_sample.a);
	//COLOR = vec4(1.);
}