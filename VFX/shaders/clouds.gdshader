shader_type canvas_item;

const vec2 ATLAS_SIZE = vec2(3.0, 1.0);

float hash(float n) {
    return fract(sin(n * 12.9898) * 43758.5453);
}

uniform sampler2D atlas;
void fragment() {
    float sum = COLOR.r + COLOR.g + COLOR.b;

    float particle_id = COLOR.r / max(sum, 0.0001);
    float r = hash(particle_id);

    float frame = floor(r * 3.0);

    float col = mod(frame, 3.0);
    float row = floor(frame / 3.0);

    vec2 atlas_uv = (UV + vec2(col, row)) / ATLAS_SIZE;

    vec4 tex_sample = texture(atlas, atlas_uv);
    COLOR = vec4(tex_sample.xyz, tex_sample.a * COLOR.a);
}