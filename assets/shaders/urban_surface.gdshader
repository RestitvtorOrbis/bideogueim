shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_tint : source_color = vec4(0.12, 0.16, 0.22, 1.0);
uniform vec4 accent_tint : source_color = vec4(0.12, 0.72, 0.9, 1.0);
uniform float grid_scale = 0.28;
uniform float accent_strength : hint_range(0.0, 1.0) = 0.32;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.68;
uniform float surface_metallic : hint_range(0.0, 1.0) = 0.08;
uniform float emission_strength : hint_range(0.0, 4.0) = 0.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 cell = abs(fract(world_position * grid_scale) - vec3(0.5));
	float seam = 1.0 - smoothstep(0.43, 0.50, max(cell.x, cell.z));
	float variation = 0.5 + 0.5 * sin(world_position.x * 0.13 + world_position.z * 0.17);
	vec3 surface = mix(base_tint.rgb, accent_tint.rgb, seam * accent_strength);
	surface *= 0.92 + variation * 0.08;
	ALBEDO = surface;
	ROUGHNESS = surface_roughness;
	METALLIC = surface_metallic;
	if (emission_strength > 0.0) {
		EMISSION = accent_tint.rgb * seam * emission_strength;
	}
}
