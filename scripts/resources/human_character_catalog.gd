class_name HumanCharacterCatalog
extends Resource

## Static metadata contract for Quaternius human character variants.
##
## Runtime model assembly and animation loading belong to later tickets.

const BODY_PATHS: Array[String] = [
	"res://assets/characters/quaternius/models/Superhero_Male_FullBody.gltf",
	"res://assets/characters/quaternius/models/Superhero_Female_FullBody.gltf",
]

const HAIRSTYLE_PATHS: Array[String] = [
	"res://assets/characters/quaternius/hairstyles/Hair_Beard.gltf",
	"res://assets/characters/quaternius/hairstyles/Hair_Buns.gltf",
	"res://assets/characters/quaternius/hairstyles/Hair_Buzzed.gltf",
	"res://assets/characters/quaternius/hairstyles/Hair_BuzzedFemale.gltf",
	"res://assets/characters/quaternius/hairstyles/Hair_Long.gltf",
	"res://assets/characters/quaternius/hairstyles/Hair_SimpleParted.gltf",
]

const EYEBROW_PATHS: Array[String] = [
	"res://assets/characters/quaternius/hairstyles/Eyebrows_Regular.gltf",
	"res://assets/characters/quaternius/hairstyles/Eyebrows_Female.gltf",
]

const PUBLIC_CLIPS: Array[StringName] = [
	&"Idle_Loop",
	&"Walk_Loop",
	&"Jog_Fwd_Loop",
]

const SHARED_PALETTE_METADATA: Dictionary = {
	"civilian": {
		"palette_id": "civilian",
		"body_material_id": "civilian_body",
		"accent_material_id": "civilian_accent",
		"skin_material_id": "skin_default",
		"hair_material_id": "hair_default",
	},
	"hostile": {
		"palette_id": "hostile",
		"body_material_id": "hostile_body",
		"accent_material_id": "hostile_accent",
		"skin_material_id": "skin_default",
		"hair_material_id": "hair_default",
	},
	"player": {
		"palette_id": "player",
		"body_material_id": "player_body",
		"accent_material_id": "player_accent",
		"skin_material_id": "skin_default",
		"hair_material_id": "hair_default",
	},
}

@export var body_paths: Array[String] = BODY_PATHS
@export var hairstyle_paths: Array[String] = HAIRSTYLE_PATHS
@export var eyebrow_paths: Array[String] = EYEBROW_PATHS
@export var public_clips: Array[StringName] = PUBLIC_CLIPS
@export var shared_palette_metadata: Dictionary = SHARED_PALETTE_METADATA


static func stable_seed(value: Variant) -> int:
	if value is int:
		return int(value) & 0x7fffffff

	var result := 0x811c9dc5
	for byte in String(value).to_utf8_buffer():
		result = int((result ^ int(byte)) * 0x01000193) & 0x7fffffff
	return result


static func variant_index(value: Variant, count: int, salt: int = 0) -> int:
	if count <= 0:
		return -1

	var mixed := stable_seed(value) ^ (salt * 0x45d9f3b)
	mixed = int((mixed ^ (mixed >> 16)) * 0x45d9f3b) & 0x7fffffff
	mixed = int((mixed ^ (mixed >> 16)) * 0x45d9f3b) & 0x7fffffff
	return posmod(mixed, count)
