shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.5, 0.45, 0.35, 1.0);
uniform int surface_kind = 0; // masonry, iron, wood, cloth, floor
varying vec3 local_position;
varying vec3 local_normal;

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise21(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1, 0)), u.x),
               mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), u.x), u.y);
}
void vertex() {
    local_position = VERTEX;
    local_normal = NORMAL;
}
void fragment() {
    vec3 n = abs(normalize(local_normal));
    vec2 p = n.y > 0.65 ? local_position.xz : (n.x > 0.65 ? local_position.zy : local_position.xy);
    float grain = noise21(p * 23.0);
    float broad = noise21(p * 2.7);
    float height = grain * 0.05;
    vec3 color = tint.rgb * mix(0.72, 1.03, grain * 0.3 + broad * 0.7);
    float rough = 0.88;
    float metal = 0.0;
    if (surface_kind == 0) {
        vec2 brick = p * vec2(1.7, 3.4);
        brick.x += mod(floor(brick.y), 2.0) * 0.5;
        vec2 f = fract(brick);
        vec2 edge = min(f, 1.0 - f);
        float mortar = 1.0 - smoothstep(0.015, 0.055, min(edge.x, edge.y));
        color *= mix(0.82, 1.06, hash21(floor(brick)));
        color = mix(color, tint.rgb * 0.30, mortar);
        height += 0.1 * (1.0 - mortar);
    } else if (surface_kind == 1) {
        float rust = smoothstep(0.49, 0.74, broad + grain * 0.15);
        color = mix(tint.rgb * (0.65 + grain * 0.5), vec3(0.30, 0.135, 0.057), rust * 0.76);
        rough = mix(0.38, 0.93, rust);
        metal = 0.76 * (1.0 - rust);
        height = grain * 0.025 + rust * 0.025;
    } else if (surface_kind == 2) {
        float wood = noise21(p * vec2(42.0, 2.0));
        float line = sin(p.x * 88.0 + broad * 9.0) * 0.5 + 0.5;
        color = tint.rgb * mix(0.68, 1.04, wood * 0.78 + line * 0.22);
        height = wood * 0.035;
    } else if (surface_kind == 3) {
        float weave = sin(p.x * 150.0) * sin(p.y * 150.0);
        float fade = 1.0 - smoothstep(0.018, 0.065, max(length(dFdx(p)), length(dFdy(p))));
        color = tint.rgb * (0.8 + broad * 0.2 + weave * 0.15 * fade);
        height = weave * 0.006 * fade;
        rough = 1.0;
    } else {
        vec2 cell = fract(p * 0.65);
        float seam = 1.0 - smoothstep(0.0, 0.014, min(min(cell.x, 1.0-cell.x), min(cell.y, 1.0-cell.y)));
        color *= 1.0 - seam * 0.48;
        rough = mix(0.48, 0.96, broad);
        height -= seam * 0.065;
    }
    // Derivative bump gives relief in Compatibility/WebGL without extra maps.
    vec3 dx = dFdx(VERTEX), dy = dFdy(VERTEX);
    vec3 r1 = cross(dy, NORMAL), r2 = cross(NORMAL, dx);
    float det = dot(dx, r1);
    NORMAL = normalize(NORMAL - sign(det) * (dFdx(height)*r1 + dFdy(height)*r2) / max(abs(det), 0.00001));
    ALBEDO = color;
    ROUGHNESS = rough;
    METALLIC = metal;
}
