shader_type canvas_item;
void fragment() {
    float edge = smoothstep(0.30, 0.72, length((UV - 0.5) * vec2(0.95, 1.0)));
    COLOR = vec4(0.015, 0.024, 0.026, edge * 0.35);
}
