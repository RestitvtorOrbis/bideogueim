extends RefCounted

const CATALOG_PATH := "res://resources/human_character_catalog.tres"
const BODY_PATHS := [
	"res://assets/characters/quaternius/models/Superhero_Male_FullBody.gltf",
	"res://assets/characters/quaternius/models/Superhero_Female_FullBody.gltf",
]
const HAIRSTYLE_PATHS := [
	"res://assets/characters/quaternius/hairstyles/Hair_Beard.gltf",
	"res://assets/characters/quaternius/hairstyles/Hair_Buns.gltf",
	"res://assets/characters/quaternius/hairstyles/Hair_Buzzed.gltf",
	"res://assets/characters/quaternius/hairstyles/Hair_BuzzedFemale.gltf",
	"res://assets/characters/quaternius/hairstyles/Hair_Long.gltf",
	"res://assets/characters/quaternius/hairstyles/Hair_SimpleParted.gltf",
]
const EYEBROW_PATHS := [
	"res://assets/characters/quaternius/hairstyles/Eyebrows_Regular.gltf",
	"res://assets/characters/quaternius/hairstyles/Eyebrows_Female.gltf",
]
const PUBLIC_CLIPS := [&"Idle_Loop", &"Walk_Loop", &"Jog_Fwd_Loop"]
const PALETTE_NAMES := ["civilian", "hostile", "player"]
const PALETTE_KEYS := [
	"palette_id",
	"body_material_id",
	"accent_material_id",
	"skin_material_id",
	"hair_material_id",
]


func run() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var loaded := load(CATALOG_PATH)
	results.append(_result("human character catalog resource loads", loaded != null))
	var catalog := loaded as HumanCharacterCatalog
	results.append(_result("human character catalog has expected type", catalog != null))
	if catalog != null:
		_append_path_results(results, "body", catalog.body_paths, BODY_PATHS)
		_append_path_results(results, "hairstyle", catalog.hairstyle_paths, HAIRSTYLE_PATHS)
		_append_path_results(results, "eyebrow", catalog.eyebrow_paths, EYEBROW_PATHS)
		results.append(_result("public clip count is exact", catalog.public_clips.size() == PUBLIC_CLIPS.size()))
		results.append(_result("public clip identifiers are exact", catalog.public_clips == PUBLIC_CLIPS))
		_append_palette_results(results, catalog.shared_palette_metadata)

	results.append(_result("string seeds are deterministic", HumanCharacterCatalog.stable_seed("character") == HumanCharacterCatalog.stable_seed("character")))
	results.append(_result("integer seeds are deterministic", HumanCharacterCatalog.stable_seed(12345) == HumanCharacterCatalog.stable_seed(12345)))
	results.append(_result("positive integer seeds preserve their value", HumanCharacterCatalog.stable_seed(12345) == 12345))
	var unsalted_index := HumanCharacterCatalog.variant_index("salt-probe", 2147483647, 0)
	var salted_index := HumanCharacterCatalog.variant_index("salt-probe", 2147483647, 1)
	results.append(_result("variant index is deterministic with a salt", salted_index == HumanCharacterCatalog.variant_index("salt-probe", 2147483647, 1)))
	results.append(_result("salt changes variant selection", unsalted_index != salted_index))
	results.append(_result("default salt matches explicit zero", HumanCharacterCatalog.variant_index("salt-probe", 97) == HumanCharacterCatalog.variant_index("salt-probe", 97, 0)))
	results.append(_result("zero count returns negative one", HumanCharacterCatalog.variant_index("character", 0) == -1))
	results.append(_result("negative count returns negative one", HumanCharacterCatalog.variant_index("character", -1) == -1))
	results.append(_result("positive variant indices stay in range", _positive_indices_are_in_range()))
	return results


func _append_path_results(results: Array[Dictionary], label: String, actual: Array, expected: Array) -> void:
	results.append(_result("%s path count is exact" % label, actual.size() == expected.size()))
	results.append(_result("%s paths are exact" % label, actual == expected))
	results.append(_result("%s paths are unique" % label, _all_unique(actual)))
	for path in expected:
		results.append(_result("%s path exists: %s" % [label, path], FileAccess.file_exists(path)))


func _append_palette_results(results: Array[Dictionary], metadata: Dictionary) -> void:
	for palette_name in PALETTE_NAMES:
		var palette: Variant = metadata.get(palette_name, null)
		results.append(_result("%s palette metadata exists" % palette_name, palette is Dictionary))
		if palette is Dictionary:
			for key in PALETTE_KEYS:
				results.append(_result("%s palette has %s" % [palette_name, key], palette.has(key)))


func _positive_indices_are_in_range() -> bool:
	for value in ["civilian", "hostile", "player", 0, 12345]:
		for count in [1, 2, 7, 97]:
			for salt in [0, 1, 7]:
				var index := HumanCharacterCatalog.variant_index(value, count, salt)
				if index < 0 or index >= count:
					return false
	return true


func _all_unique(values: Array) -> bool:
	var seen := {}
	for value in values:
		seen[value] = true
	return seen.size() == values.size()


func _result(name: String, passed: bool) -> Dictionary:
	return {"name": name, "passed": passed}
