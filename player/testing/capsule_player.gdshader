shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h );
}

// just match it up and make it analytic later
uniform float dummy_burn_timer: hint_range(0.0, 5.0, 0.1);
uniform float radius;
uniform float height;

uniform vec4 src_col: source_color;

void fragment() {
	vec2 uv = 2. * UV - 1.;
	float d = sdSegment(uv, vec2(0., 0.45), vec2(0., -0.45));
	float m = 1. - smoothstep(0.3, 0.35, d);
	float t = exp(-dummy_burn_timer);
	
	vec3 col = mix(src_col.xyz, vec3(1., 0., 0.) + sin(20. * TIME), t);
	COLOR = vec4(col, m);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
