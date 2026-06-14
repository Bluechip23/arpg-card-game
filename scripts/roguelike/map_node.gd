class_name RoguelikeMapNode
extends RefCounted

## A single node on the roguelike run map (Slay-the-Spire style).

enum Type { MONSTER, ELITE, SHOP, CAMPFIRE, RANDOM, BOSS }

var id: int = -1
var type: int = Type.MONSTER
var row: int = 0          ## 0 = first floor, increases toward the boss
var col: int = 0          ## index within the row
var next_ids: Array[int] = []  ## ids of nodes reachable from this one (next row up)
var visited: bool = false ## true once the encounter has been resolved
var ui_pos: Vector2 = Vector2.ZERO  ## screen position, filled in by the map UI

static func type_id(t: int) -> String:
	match t:
		Type.MONSTER: return "monster"
		Type.ELITE: return "elite"
		Type.SHOP: return "shop"
		Type.CAMPFIRE: return "campfire"
		Type.RANDOM: return "random"
		Type.BOSS: return "boss"
	return "monster"

static func type_display_name(t: int) -> String:
	match t:
		Type.MONSTER: return "Monster"
		Type.ELITE: return "Elite"
		Type.SHOP: return "Shop"
		Type.CAMPFIRE: return "Campfire"
		Type.RANDOM: return "Unknown"
		Type.BOSS: return "Boss"
	return "Monster"

static func type_glyph(t: int) -> String:
	match t:
		Type.MONSTER: return "M"
		Type.ELITE: return "E"
		Type.SHOP: return "$"
		Type.CAMPFIRE: return "R"
		Type.RANDOM: return "?"
		Type.BOSS: return "B"
	return "M"

static func type_color(t: int) -> Color:
	match t:
		Type.MONSTER: return Color(0.78, 0.30, 0.30)
		Type.ELITE: return Color(0.85, 0.20, 0.55)
		Type.SHOP: return Color(0.85, 0.72, 0.25)
		Type.CAMPFIRE: return Color(0.35, 0.70, 0.45)
		Type.RANDOM: return Color(0.45, 0.55, 0.80)
		Type.BOSS: return Color(0.65, 0.25, 0.85)
	return Color(0.78, 0.30, 0.30)

func is_combat() -> bool:
	return type == Type.MONSTER or type == Type.ELITE or type == Type.BOSS
