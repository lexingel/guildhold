extends "res://scripts/autoload/game_state/GameStateHeroes.gd"
## GameState, part 3: gear and relics — equipping, crafting, reforging, selling, supplies.


func buy_tonic(id: String = "healing") -> String:
	var def := GameData.find_tonic(id)
	if def.is_empty():
		return ""
	if tonic_count() >= GameData.TONIC_CAP:
		return tr("Your belt is full (%d tonics)") % GameData.TONIC_CAP
	if coins < int(def["cost"]):
		return tr("Not enough Gold")
	coins -= int(def["cost"])
	add_tonic(id)
	save()
	state_changed.emit()
	return ""


func toggle_equip_relic(relic_id: String) -> void:
	for r in relics:
		if r.id == relic_id:
			if not r.equipped and Combat.equipped_relics().size() >= relic_slot_cap():
				return
			r.equipped = not r.equipped
			save()
			state_changed.emit()
			return


## Adds a rolled loot entry ({loot_type, obj}) to the guild's stash.
func _grant_loot(loot: Dictionary) -> void:
	if loot["loot_type"] == "item":
		var it: Item = loot["obj"]
		it.id = "it" + str(next_id)
		next_id += 1
		items.append(it)
	else:
		var r: Relic = loot["obj"]
		r.id = "rl" + str(next_id)
		next_id += 1
		r.equipped = Combat.equipped_relics().size() < relic_slot_cap()
		relics.append(r)


## Whether the guild holds relic `uid` (a GameData unique id), on a hero or not.
func owns_relic(uid: String) -> bool:
	return relics.any(func(r): return r.unique_id == uid) or heroes.any(func(h): return h.path_relic == uid) or path_relic_chest.has(uid)


## A relic reward (0.66): a unique relic the guild doesn't hold yet, else an
## epic item. Before relics are revealed, always the item.
func unique_or_epic() -> Dictionary:
	var pool: Array = GameData.UNIQUE_RELICS.filter(func(u): return not owns_relic(str(u["id"])))
	if pool.is_empty() or not feature_unlocked("relics"):
		return {"loot_type": "item", "obj": Combat.gen_item("epic")}
	return {"loot_type": "relic", "obj": Combat.relic_from_unique(pool[randi() % pool.size()])}


func sell_relic(relic_id: String) -> void:
	for r in relics:
		if r.id == relic_id and not r.equipped:
			var rar := GameData.find_rarity(r.rarity)
			var fee: float = max(0.05, 0.15 - broker_fee_reduction())
			var sale := int(round(15.0 * float(rar["mult"]) * (1.0 - fee)))
			coins += sale
			relics.erase(r)
			save()
			state_changed.emit()
			return


func craft_items(category: String, rarity: String) -> void:
	if not CRAFT_RARITY_UP.has(rarity):
		return
	var matches: Array[Item] = []
	for it in items:
		if it.category == category and it.rarity == rarity and it.equipped_to == "":
			matches.append(it)
	if matches.size() < 3:
		return
	# The crafted item keeps the best rank among the three fed in — feeding
	# high-rank commons shouldn't hand back a Rank-F rare.
	var best_rank_idx := 0
	var best_kind := ""
	var best_roll := 0.0
	for i in 3:
		best_rank_idx = max(best_rank_idx, GameData.rift_rank_index(matches[i].item_rank))
		var r := item_roll(matches[i])
		if r > best_roll:
			best_kind = matches[i].kind
			best_roll = r
		items.erase(matches[i])
	if not has_wing("smithy"):   # the Smithy wing keeps the best stat line of the three
		best_kind = ""
		best_roll = 0.0
	items.append(Combat.gen_item(str(CRAFT_RARITY_UP[rarity]), category, str(GameData.RIFT_RANKS[best_rank_idx]["id"]), best_kind, minf(best_roll, GameData.ITEM_ROLL_RANGE[1])))
	crafts_performed += 1
	save()
	state_changed.emit()


## How well an item's first stat line rolled (0.9-1.1), whatever its rarity and rank.
func item_roll(it: Item) -> float:
	var base := float(GameData.ITEM_KIND_BASE.get(it.kind, 0.0)) * float(GameData.find_rarity(it.rarity)["mult"]) * float(GameData.ITEM_AFFIX_VALUE_SHARE[0]) 		* float(GameData.ITEM_RANK_MULT[GameData.rift_rank_index(it.item_rank)])
	return it.value / base if base > 0.0 else 0.0


## A won fight counts toward every equipped item on the heroes still standing.
func _attune_gear(party: Array) -> void:
	for h in party:
		if h.hp <= 0:
			continue
		for it in items:
			if it.equipped_to != h.id or it.attune_level >= GameData.ATTUNE_MAX:
				continue
			it.attune_wins += 1
			if it.attune_wins >= GameData.ATTUNE_WINS * (it.attune_level + 1):
				it.attune_level += 1
				var g := 1.0 + GameData.ATTUNE_STEP
				it.value = snappedf(it.value * g, 0.001)
				it.secondary_value = snappedf(it.secondary_value * g, 0.001)
				it.tertiary_value = snappedf(it.tertiary_value * g, 0.001)
				push_toast(h, tr("Gear attuned"), tr("%s grows stronger (%d/%d)") % [tr(str(it.name)), it.attune_level, GameData.ATTUNE_MAX])


