shader_type canvas_item;

render_mode blend_add;

uniform sampler2D noise_tex;

uniform float spark_width : hint_range(0.001, 0.05) = 0.012;
uniform float min_length : hint_range(0.0, 1.0) = 0.25;
uniform float max_length : hint_range(0.0, 1.5) = 0.85;
uniform float min_radius : hint_range(0.0, 0.5) = 0.03;
uniform float max_radius : hint_range(0.0, 0.5) = 0.20;

// How quickly the spark disappears along its length.
uniform float attenuation : hint_range(0.1, 20.0) = 7.0;

// Glow radius and intensity.
uniform float glow_radius : hint_range(0.001, 0.5) = 0.12;
uniform float glow_strength : hint_range(0.0, 5.0) = 1.5;

uniform vec4 flash_color : source_color = vec4(1.0);


// ------------------------------------------------------------
// Noise lookup
// ------------------------------------------------------------

float noise(float x) {
    return texture(
        noise_tex,
        vec2(fract(x), 0.5)
    ).r;
}

float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h );
}

void fragment() {

    vec2 p = UV * 2.0 - 1.0;
	p *= 2.;
    // Minimum distance to ANY spark.
    float total_sdf = 1000.0;

    // Bright spark contribution.
    float spark_mask = 0.0;


    // ------------------------------------------------------------
    // Five radial sparks
    // ------------------------------------------------------------

    for (int i = 0; i < 5; i++) {

        float id = float(i);

        float n0 = noise(id * 0.173 + 0.13);
        float n1 = noise(id * 0.173 + 4.71);
        float n2 = noise(id * 0.173 + 9.31);


        // ----------------------------------------
        // Roughly radial distribution
        // with random angular jitter.
        // ----------------------------------------

        float base_angle =
            id / 5.0 * TAU;

        float angle_jitter =
            (n0 - 0.5)
            * (TAU / 5.0)
            * 0.8;

        float angle =base_angle + angle_jitter;


        vec2 dir = vec2(cos(angle),sin(angle));
        // ----------------------------------------
        // Random radius and length
        // ----------------------------------------
        float start = mix(min_radius,max_radius,n1);
        float l = mix(min_length, max_length, n2);
        float end = start + l;
        vec2 a = dir * start;
        vec2 b = dir * end;
		float d = sdSegment(p, a, b);

        // Keep the closest spark for glow.
        total_sdf = min(total_sdf,d);

        //float aa = fwidth(d);
    }


  	float dist = 1.0/ total_sdf;
	dist *= 0.01;
	dist = pow(dist, 0.5);

    float final_alpha = spark_mask + dist * dist;

    final_alpha = clamp(final_alpha, 0.0,1.0);


    COLOR = vec4(flash_color.rgb, pow(flash_color.a * final_alpha, 1.2)
    );
}
