shader_type spatial;
// Neon grid drawn on the corridor's top faces from world-space coordinates.
// Side faces are dimmed (no grid) so the raised terrace/platform blocks read as
// 3D and overlapping elevation tiers stay distinguishable. Unshaded + emissive
// so the grid lines bloom.
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 line_color : source_color = vec3(0.0, 1.0, 0.95);
uniform vec3 bg_color : source_color = vec3(0.02, 0.02, 0.08);
uniform float cell_size = 1.0;
uniform float line_width = 0.05;
uniform float glow = 0.9;
uniform float side_dim = 0.4;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	float up = clamp(world_normal.y, 0.0, 1.0);  // 1 on top faces, 0 on sides
	vec2 uv = world_pos.xz / cell_size;
	vec2 f = fract(uv);
	vec2 dist_to_line = min(f, 1.0 - f);
	float d = min(dist_to_line.x, dist_to_line.y);
	float line = (1.0 - smoothstep(0.0, line_width, d)) * up;  // grid only on tops
	ALBEDO = bg_color * mix(side_dim, 1.0, up);
	EMISSION = line_color * glow * line;
}