## Gold to temper `it` one more level at the Forge (0 = fully tempered).
func forge_cost(it: Item) -> int:
	if it.forge_level >= GameData.FORGE_MAX:
		return 0
	var rank_mult := float(GameData.find_rift_rank(it.item_rank).get("reward", 1.0)) if it.item_rank != "" else 1.0
	return int(round(GameData.FORGE_GOLD * float(GameData.find_rarity(it.rarity)["mult"]) * rank_mult * (it.forge_level + 1) * (1.0 - work_bonus("forge"))))


## Tempers an item (equipped or not): its rolled stats grow FORGE_STEP.
func forge_item(item_id: String) -> String:
	var it: Item = null
	for x in items:
		if x.id == item_id:
			it = x
	if not it:
		return tr("No such item")
	if not feature_unlocked("forge"):
		return tr("The Smithy opens when Act I is done")
	var cost := forge_cost(it)
	if cost <= 0:
		return tr("Fully tempered")
	if coins < cost:
		return tr("Needs %d Gold") % cost
	coins -= cost
	it.forge_level += 1
	var g := 1.0 + GameData.FORGE_STEP
	it.value = snappedf(it.value * g, 0.001)
	it.secondary_value = snappedf(it.secondary_value * g, 0.001)
	it.tertiary_value = snappedf(it.tertiary_value * g, 0.001)
	save()
	state_changed.emit()
	return ""


func reforge_cost(it: Item) -> int:
	return int(round(GameData.REFORGE_CRYSTALS * float(GameData.find_rarity(it.rarity)["mult"]) * (it.reforges + 1)))


## Rerolls one stat line (0 primary, 1 secondary, 2 tertiary) of an unequipped
## generated item: the primary keeps its kind (the name comes from it), the
## others can land on any kind the item doesn't already have.
func reforge_item(item_id: String, line: int) -> String:
	var it: Item = null
	for x in items:
		if x.id == item_id:
			it = x
	if not it or it.unique_id != "" or it.equipped_to != "":
		return tr("Can't reforge this item")
	var kinds := [it.kind, it.secondary_kind, it.tertiary_kind]
	if line < 0 or line > 2 or str(kinds[line]) == "":
		return tr("No such stat")
	var cost := reforge_cost(it)
	if crystals < cost:
		return tr("Not enough Essence")
	crystals -= cost
	it.reforges += 1
	var kind: String = kinds[line]
	if line > 0:
		var pool: Array = GameData.ITEM_CATEGORY_KINDS[it.category].filter(func(k): return not kinds.has(k))
		pool.append(kind)
		kind = str(pool[randi() % pool.size()])
	var val := Combat.item_line_value(kind, it.rarity, line, it.item_rank) * pow(1.0 + GameData.ATTUNE_STEP, it.attune_level) * pow(1.0 + GameData.FORGE_STEP, it.forge_level)
	match line:
		0:
			it.value = val
		1:
			it.secondary_kind = kind
			it.secondary_value = val
			if it.effects.is_empty() or not (it.effects[0] as Dictionary).has("suffix"):   # older items are named by their 2nd stat
				var suffixes: Array = GameData.ITEM_AFFIX_SUFFIX[kind]
				it.name = "%s %s" % [it.name.split(" of ")[0], str(suffixes[randi() % suffixes.size()])]
		2:
			it.tertiary_kind = kind
			it.tertiary_value = val
	save()
	state_changed.emit()
	return ""


func salvage_value(it: Item) -> int:
	return int(round(GameData.SALVAGE_CRYSTALS * float(GameData.find_rarity(it.rarity)["mult"]) * salvage_mult()))


func salvage_item(item_id: String) -> void:
	if not feature_unlocked("forge"):   # the Smithy's (0.66)
		return
	for it in items:
		if it.id == item_id and it.equipped_to == "":
			crystals += salvage_value(it)
			items.erase(it)
			save()
			state_changed.emit()
			return


func sell_item(item_id: String) -> void:
	for it in items:
		if it.id == item_id and it.equipped_to == "":
			var rar := GameData.find_rarity(it.rarity)
			var fee: float = max(0.05, 0.15 - broker_fee_reduction())
			var sale := int(round(15.0 * float(rar["mult"]) * (1.0 - fee)))
			coins += sale
			items.erase(it)
			save()
			state_changed.emit()
			return


func find_item(item_id: String) -> Item:
	for it in items:
		if it.id == item_id:
			return it
	return null


