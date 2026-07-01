shader_type spatial;
// Neon grid drawn on the ground plane from world-space coordinates, so the
// grid lines stay put regardless of the plane's UVs. Unshaded + emissive so the
// WorldEnvironment glow blooms the lines.
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 line_color : source_color = vec3(0.0, 1.0, 0.95);
uniform vec3 bg_color : source_color = vec3(0.02, 0.02, 0.08);
uniform float cell_size = 1.0;
uniform float line_width = 0.03;
uniform float glow = 2.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz / cell_size;
	vec2 f = fract(uv);
	vec2 dist_to_line = min(f, 1.0 - f); // 0 at integer grid lines
	float d = min(dist_to_line.x, dist_to_line.y);
	float line = 1.0 - smoothstep(0.0, line_width, d);
	ALBEDO = bg_color;
	EMISSION = line_color * glow * line;
}
