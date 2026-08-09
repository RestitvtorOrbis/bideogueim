class_name CityMeshes
extends RefCounted

## Shared meshes and materials used by the city builder. All repeated detail is
## rendered through MultiMesh so a large city does not become a large scene tree.

static func make_materials() -> Dictionary:
	var neon_colors := neon_palette()
	return {
		"ground": _pbr_material(
			"res://assets/textures/sparse_grass/sparse_grass_diff_1k.jpg",
			"res://assets/textures/sparse_grass/sparse_grass_nor_gl_1k.jpg",
			"res://assets/textures/sparse_grass/sparse_grass_rough_1k.jpg",
			Color("#789b68"), 0.96, 0.0, Vector3(5.0, 5.0, 5.0)
		),
		"road": _pbr_material(
			"res://assets/textures/clean_asphalt/clean_asphalt_diff_1k.jpg",
			"res://assets/textures/clean_asphalt/clean_asphalt_nor_gl_1k.jpg",
			"res://assets/textures/clean_asphalt/clean_asphalt_rough_1k.jpg",
			Color("#515965"), 0.9, 0.02, Vector3(8.0, 8.0, 8.0)
		),
		"sidewalk": _pbr_material(
			"res://assets/textures/concrete_pavement_02/concrete_pavement_02_diff_1k.jpg",
			"res://assets/textures/concrete_pavement_02/concrete_pavement_02_nor_gl_1k.jpg",
			"res://assets/textures/concrete_pavement_02/concrete_pavement_02_rough_1k.jpg",
			Color("#b8b7ad"), 0.82, 0.0, Vector3(2.2, 2.2, 2.2)
		),
		"road_marking": _solid_material(Color("#d9bd72"), 0.66),
		"park": _pbr_material(
			"res://assets/textures/sparse_grass/sparse_grass_diff_1k.jpg",
			"res://assets/textures/sparse_grass/sparse_grass_nor_gl_1k.jpg",
			"res://assets/textures/sparse_grass/sparse_grass_rough_1k.jpg",
			Color("#5b8d50"), 0.98, 0.0, Vector3(3.5, 3.5, 3.5)
		),
		"park_path": _pbr_material(
			"res://assets/textures/concrete_pavement_02/concrete_pavement_02_diff_1k.jpg",
			"res://assets/textures/concrete_pavement_02/concrete_pavement_02_nor_gl_1k.jpg",
			"res://assets/textures/concrete_pavement_02/concrete_pavement_02_rough_1k.jpg",
			Color("#a69883"), 0.88, 0.0, Vector3(3.0, 3.0, 3.0)
		),
		"building_0": _pbr_material(
			"res://assets/textures/concrete_pavement_02/concrete_pavement_02_diff_1k.jpg",
			"res://assets/textures/concrete_pavement_02/concrete_pavement_02_nor_gl_1k.jpg",
			"res://assets/textures/concrete_pavement_02/concrete_pavement_02_rough_1k.jpg",
			Color("#c3b09b"), 0.82, 0.06, Vector3(4.0, 4.0, 4.0)
		),
		"building_1": _pbr_material(
			"res://assets/textures/concrete_pavement_02/concrete_pavement_02_diff_1k.jpg",
			"res://assets/textures/concrete_pavement_02/concrete_pavement_02_nor_gl_1k.jpg",
			"res://assets/textures/concrete_pavement_02/concrete_pavement_02_rough_1k.jpg",
			Color("#718694"), 0.86, 0.08, Vector3(4.5, 4.5, 4.5)
		),
		"building_2": _pbr_material(
			"res://assets/textures/factory_brick/factory_brick_diff_1k.jpg",
			"res://assets/textures/factory_brick/factory_brick_nor_gl_1k.jpg",
			"res://assets/textures/factory_brick/factory_brick_rough_1k.jpg",
			Color("#a05e4c"), 0.9, 0.04, Vector3(3.2, 3.2, 3.2)
		),
		"building_3": _pbr_material(
			"res://assets/textures/factory_brick/factory_brick_diff_1k.jpg",
			"res://assets/textures/factory_brick/factory_brick_nor_gl_1k.jpg",
			"res://assets/textures/factory_brick/factory_brick_rough_1k.jpg",
			Color("#435b6d"), 0.78, 0.12, Vector3(3.8, 3.8, 3.8)
		),
		"building_roof": _solid_material(Color("#28313a"), 0.88),
		"glass": _emissive_material(Color("#9ed8eb"), Color("#71b7d7"), 0.52),
		"neon_cyan": _emissive_material(neon_colors[0], neon_colors[0], 6.0),
		"neon_magenta": _emissive_material(neon_colors[1], neon_colors[1], 6.0),
		"neon_purple": _emissive_material(neon_colors[2], neon_colors[2], 6.0),
		"trunk": _solid_material(Color("#5b3f2b"), 0.98),
		"leaves": _noise_material(Color("#367b54"), 0.88, 0.3, 0.18),
		"lamp": _solid_material(Color("#27313b"), 0.72),
		"lamp_glow": _emissive_material(Color("#ffd891"), Color("#ffb548"), 0.9),
		"bench": _solid_material(Color("#76543a"), 0.9),
		"planter": _solid_material(Color("#5b6668"), 0.86),
	}

static func neon_palette() -> Array[Color]:
	return [
		Color("#42f4ff"),
		Color("#ff3fc8"),
		Color("#a66bff"),
	]

static func box_mesh(size: Vector3, material: Material) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	return mesh

static func cylinder_mesh(radius: float, height: float, material: Material, radial_segments: int = 8) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	mesh.material = material
	return mesh

static func sphere_mesh(radius: float, material: Material) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = material
	return mesh

static func make_multimesh(mesh: Mesh, transforms: Array, colors: Array = []) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	if not colors.is_empty():
		multimesh.use_colors = true
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
		if not colors.is_empty() and index < colors.size():
			multimesh.set_instance_color(index, colors[index])
	return multimesh

static func _solid_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

static func _emissive_material(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := _solid_material(color, 0.34)
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material

static func _building_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := _solid_material(color, roughness)
	material.metallic = 0.06
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return material

static func _noise_material(color: Color, roughness: float, frequency: float, contrast: float) -> StandardMaterial3D:
	var material := _solid_material(color, roughness)
	var noise := FastNoiseLite.new()
	noise.frequency = frequency
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.noise = noise
	texture.seamless = true
	material.albedo_texture = texture
	material.uv1_scale = Vector3(contrast, contrast, contrast)
	return material

static func _pbr_material(albedo_path: String, normal_path: String, roughness_path: String, tint: Color, roughness: float, metallic: float, uv_scale: Vector3) -> StandardMaterial3D:
	var material := _solid_material(tint, roughness)
	material.metallic = metallic
	material.albedo_texture = load(albedo_path) as Texture2D
	material.normal_enabled = true
	material.normal_texture = load(normal_path) as Texture2D
	material.roughness_texture = load(roughness_path) as Texture2D
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.uv1_scale = uv_scale
	return material
