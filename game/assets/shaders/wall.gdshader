shader_type spatial;
// Wall blocks (rendered via MultiMesh, per-instance COLOR). Fake shading gives
// depth cues without depending on scene lights: side faces are dimmed relative
// to top faces (so overlapping blocks read as 3D), and blocks are tinted a
// little brighter with height so elevation layers are distinguishable.
render_mode unshaded, cull_disabled;

uniform float side_dim = 0.5;      // brightness of vertical faces vs top faces
uniform float height_tint = 0.05;  // extra brightness per world-unit of height

varying vec3 icolor;
varying vec3 world_normal;
varying float world_y;

void vertex() {
	icolor = COLOR.rgb;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float up = clamp(world_normal.y, 0.0, 1.0);      // 1 on top faces, 0 on sides
	float face = mix(side_dim, 1.0, up);
	float ht = 1.0 + height_tint * world_y;
	ALBEDO = icolor * face * ht;
}
