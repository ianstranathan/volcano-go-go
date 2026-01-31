shader_type canvas_item;

void vertex() {
	VERTEX += vec2(sign(VERTEX.x), sign(VERTEX.y)) * 12. * sin(10. * TIME);
}

mat2 rotate2d(float _angle){
	return mat2(vec2(cos(_angle), -sin(_angle)), vec2(sin(_angle), cos(_angle)));
}

float sdStar( in vec2 p, in float r, in int n, in float m)
{
    // next 4 lines can be precomputed for a given shape
    float an = 3.141593/float(n);
    float en = 3.141593/m;  // m is between 2 and n
    vec2  acs = vec2(cos(an),sin(an));
    vec2  ecs = vec2(cos(en),sin(en)); // ecs=vec2(0,1) for regular polygon

    float bn = mod(atan(p.x,p.y),2.0*an) - an;
    p = length(p)*vec2(cos(bn),abs(sin(bn)));
    p -= r*acs;
    p += ecs*clamp( -dot(p,ecs), 0.0, r*acs.y/ecs.y);
    return length(p)*sign(p.x);
}

void fragment() {
	vec2 uv = 2. * UV - 1.;
	uv = rotate2d(TIME) * uv;
	// friendly star
	float star_sdf = abs(sdStar(uv, 0.75, 6, 3) - 0.05);
	float friendly_reticle_mask = 1.5 * smoothstep(.6, 1.1, pow((1. - star_sdf), 1.5));
	
	// friendly reticle color
	float dist = 1.0/ star_sdf;
	dist *= 0.1;
	dist = pow(dist, 0.8);
	vec3 friendly_reticle_col = dist * vec3(1.0, 0.5, 0.25) + 0.2 * sin(10. * TIME);
	
	COLOR = vec4(friendly_reticle_col, friendly_reticle_mask);
}

