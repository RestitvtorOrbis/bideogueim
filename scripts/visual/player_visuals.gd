extends Node3D
class_name PlayerVisuals

const PLAYER_VISUAL_SEED := 17062026
const PLAYER_VISUAL_HEIGHT := 1.82
const PLAYER_ROLE := &"player"
const CHARACTER_CATALOG := preload("res://resources/human_character_catalog.tres")


func _ready() -> void:
	var visual_root := get_parent() as Node3D
	if visual_root == null:
		return
	var human_visual := visual_root.get_node_or_null("HumanCharacterVisual") as HumanCharacterVisual
	if human_visual == null:
		return
	human_visual.configure_from_catalog(CHARACTER_CATALOG, PLAYER_VISUAL_SEED, PLAYER_ROLE, PLAYER_VISUAL_HEIGHT, true)
