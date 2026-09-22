shader_type canvas_item;

uniform float progress : hint_range(0.0, 3.) = 0.0;
uniform float radius : hint_range(0.05, 0.55) = 0.22;
uniform float squash_amount : hint_range(0.0, 3.0) = 1.5;
uniform float rebound_amount : hint_range(0.0, 1.0) = 0.35;

uniform sampler2D noise_tex: repeat_enable;
uniform sampler2D magma_tex: repeat_enable;

float smin( float a, float b, float k )
{
    k *= 1.0;
    float r = exp2(-a/k) + exp2(-b/k);
    return -k*log2(r);
}

void fragment()
{
	vec2 p = 2. * UV - 1.;
	p.y *= -1.;

	//
	//float parab = 1. - pow(2. * progress - 1., 2.);
	//parab = clamp(parab, 0., 1);
	//float sinusoid = 0.3 * sin(4. * PI * progress);
	//sinusoid *= step(1., progress);
	//float d = parab * (1. - step(1., progress)) + step(1., progress) * smin(sinusoid, parab, 0.3);
	float t = progress; // mod(TIME, 3.);
	//t = t * t;
	//float d = exp(-2. * (t - 0.225)) * sin(2. * PI * t);
	float d = 1.57 * exp(-4. * progress) * sin( 4. * PI * progress);
	float width = 1.0 + d * squash_amount;

	//  reciprocal scaling preserves area: width * height ≈ 1
	float height = 1.0 / width;


	// pinning to bottom
	float vertical_shift = radius * (1.0 - height);
	p.y += vertical_shift;

	// Apply the volume-preserving deformation.
	p.x /= width;
	p.y /= height;


	/*
	    -----------------------------------------
	    SOFT BLOB DEFORMATION
	    -----------------------------------------

	    A tiny nonlinear widening around the equator
	    prevents it from looking like a mechanically
	    scaled ellipse.
	*/

	float normalized_y = clamp(p.y / radius, -1.0, 1.0);

	float equator = 1.0 - normalized_y * normalized_y;

	float soft_bulge =
		equator *
		d * 0.10;

	p.x /= 1.0 + soft_bulge;


	vec4 noise_sample = texture(noise_tex, p);
	float sdf = length(p) - radius;
	float aa = fwidth(sdf);
	// the mask
	float alpha = 1.0 - smoothstep(-aa, aa, sdf);

	// -- everything else is just playing around
	float n1 = texture(noise_tex, 0.2 * p).r;
	float n2 = texture(noise_tex, 0.5 * p * 2.0 + vec2(4.1, 2.7)).r;

	// --
	float combined = 2.0 * n1 * n2;
	float edge_aa = fwidth(combined);
	float rock_mask =
	smoothstep(0.6, 0.6 + edge_aa, combined);
	float pos = abs(combined - 0.3 + 0.2 * sin(2. * TIME));

	// division by zero
	pos = max(pos, edge_aa);

	 // glow
	float dist = 1.0 / pos;
	dist *= 0.1;
	dist = pow(dist, 0.8);

	vec3 glow_color = dist * vec3(1.0, 0.5, 0.25);
	glow_color = 1.0 - exp(-glow_color);
	float glow_radius = 0.5;
	float glow = 1.0 - smoothstep(0.0, glow_radius, pos);

	glow_color *= glow;

	vec4 magma_tex_sample = texture(magma_tex, 0.5 * p);
	vec3 color = magma_tex_sample.xyz + glow_color + (1. - rock_mask) * texture(magma_tex, p).xyz;

	COLOR = vec4((1. - length(p)) * color, alpha);
}