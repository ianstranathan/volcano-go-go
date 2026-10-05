shader_type canvas_item;

void vertex() {
}

float sdSegment(in vec2 p, in vec2 a, in vec2 b)
{
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float radius : hint_range(0.05, 0.55) = 0.22;
uniform float squash_amount : hint_range(0.0, 3.0) = 1.5;

uniform float height = 0.355;
uniform vec4 src_col : source_color;

void fragment()
{
    vec2 p = 2.0 * UV - 1.0;
    p.y *= -1.0;

    // -----------------------------------------
    // Volume-preserving vertical elongation
    // -----------------------------------------

    //float scale_y = 1.0 + progress * squash_amount;
    //float scale_x = 1.0 / scale_y;
//
    //// Pin the bottom of the shape.
    //float vertical_shift = radius * (1.0 - scale_y);
    //p.y -= vertical_shift;
	
	
    // Stretch vertically, compress horizontally.
    //p.x /= scale_x;
    //p.y /= scale_y;
//
    //// -----------------------------------------
    //// Segment SDF
    //// -----------------------------------------
//
    //float d = sdSegment(
        //p,
        //vec2(0.0, height),
        //vec2(0.0, -height)
    //);
//
    //float aa = 2.0 * fwidth(d);
//
    //float m = 1.0 - smoothstep(
        //radius,
        //radius + aa,
        //d
    //);


	// Volume-preserving elongation.
	// No positional offset: the blob expands/contracts
	// around its center.
	float scale_y = 1.0 + progress * squash_amount;
	float scale_x = 1.0 / scale_y;

	p.x /= scale_x;
	p.y /= scale_y;

	float d = sdSegment(
	    p,
	    vec2(0.0, height),
	    vec2(0.0, -height)
	);

	float aa = 2.0 * fwidth(d);

	float m = 1.0 - smoothstep(
	    radius,
	    radius + aa,
	    d
	);

    COLOR = vec4(src_col.xyz, m);
}

//shader_type canvas_item;
//
//void vertex() {
	//// Called for every vertex the material is visible on.
//}
//
//float sdSegment( in vec2 p, in vec2 a, in vec2 b )
//{
    //vec2 pa = p-a, ba = b-a;
    //float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    //return length( pa - ba*h );
//}
//
//// just match it up and make it analytic later
////uniform float dummy_burn_timer: hint_range(0.0, 5.0, 0.1);
//uniform float height;
//uniform float radius; // 0.355
//
//uniform vec4 src_col: source_color;
//
//void fragment() {
	//vec2 uv = 2. * UV - 1.;
	//float d = sdSegment(uv, vec2(0., height), vec2(0., -height));
	//float m = 1. - smoothstep(radius, radius + 2. * fwidth(d), d);
	//// float t = exp(-dummy_burn_timer);
//
	////vec3 col = mix(src_col.xyz, vec3(1., 0., 0.) + sin(20. * TIME), t);
	////vec3 col = src_col.xyz;
	//COLOR = vec4(src_col.xyz, m);
//}
//
////void light() {
////	// Called for every pixel for every light affecting the CanvasItem.
////	// Uncomment to replace the default light processing function with this one.
////}
