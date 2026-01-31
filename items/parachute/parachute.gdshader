shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

float sdCircle( vec2 p, float r )
{
    return length(p) - r;
}

float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h );
}
const int num_strings = 5;
const float circ_rad = 0.5;
uniform sampler2D noise_tex: repeat_enable;

vec2 line_parab_pos(vec2 uv, float r, float dx_times_i)
{
	// float a = -1.
	float b = -1. / (-r + dx_times_i);
	float c = (r * r) + 1.0;
	float discrim = (b * b) + 4. * c; // always positive
	float sqrt_discr = sqrt(discrim);
	return 0.5 * vec2( b - sqrt_discr, b + sqrt_discr);
}

float parab_fn( float _x, float r, float noise)
{
	return -(_x + r)* (_x - r) + noise; 
}
void fragment() 
{
	vec2 uv = 2. * UV - 1.;
	uv.y *= -1.;
	vec2 polar = vec2(length(uv), atan(uv.y, uv.x));
	
	vec4 noise_sample = texture(noise_tex, 0.1 * polar - vec2(TIME, 0.));
	// ----------------------------------
	float d = sdCircle(uv, 0.5);
	float f = parab_fn(uv.x, circ_rad, -0.1 * noise_sample.r);
	
	float string_mask = 1.0;
	float dx = 2. * circ_rad/ float(num_strings);
	for( int i = 0; i <= num_strings; i++){
		//float x_pos = -circ_rad + dx * float(i);
		vec2 line_parab_xs = line_parab_pos(uv, circ_rad, dx * float(i));
		float x_pos = uv.x > 0.0 ? line_parab_xs.y : line_parab_xs.x;
		float fn_at_x_pos = parab_fn(x_pos, circ_rad, -0.1 * noise_sample.r);
		float s = sdSegment(uv, vec2(0., -1.), vec2(x_pos, fn_at_x_pos));
		string_mask *= smoothstep(0., 0.05, s);
	}
	float bottom_cut = smoothstep(f, f + 0.05, uv.y);
	
	d = (1. - smoothstep(0., 0.05 + 0.1 * noise_sample.r, d)) * bottom_cut;
	
	float s = (1. - string_mask);
	float mask = s + d;
	COLOR = vec4(vec3(1., 0.6, 0.2) * mask, mask);
	
	
	//COLOR = vec4( vec3( smoothstep(f, f + 0.1, uv.y)), 1.);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
