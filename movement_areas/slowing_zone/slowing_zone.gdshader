shader_type canvas_item;

void vertex() {
	// Called for every vertex the material is visible on.
}

float sdfCircle(vec2 p, float r)
{
    return length(p) - r;
}

vec3 background(vec2 uv)
{
    float g = 0.5 + 0.5 * sin(uv.x * 4.0 + TIME);
    float b = 0.5 + 0.5 * sin(uv.y * 3.0 - TIME * 1.3);
    return vec3(g * 0.4 + 0.2, b * 0.4 + 0.3, 0.6);
}

void fragment()
{
    // Normalized coords (-1..1)
    vec2 uv = 2. * UV - 1.;

    float radius = 0.98;
    float d = sdfCircle(uv, radius);

    // Anti-aliased mask
    float edge = fwidth(d);
    float mask = 1.0 - smoothstep(0.0, edge, d);

    // ---------- Fake sphere normal ----------
    vec2 n2 = uv / radius;
    float r2 = dot(n2, n2);
    float nz = sqrt(max(0.0, 1.0 - r2));
    vec3 normal = normalize(vec3(n2, nz));

    vec3 viewDir = vec3(0.0, 0.0, 1.0);

    // ---------- Fresnel ----------
    float fresnel = pow(1.0 - dot(normal, viewDir), 4.0);

    // Push rim to silhouette
    float rimMask = smoothstep(0.6, 1.0, r2);
    fresnel *= rimMask;

    // ---------- Fake refraction ----------
    float wobble = sin(TIME * 2.0 + r2 * 12.0) * 0.02;
    vec2 refractOffset = normal.xy * (0.06 + wobble) * fresnel;

    vec2 bgUV = uv + refractOffset;
    vec3 bg = background(bgUV);

    // ---------- Bubble shading ----------
    vec3 rimColor = vec3(1.0, 0.6, .2);
    vec3 bubbleTint = vec3(0.7, 0.9, 1.0);

    vec3 color = bg;
    color = mix(color, bubbleTint, 0.08);
    color += rimColor * fresnel * 1.2;

    // ---------- Transparency ----------
    float thickness = nz; // thicker at center
    float alpha = fresnel * 0.7 + thickness * 0.15;
    alpha *= mask;

    COLOR = vec4(color, 1.5 * alpha);
}
