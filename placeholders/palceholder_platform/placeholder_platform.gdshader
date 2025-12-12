shader_type canvas_item;

uniform vec4 source_col: source_color;

void fragment() {
	COLOR = source_col;
}

