shader_type canvas_item;

uniform float joint_edge_px;
uniform float overlap_px;

void fragment() {
	float atlas_y = UV.y / TEXTURE_PIXEL_SIZE.y;
	COLOR.a *= smoothstep(joint_edge_px, joint_edge_px + overlap_px, atlas_y);
}
