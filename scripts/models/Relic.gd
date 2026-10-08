class_name Relic
extends RefCounted
## A relic bends a rule for the whole guild (0.66: rules only; stats live on
## gear). Every relic is a fixed pick: GameData.UNIQUE_RELICS, TOWER_RELICS
## or ENDLESS_RELICS (Path relics are carried by heroes: Hero.path_relic).

var id: String
var name: String
var type: String          # Ember/Frost/Verdant/Umbral/Arcane
var rarity: String        # common/rare/epic/legendary
var specials: Array = []         # [{kind, value, label}]
var trigger: Dictionary = {}     # {trigger, effect, value} in Combat's effect shape, or {}
var level: int = 1               # only read by the 0.66 save conversion (levels are gone)
var equipped: bool = false
var unique_id: String = ""       # "" = normal generated relic; else a GameData.UNIQUE_RELICS id
var drawback_kind: String = ""   # "" = no drawback; must be a kind relics already aggregate
var drawback_value: float = 0.0  # stored negative
var drawback_label: String = ""
var combo_with: String = ""      # another unique_id that doubles this relic's effect when both are equipped
var lore: String = ""            # a story-web fragment it carries (before 0.66; keepsakes are items now)


func has_special() -> bool:
	return not specials.is_empty()


func desc() -> String:
	var parts: Array[String] = []
	for s in specials:
		parts.append(str(s["label"]))
	if not trigger.is_empty():
		parts.append(Combat.describe_effect(trigger, true))
	if drawback_kind != "":
		parts.append(drawback_label)
	return " · ".join(parts)


func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "type": type, "rarity": rarity,
		"specials": specials, "trigger": trigger, "level": level, "equipped": equipped,
		"unique_id": unique_id, "drawback_kind": drawback_kind, "drawback_value": drawback_value,
		"drawback_label": drawback_label, "combo_with": combo_with, "lore": lore,
	}


static func from_dict(d: Dictionary) -> Relic:
	var r := Relic.new()
	r.id = d.get("id", "")
	r.name = d.get("name", "")
	r.type = d.get("type", "")
	r.rarity = d.get("rarity", "common")
	r.level = d.get("level", 1)
	r.equipped = d.get("equipped", false)
	r.unique_id = d.get("unique_id", "")
	r.drawback_kind = d.get("drawback_kind", "")
	r.drawback_value = d.get("drawback_value", 0.0)
	r.drawback_label = d.get("drawback_label", "")
	r.combo_with = d.get("combo_with", "")
	r.lore = str(d.get("lore", ""))
	r.trigger = d.get("trigger", {})
	if d.has("specials"):
		r.specials = d["specials"]
	elif str(d.get("special_kind", "")) != "":   # from before every relic had an effect
		r.specials = [{"kind": str(d["special_kind"]), "value": float(d.get("special_value", 0.0)), "label": str(d.get("special_label", ""))}]
	return r