## Every flat kind->value an item contributes (what Combat.hero_item_total
## sums for it).
## How much `h`'s Power changes with `it` in their slot `idx` (replacing
## what's there), tried on and taken off again without saving.
func power_delta(h: Hero, it: Item, idx: int) -> int:
	var before := Combat.power_of(h)
	var cur: Item = null
	for x in items:
		if x != it and x.equipped_to == h.id and x.slot_type() == it.slot_type() and x.equipped_idx == idx:
			cur = x
	var was_to := it.equipped_to
	var was_idx := it.equipped_idx
	if cur:
		cur.equipped_to = ""
	it.equipped_to = h.id
	it.equipped_idx = idx
	var after := Combat.power_of(h)
	it.equipped_to = was_to
	it.equipped_idx = was_idx
	if cur:
		cur.equipped_to = h.id
	return after - before


func item_stat_map(it: Item) -> Dictionary:
	var m := {}
	if it == null:
		return m
	for pair in [[it.kind, it.value], [it.secondary_kind, it.secondary_value], [it.tertiary_kind, it.tertiary_value],
			[it.implicit_kind, it.implicit_value], [it.drawback_kind, it.drawback_value]]:
		if str(pair[0]) != "":
			m[pair[0]] = float(m.get(pair[0], 0.0)) + float(pair[1])
	return m


## How much an item helps `h`, for "Equip best": the hero power it adds on
## top of what they wear now (or loses, if already worn), plus a little per
## special effect, which power doesn't see. Stat weights break ties.
func gear_score(it: Item, h: Hero) -> float:
	var was_to := it.equipped_to
	it.equipped_to = h.id
	var p_with := Combat.power_of(h)
	it.equipped_to = ""
	var p_without := Combat.power_of(h)
	it.equipped_to = was_to
	var tie := 0.0
	var stats := item_stat_map(it)
	for k in stats:
		tie += float(stats[k]) * float(GEAR_SCORE_WEIGHT.get(k, 0.4))
	var fx: Array = GameData.find_unique_item(it.unique_id).get("effects", []) if it.unique_id != "" else it.effects
	return float(p_with - p_without) + 3.0 * fx.size() + 0.1 * tie


## The best free (or already worn) gear for a hero: {slot_type: [items]},
## never taking an item another hero is wearing.
func best_gear(h: Hero) -> Dictionary:
	var out := {}
	# Score each piece alone on the hero with nothing equipped, so the ranking
	# doesn't depend on what they happen to wear now (stats multiply).
	var worn: Array = items.filter(func(it): return it.equipped_to == h.id)
	var pools := {}
	for st in ["weapon", "gear"]:
		pools[st] = items.filter(func(it): return it.slot_type() == st and (it.equipped_to == "" or it.equipped_to == h.id) and item_fits_hero(it, h) and attr_req_met(it, h))
	for it in worn:
		it.equipped_to = ""
	var score := {}
	for st in pools:
		for it in pools[st]:
			score[it] = gear_score(it, h)
	for it in worn:
		it.equipped_to = h.id
	for st in pools:
		var pool: Array = pools[st]
		var cap := GameData.weapon_slots(h.pool_id) if st == "weapon" else GameData.gear_slots(h.rank)
		pool.sort_custom(func(a, b): return score[a] > score[b] or (score[a] == score[b] and a.id < b.id))
		out[st] = pool.slice(0, cap)
	return out


## How many items "Equip best" would put on `h` that it isn't wearing.
func equip_best_changes(h: Hero) -> int:
	var n := 0
	var best := best_gear(h)
	for st in best:
		n += (best[st] as Array).filter(func(it): return it.equipped_to != h.id).size()
	return n


func equip_best(hero_id: String) -> void:
	var h := find_hero(hero_id)
	if not h:
		return
	var best := best_gear(h)
	for st in best:
		for it in items:
			if it.equipped_to == h.id and it.slot_type() == st:
				it.equipped_to = ""
				it.equipped_idx = -1
		var idx := 0
		for it in best[st]:
			it.equipped_to = h.id
			it.equipped_idx = idx
			idx += 1
	save()
	state_changed.emit()


func equip_item(hero_id: String, slot_type: String, idx: int, item_id: String) -> void:
	var h := find_hero(hero_id)
	if not h:
		return
	# Validate the new item first — a rejected equip must not empty the slot.
	var target: Item = null
	if item_id != "":
		for it in items:
			if it.id == item_id:
				target = it
				break
		if not target or target.slot_type() != slot_type:
			return
		if not item_fits_hero(target, h) or not attr_req_met(target, h):
			return
		var cap := GameData.weapon_slots(h.pool_id) if slot_type == "weapon" else GameData.gear_slots(h.rank)
		if idx >= cap:
			return
	for it in items:
		if it.equipped_to == hero_id and it.slot_type() == slot_type and it.equipped_idx == idx:
			it.equipped_to = ""
			it.equipped_idx = -1
	if target == null:
		save()
		state_changed.emit()
		return
	target.equipped_to = hero_id
	target.equipped_idx = idx
	save()
	state_changed.emit()
