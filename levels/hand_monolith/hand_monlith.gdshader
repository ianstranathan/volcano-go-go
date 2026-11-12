shader_type canvas_item;

uniform int is_shaking : hint_enum("No", "Yes") = 0;
uniform int is_closed : hint_enum("No", "Yes") = 0;
uniform float shake_strength : hint_range(0.0, 30.0) = 10.0;
uniform float shake_speed : hint_range(0.1, 30.0) = 15.0;

uniform sampler2D noise_tex : repeat_enable;

void vertex() {
    vec2 noise_uv = VERTEX * 0.05 + vec2(TIME * shake_speed);
    vec2 noise = texture(noise_tex, noise_uv).rg * 2.0 - 1.0;
    VERTEX.xy += noise * shake_strength * float(is_shaking);
}

uniform sampler2D closed_tex : repeat_enable;

void fragment() {
    vec4 open_color = texture(TEXTURE, UV);
    vec4 closed_color = texture(
        closed_tex,
        vec2(2., 1.) * (UV - vec2(0.5)) + vec2(0.5)
    ) * vec4(vec3(1.), step(0.25, UV.x) * step(UV.x, 0.75));

    COLOR = mix(open_color, closed_color, float(is_closed));
}

