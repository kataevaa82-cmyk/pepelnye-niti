shader_type canvas_item;
void fragment() {
    float left = 1.0 - smoothstep(0.12, 0.63, UV.x);
    float edge = smoothstep(0.20, 0.72, length(UV - vec2(0.52, 0.48)));
    COLOR = vec4(vec3(0.018, 0.029, 0.030), clamp(left * 0.50 + edge * 0.28, 0.0, 0.80));
}
