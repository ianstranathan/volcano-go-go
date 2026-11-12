shader_type canvas_item;


float EaseOutQuad(float x)
{
  return 1.0 - (1.0-x) * (1.0 -x );
}

float EaseInQuad(float x)
{
   return x * x;
}
float cel_shade(float value, float bands) {
    return floor(value * bands) / (bands - 1.0);
}
uniform sampler2D tex: repeat_enable;
uniform sampler2D noise_tex: repeat_enable;
void fragment() {
	vec2 uv = 2. * UV - 1.;
	uv.y *= -1.;
	vec4 noise_sample = texture(noise_tex, uv * vec2(0.1, 0.2) + vec2(0.5 * TIME, 0.));
	vec4 tex_sample = texture(tex, (vec2(UV.x, -UV.y)) + vec2(0.4, 0.) + 0.05 * noise_sample.r);


	float black_mask = 1.0 - smoothstep(0.01 - fwidth(tex_sample.r), 0.01 + fwidth(tex_sample.r), tex_sample.r);

	vec3 col = mix((1. - tex_sample.r) * vec3(1., 0., 1.) + vec3(tex_sample.r) ,
					noise_sample.r * vec3(.5, 0., 0.),
					black_mask - 0.5);
	COLOR = vec4(col, tex_sample.r + noise_sample.r) * UV.x + 0.1;


}