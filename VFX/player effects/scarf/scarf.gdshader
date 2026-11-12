
shader_type canvas_item;
render_mode unshaded;

const int MAX_POINTS = 16;

uniform int point_count = 0;
uniform vec2 chain_points[MAX_POINTS];
uniform float chain_widths[MAX_POINTS];

uniform vec4 scarf_color : source_color = vec4(0.78, 0.16, 0.25, 1.0);
uniform vec4 shadow_color : source_color = vec4(0.40, 0.08, 0.18, 1.0);
uniform vec4 outline_color : source_color = vec4(0.12, 0.10, 0.16, 1.0);

uniform vec2 renderer_size = vec2(128.0, 128.0);
uniform float outline_width = 1.0;
uniform float blend_radius = 1.5;
uniform float antialias_width = 0.75;
uniform float shadow_offset = 1.0;
uniform float shadow_strength = 0.35;

uniform sampler2D noise_tex: repeat_enable;
// Distance to a tapered line segment.
// Width can differ at either end of the segment.
float segment_sdf(
    vec2 p,
    vec2 a,
    vec2 b,
    float radius_a,
    float radius_b
) {
    vec2 ab = b - a;
    float denom = max(dot(ab, ab), 0.0001);

    float t = clamp(dot(p - a, ab) / denom, 0.0, 1.0);

    vec2 closest = a + ab * t;
    float radius = mix(radius_a, radius_b, t);

    return length(p - closest) - radius;
}


// Polynomial smooth minimum: merges adjacent segments.
float smooth_min(float a, float b, float k) {
    k = max(k, 0.001);

    float h = max(k - abs(a - b), 0.0) / k;

    return min(a, b) - h * h * k * 0.25;
}


// Signed distance to the entire scarf silhouette.
float scarf_sdf(vec2 p) {
    float d = 100000.0;

    for (int i = 0; i < MAX_POINTS - 1; i++) {
        if (i >= point_count - 1) {
            break;
        }

        float segment_d = segment_sdf(
            p,
            chain_points[i],
            chain_points[i + 1],
            chain_widths[i] * 0.5,
            chain_widths[i + 1] * 0.5
        );

        if (i == 0) {
            d = segment_d;
        } else {
            d = smooth_min(d, segment_d, blend_radius);
        }
    }

    return d;
}


uniform float tear_scale = 12.0;
uniform float tear_threshold = 0.65;
uniform float tear_softness = 0.08;
uniform float tear_strength = 1.0;

float tear_mask(vec2 uv) {
    // Stretch noise horizontally to create streaks along X.
    vec2 noise_uv = vec2(
        uv.x * tear_scale,
        uv.y * 2.0
    );

    float noise = texture(noise_tex, noise_uv).r;

    // Threshold noise to create intermittent ripped sections.
    float mask = smoothstep(
        tear_threshold - tear_softness,
        tear_threshold + tear_softness,
        noise
    );

    return mix(1.0, mask, tear_strength);
}

void fragment() {
    // Aspect-correct coordinates
  	vec2 p = 2. * UV - 1.;

    float t = TIME;

    // Scarf shape
    float x = p.x;
    float y = p.y;

    // Flowing wave deformation
    float wave =
        sin(x * 7.0 - t * 2.0) * 0.07 +
        sin(x * 13.0 - t * 3.0) * 0.025;

    float center = wave + x * x * 0.15;

    // Taper the scarf at its ends
    float width = 0.12 * (1.0 - smoothstep(0.2, 0.55, abs(x)));

    float dist = abs(y - center);

    // Scarf mask
    float mask = 1.0 - smoothstep(
        width - 0.005,
        width + 0.005,
        dist
    );

    // Fabric gradient
    float edge = smoothstep(width, 0.0, dist);

    vec3 darkRed = vec3(0.45, 0.015, 0.025);
    vec3 red = vec3(0.85, 0.035, 0.025);
    vec3 orange = vec3(1.0, 0.25, 0.06);

    vec3 color = mix(darkRed, red, edge);
    color = mix(color, orange, edge * 0.45);

    // Subtle fabric highlights
    float folds = sin(y * 100.0 + x * 15.0 - t * 2.0);
    color += 0.025 * folds;

    // Magical glow
    float glow = exp(-dist * 25.0);
    color += vec3(1.0, 0.12, 0.025) * glow * 0.12;

    // Background
    vec3 bg = vec3(0.035, 0.025, 0.055);

    vec3 finalColor = mix(bg, color, mask);

    COLOR = vec4(finalColor, 1.0);
}
