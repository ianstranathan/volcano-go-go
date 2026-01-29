shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}
float rand(float x) {
    return fract(sin(x * 12.9898) * 43758.5453);
}

uniform sampler2D noise_tex: repeat_enable;
uniform vec4 light_blue: source_color;
uniform vec4 dark_blue: source_color;

void fragment() {
	vec2 uv = UV;
	uv.x += uv.y;
	vec4 noise = texture(noise_tex, uv * vec2(1., 0.05));

    float column = floor(uv.x * 20.0);
    float streak = step(0.5 + 0.1 * noise.r, rand(column));

	float mask = noise.r * streak;
	float t = noise.r * noise.r;
	t = 2. * t - 1.;
	vec3 col = mix(vec3(1.), dark_blue.xyz, t * t ) * mask + (1. - mask) * light_blue.xyz;

	/* ---- ICE SHINE (material-based) ---- */

	// Screen-space noise to avoid tiling seams
	vec2 suv = 0.5 * SCREEN_UV * vec2(3.0, 1.5);
	suv.x += TIME * 0.01;
	suv.y += TIME * 0.01;

	float shine_noise = texture(noise_tex, suv).r;

	// Soft sparkle modulation
	float shine = smoothstep(0.6, 0.9, shine_noise);
	shine *= noise.r;   // lock to internal structure
	shine *= mask;

	col += 10. * vec3(0.25, 0.35, 0.45) * shine * 0.35;

	/* ----------------------------------- */

    COLOR = vec4(col, 1.0);
}
