shader_type canvas_item;
render_mode unshaded;

/*
this is a simple gaussian blur shader tha
also works with how canvas groups composite items in a buffer
*/

uniform sampler2D screen_texture :
    hint_screen_texture, repeat_disable, filter_linear;

uniform float blur_radius : hint_range(0.0, 10.0) = 2.0;

void fragment() 
{
    vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);

    if (c.a > 0.0001) 
	{
        c.rgb /= c.a;
    }

    vec2 pixel_size = SCREEN_PIXEL_SIZE * blur_radius;

    vec4 blurred = vec4(0.0);

    // 3x3 Gaussian-style kernel.
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            float weight = (x == 0 ? 2.0 : 1.0)
                         * (y == 0 ? 2.0 : 1.0);

            blurred += texture(
                screen_texture,
                SCREEN_UV + vec2(float(x), float(y)) * pixel_size
            ) * weight;
        }
    }

    blurred /= 16.0;

    if (blurred.a > 0.0001) {
        blurred.rgb /= blurred.a;
    }

    COLOR *= blurred;
}
