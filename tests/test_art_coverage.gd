extends "res://tests/base_test.gd"
## Art coverage (0.50): every hero and champion animates as themself, every
## skill has its own icon, every legendary relic its own picture.


func run() -> void:
	var gaps: Array[String] = []
	for pid in GameData.SUBCLASS_PORTRAIT_PATH:
		for a in ["attack", "hurt", "skill"]:
			if GameData.subclass_anim_frames(pid, a).is_empty():
				gaps.append("%s %s" % [pid, a])
		if not ResourceLoader.exists("res://assets/survivors/walk/sub_%s_7.png" % pid):
			gaps.append("%s walk" % pid)
	check(gaps.is_empty(), "every subclass has attack, hit, skill and walk frames %s" % [gaps])

	gaps.clear()
	for id in GameData.CHAMPIONS:
		for a in ["attack", "hurt", "skill"]:
			if GameData.hero_combat_frames("warrior", "champ_" + id, a).is_empty():
				gaps.append("%s %s" % [id, a])
	check(gaps.is_empty(), "every champion has their own combat frames %s" % [gaps])

	# Skill icons, read from the data file so tree nodes built in code count too.
	var src := FileAccess.get_file_as_string("res://scripts/autoload/game_data/GameDataSkills.gd")
	var re := RegEx.create_from_string("\"name\": \"([^\"]+)\"[^{}]*?\"icon\": \"(res://assets/skills/[a-z_]+\\.png)\"")
	var icon_of := {}
	var missing: Array[String] = []
	for m in re.search_all(src):
		icon_of[m.get_string(1)] = m.get_string(2)
		if not ResourceLoader.exists(m.get_string(2)):
			missing.append(m.get_string(1))
	check(icon_of.size() > 100 and missing.is_empty(), "%d skills, every icon exists %s" % [icon_of.size(), missing])
	var by_icon := {}
	for n in icon_of:
		by_icon[icon_of[n]] = by_icon.get(icon_of[n], []) + [n]
	var shared := by_icon.values().filter(func(names): return names.size() > 1)
	check(shared.is_empty(), "no two skills share an icon %s" % [shared])

	gaps.clear()
	for u in GameData.UNIQUE_RELICS + GameData.TOWER_RELICS.values() + GameData.ENDLESS_RELICS.values():
		if not ResourceLoader.exists("res://assets/relics/u_%s.png" % u["id"]):
			gaps.append(str(u["id"]))
	check(gaps.is_empty(), "every legendary relic has its own icon %s" % [gaps])

	# Icons draw at whole multiples of their own size (0.52), so pixels stay even.
	check(UiKit.pixel_size(32, 28) == 32 and UiKit.pixel_size(32, 40) == 32 and UiKit.pixel_size(32, 64) == 64 and UiKit.pixel_size(40, 48) == 40, "small icons snap to whole pixel multiples")
	check(UiKit.pixel_size(32, 16) == 16 and UiKit.pixel_size(200, 78) == 78, "tiny requests and big art keep their size")

	# Effects (0.52): every frame of every set exists; every role, element and foe kind has its own.
	var fx_missing: Array[String] = []
	for id in Fx.FRAMES:
		for i in int(Fx.FRAMES[id]):
			if not ResourceLoader.exists(Fx.frame_path(id, i)):
				fx_missing.append("%s_%d" % [id, i])
	check(fx_missing.is_empty(), "every effect frame exists %s" % [fx_missing])
	var used := {}
	for role in ["warrior", "rogue", "ranger", "cleric", "mage"]:
		for el in ["Ember", "Frost", "Arcane", "Umbral", "Verdant"]:
			used[Fx.hero_hit(role, el)] = true
	for el in ["Ember", "Frost", "Arcane", "Umbral", "Verdant"]:
		used[Fx.foe_hit(true, el)] = true
	used[Fx.foe_hit(false, "")] = true
	check(used.keys().all(func(k): return Fx.FRAMES.has(k)) and used.size() >= 11, "%d effect sets in use, all real" % used.size())
