extends "res://scripts/autoload/game_data/GameDataSkills.gd"
## GameData, part 5b: Paths (0.62). First generated from docs/design/subclass_paths.md
## (section 3a); edit here from now on.
## A Path is a role's playstyle: a rule (stage 1, trained at Rank D), a Technique
## (stage 2, Rank B) and a Signature moment (stage 3, Rank S). Every subclass is a
## stage of one Path and adds a Twist; each role's Legend is a stage-3 choice for
## all three of its Paths that lifts the rule's limit.

const PATHS := {
	"shieldwall": {"role": "warrior", "name": "Shieldwall", "blurb": "the one who stands in front.", "kind": "hp_pct", "rule": {"name": "Guardian", "desc": "from the front row, takes 25% of every hit aimed at a back-row ally."}, "technique": {"name": "Hold the Line", "desc": "until the round ends, takes every hit aimed at the back row, at 30% less."}, "signature": {"name": "Last Wall", "desc": "the first time an ally would fall, they take the blow instead, gain a ward of 30% max HP, and every foe must attack them for 2 rounds."}, "legend": "Guardian covers front-row allies too.", "stages": [["footman", "fieldmender", "bulwark", "frostguard"], ["iron-guard", "aegis-bearer"], ["stormguard"]]},
	"bloodrage": {"role": "warrior", "name": "Bloodrage", "blurb": "gets stronger as they bleed.", "kind": "dmg_pct", "rule": {"name": "Bloodrage", "desc": "+1% damage for every 2% of HP missing."}, "technique": {"name": "Blood Price", "desc": "pay 15% HP (no Momentum): +2 Momentum and the next hit does +50%."}, "signature": {"name": "Red Mist", "desc": "the first time they drop below 30% HP, for 3 rounds their attacks hit every foe, they can't be stunned, and they can't be healed."}, "legend": "Red Mist triggers at 50% HP.", "stages": [["squire"], ["berserker", "bloodletter"], ["ashen-templar"]]},
	"weaponmaster": {"role": "warrior", "name": "Weaponmaster", "blurb": "builds a rhythm on one foe.", "kind": "first_round_pct", "rule": {"name": "Combo", "desc": "each hit in a row on the same foe adds +12% (up to 4); switching targets resets it."}, "technique": {"name": "Flurry", "desc": "three quick strikes at the target, each adding a Combo stack."}, "signature": {"name": "Perfect Form", "desc": "the first time Combo reaches 4, they act twice next round."}, "legend": "switching targets no longer resets Combo.", "stages": [["trailblazer", "duelist", "featherguard"], ["warbrand"], ["runeblade", "rift-breaker"]]},
	"marksman": {"role": "ranger", "name": "Marksman", "blurb": "waits for the clean shot.", "kind": "boss_alpha_strike", "rule": {"name": "Steady Aim", "desc": "not attacked last round → the next shot does +35%."}, "technique": {"name": "Called Shot", "desc": "pick a foe; the next Steady shot at it also cancels its wind-up."}, "signature": {"name": "Overwatch", "desc": "the first time they use Called Shot, they hold their turn and fire at the first foe to act next round, with double the Steady bonus."}, "legend": "Steady Aim holds even when they're attacked.", "stages": [["fieldscout", "slinger", "longshot"], ["blade-dancer", "gale-marksman"], ["rift-piercer"]]},
	"trapper": {"role": "ranger", "name": "Trapper", "blurb": "controls the ground.", "kind": "hazard_guard_pct", "rule": {"name": "Snares", "desc": "each round the first foe to act steps in a snare: light damage, and it acts last next round."}, "technique": {"name": "Bait", "desc": "a lure takes the next foe attack this round (no damage) and snares that foe."}, "signature": {"name": "Killing Ground", "desc": "the first time three foes have been snared in a fight, every snared foe takes +30% damage for 2 rounds."}, "legend": "snares also cancel wind-ups.", "stages": [["trapper", "pathfinder", "sapling-keeper"], ["warden", "deadfall-hunter"], ["wintertide-archer"]]},
	"stalker": {"role": "ranger", "name": "Stalker", "blurb": "picks the prey for the whole party.", "kind": "dodge_pct", "rule": {"name": "Mark", "desc": "their first hit marks a foe; the party does +15% to it; the mark jumps to another foe when it dies."}, "technique": {"name": "Hunt", "desc": "move the Mark to any foe; their next hit on it does +60%."}, "signature": {"name": "Vanish", "desc": "the first time they're hit, they can't be targeted for a round and their next hit on the Mark does triple."}, "legend": "two Marks at once.", "stages": [["shadowtracker", "nightwarden"], ["duskstalker", "rift-ranger", "stormtracker"], ["voidwalker"]]},
	"evocation": {"role": "mage", "name": "Evocation", "blurb": "builds heat until it explodes.", "kind": "dmg_pct", "rule": {"name": "Kindling", "desc": "each spell adds 1 Heat (+8% damage, up to 5); at 5 the next skill hits every foe and Heat resets."}, "technique": {"name": "Flashpoint", "desc": "+3 Heat at once."}, "signature": {"name": "Inferno", "desc": "the first detonation in a fight leaves every foe burning for 3 rounds."}, "legend": "detonating drops Heat to 3, not 0.", "stages": [["apprentice", "cinderling", "cinder-adept"], ["stormcaller"], ["ashbound-theorist", "pyromancer"]]},
	"warding": {"role": "mage", "name": "Warding", "blurb": "keeps the party behind glass.", "kind": "wipe_guard", "rule": {"name": "Ward Weave", "desc": "at the start of every round, the most-hurt ally gets a ward of 8% of max HP."}, "technique": {"name": "Sigil", "desc": "wards every ally for 12% of their max HP."}, "signature": {"name": "Mirror Ward", "desc": "the first time a ward breaks, every ward reflects damage for 2 rounds."}, "legend": "Ward Weave wards every ally each round.", "stages": [["fledgling-seer", "frost-scholar", "stoneward-mystic"], ["wardweaver"], ["rift-warden-magus"]]},
	"augury": {"role": "mage", "name": "Augury", "blurb": "sees what's coming and bends it.", "kind": "dodge_pct", "rule": {"name": "Foresight", "desc": "once a fight, the first heavy blow aimed at the party comes to nothing."}, "technique": {"name": "Twist Fate", "desc": "reroll a foe's next move."}, "signature": {"name": "Prophecy", "desc": "the first time a foe winds up, the whole party dodges the blow and gains 2 Momentum."}, "legend": "two cancels a fight.", "stages": [["shade-adept", "thornweaver", "grim-conjurer"], ["verdant-oracle", "duskglass-seer"], ["archon-of-storms"]]},
	"mercy": {"role": "cleric", "name": "Mercy", "blurb": "healing that keeps on giving.", "kind": "mend_pct", "rule": {"name": "Overflow", "desc": "healing past full HP becomes a ward."}, "technique": {"name": "Benediction", "desc": "heals every ally for 15% of max HP."}, "signature": {"name": "Miracle", "desc": "the first time an ally falls, they rise at 30% HP."}, "legend": "Miracle works twice a fight.", "stages": [["acolyte", "peddler", "herbalist"], ["rift-medic", "frost-anchorite"], ["dawnkeeper", "alchemist"]]},
	"aegis": {"role": "cleric", "name": "Aegis", "blurb": "the party is safer while they stand.", "kind": "hp_pct", "rule": {"name": "Sanctuary", "desc": "while they stand, the party takes 6% less damage."}, "technique": {"name": "Consecrate", "desc": "one ally takes no damage this round."}, "signature": {"name": "Hallowed Ground", "desc": "the first time the party falls below half its total HP, damage taken is halved for 2 rounds."}, "legend": "Sanctuary is doubled.", "stages": [["frostward-sister", "hearth-warden"], ["battle-chaplain"], ["sanctified-shield"]]},
	"zeal": {"role": "cleric", "name": "Zeal", "blurb": "heals by hitting.", "kind": "dmg_pct", "rule": {"name": "Fervor", "desc": "their attacks heal the most-hurt ally for 25% of the damage."}, "technique": {"name": "Smite", "desc": "a 150% holy strike; Fervor heals double for it."}, "signature": {"name": "Judgment", "desc": "their first kill in a fight hits every foe for half their attack and heals the party 10%."}, "legend": "Fervor heals the whole party.", "stages": [["emberblessed-acolyte", "lay-brother", "vanguard-chaplain"], ["ember-confessor", "zealot"], ["radiant-vanguard", "sainted-ember"]]},
	"assassin": {"role": "rogue", "name": "Assassin", "blurb": "finishes what others start.", "kind": "dmg_pct", "rule": {"name": "Execute", "desc": "+50% damage to foes under 35% HP; a kill refunds 2 Momentum."}, "technique": {"name": "Shadowstep", "desc": "strikes any foe for 130%, past escorts and guards."}, "signature": {"name": "Deathmark", "desc": "their first kill in a fight gives them another action at once."}, "legend": "Execute works under 50% HP.", "stages": [["cutpurse", "arcane-pilferer"], ["wraithstep", "nightblade"], ["the-unseen-hand"]]},
	"skirmisher": {"role": "rogue", "name": "Skirmisher", "blurb": "can't be pinned down.", "kind": "dodge_pct", "rule": {"name": "Evasion", "desc": "+15% dodge; each dodge gives 1 Momentum and a counter jab."}, "technique": {"name": "Feint", "desc": "until their next turn, half the attacks aimed at others go to them instead, and they have +25% dodge."}, "signature": {"name": "Untouchable", "desc": "after their third dodge in a fight, they can't be hit for 2 rounds."}, "legend": "counter jabs hit at full strength.", "stages": [["runaway", "scavenger", "skirmisher", "glyphhand", "footpad"], ["shadowfoot", "rift-slipper"], ["wraithblade-adept"]]},
	"scrapper": {"role": "rogue", "name": "Scrapper", "blurb": "hard to put down.", "kind": "hp_pct", "rule": {"name": "Scrappy", "desc": "heals 15% of the damage they deal; +5% HP each round in the front row."}, "technique": {"name": "Dirty Trick", "desc": "a hit that stuns the foe and gives 2 Momentum."}, "signature": {"name": "Second Wind", "desc": "the first time they drop below 25% HP, they heal 50% and their next 2 attacks hit twice."}, "legend": "can't be stunned, and Scrappy heals 30%.", "stages": [["herbrunner", "ironhide-footpad"], ["bramblefoot", "fleetblade"], ["duskrunner"]]},
}
## Each role's Legend subclass (stage 3, open to all three of its Paths).
const LEGENDS := {"warrior": "rift-sovereign", "ranger": "rift-eclipsed-warden", "mage": "the-unbound", "cleric": "last-light-martyr", "rogue": "the-final-cut"}
## One line per subclass: how it bends its Path.
const SUBCLASS_TWIST := {
	"footman": "Foes whose hits they take deal 10% less for the rest of the fight.",
	"fieldmender": "Each hit they take heals the ally it was aimed at for 5% of their max HP.",
	"bulwark": "Takes 40% instead of 25%, but always acts last.",
	"frostguard": "Foes whose hits they take are chilled and act later next round.",
	"iron-guard": "Hold the Line also wards the back row for 10% of their max HP.",
	"aegis-bearer": "Hold the Line costs 2 Momentum.",
	"stormguard": "During Last Wall, every foe that hits them is stunned.",
	"squire": "Reckless: +10% damage dealt and taken.",
	"berserker": "Blood Price costs 10% HP and the empowered hit cleaves.",
	"bloodletter": "Heals 1% of damage dealt for every 4% of HP missing.",
	"ashen-templar": "Can't fall below 1 HP during Red Mist.",
	"trailblazer": "Starts every fight at 1 Combo.",
	"duelist": "When their Combo target attacks them, they counter and keep the stack.",
	"featherguard": "Each Combo stack also gives +3% dodge.",
	"warbrand": "Combo goes up to 6.",
	"runeblade": "During Perfect Form the whole party hits 15% harder.",
	"rift-breaker": "At 4 Combo their hits ignore armor and wards.",
	"fieldscout": "Steady shots break armor.",
	"slinger": "Steady Aim still holds after one hit.",
	"longshot": "Needs two quiet rounds, but gives +70%.",
	"blade-dancer": "Called Shot also hits every foe under 40% HP.",
	"gale-marksman": "Can use Called Shot from the front row.",
	"rift-piercer": "Overwatch shots ignore wards.",
	"trapper": "Snares do double damage.",
	"pathfinder": "Snared foes' hits are 10% weaker; rift hazards are 20% weaker.",
	"sapling-keeper": "Each snare heals the most-hurt ally for 4% of max HP.",
	"warden": "Bait also wards the party for 8% of max HP.",
	"deadfall-hunter": "Snares hit as hard as their basic attack.",
	"wintertide-archer": "Snared foes lose their next action.",
	"shadowtracker": "The marked foe deals 10% less damage.",
	"nightwarden": "The party dodges the marked foe's attacks 15% more often.",
	"duskstalker": "+15% dodge while their Mark lives.",
	"rift-ranger": "When the Mark jumps, +2 Momentum.",
	"stormtracker": "Their hits on the Mark chain to another foe for 30%.",
	"voidwalker": "Vanish lasts 2 rounds.",
	"apprentice": "Heat goes up to 7, but the detonation hits only the target.",
	"cinderling": "Every spell burns its target lightly.",
	"cinder-adept": "Starts every fight at 2 Heat.",
	"stormcaller": "Gains Heat when foes attack them too.",
	"ashbound-theorist": "When a burning foe dies, its fire spreads to the rest.",
	"pyromancer": "Detonates at 4 Heat.",
	"fledgling-seer": "Wards go on the ally a foe is about to hit, not the most-hurt one.",
	"frost-scholar": "A broken ward chills the attacker.",
	"stoneward-mystic": "Wards are 12%, front row only.",
	"wardweaver": "Sigil costs 2 Momentum.",
	"rift-warden-magus": "Mirror Ward also shatters a foe's wind-up.",
	"shade-adept": "The foe whose blow is cancelled takes +15% damage after.",
	"thornweaver": "Allies who were warned of a hit heal 4% after it lands.",
	"grim-conjurer": "Once a fight, a fallen ally rises at 15%.",
	"verdant-oracle": "Twist Fate also heals the party 6%.",
	"duskglass-seer": "Twist Fate also gives an ally 2 Momentum.",
	"archon-of-storms": "Prophecy also strikes the winding-up foe with lightning.",
	"acolyte": "Their heals cleanse one ailment.",
	"peddler": "Overflow wards are half again as big.",
	"herbalist": "Healed allies mend 3% more on each of the next 2 rounds.",
	"rift-medic": "Benediction costs 2 Momentum.",
	"frost-anchorite": "Benediction cleanses everyone.",
	"dawnkeeper": "Miracle also wards the party for 15%.",
	"alchemist": "Miracle brings the ally back at 50%.",
	"frostward-sister": "Front-row allies take a further 4% less.",
	"hearth-warden": "Sanctuary also mends the party 2% each round.",
	"battle-chaplain": "Consecrate also gives its target +20% dodge next round.",
	"sanctified-shield": "Hallowed Ground triggers at 70% instead of 50%.",
	"emberblessed-acolyte": "The ally Fervor heals hits 5% harder on their next turn.",
	"lay-brother": "Their hits break a foe's wind-up.",
	"vanguard-chaplain": "Their first attack each fight does +50%.",
	"ember-confessor": "Smite finishes foes under 20% HP.",
	"zealot": "Smite costs 10% HP instead of Momentum.",
	"radiant-vanguard": "Judgment triggers on any party kill.",
	"sainted-ember": "Judgment also sets every foe burning.",
	"cutpurse": "Their kills add 10 Gold to the haul.",
	"arcane-pilferer": "Their hits break wards.",
	"wraithstep": "After Shadowstep, they can't be targeted until their next turn.",
	"nightblade": "Execute damage heals them for 20% of it.",
	"the-unseen-hand": "Deathmark can chain: up to 3 extra actions.",
	"runaway": "Each dodge wards the most-hurt ally for 5%.",
	"scavenger": "Rift hazards never hurt them.",
	"skirmisher": "Counter jabs hit for 60% instead of 30%.",
	"glyphhand": "Counter jabs break wards.",
	"footpad": "Dodging the first hit of a fight gives 3 Momentum.",
	"shadowfoot": "Feint costs 2 Momentum.",
	"rift-slipper": "Feint also saves the party from one wipe.",
	"wraithblade-adept": "Untouchable after the second dodge.",
	"herbrunner": "Scrappy also heals the most-hurt ally for half as much.",
	"ironhide-footpad": "Takes 10% less in the front row.",
	"bramblefoot": "Attackers take 10% of their hit back.",
	"fleetblade": "Dirty Trick hits twice.",
	"duskrunner": "Second Wind triggers at 40%.",
}
## What unlocks each subclass's training for the guild ({} = open from the start).
## act: that act done · tower: that Tower of Trials floor · role_seals: rifts sealed
## with a hero of the role · flawless_boss: a boss beaten by hand with no one down ·
## freed: lost champions freed · seal_rank: a rift of that rank sealed ·
## riftbreak_rank: a Riftbreak of that rank held. Several keys = all of them.
const SUBCLASS_UNLOCK := {
	"footman": {},
	"fieldmender": {"act": 1},
	"bulwark": {"tower": 10},
	"frostguard": {"role_seals": 10},
	"iron-guard": {"act": 2},
	"aegis-bearer": {"tower": 30},
	"stormguard": {"act": 3},
	"squire": {},
	"berserker": {"act": 2},
	"bloodletter": {"act": 3},
	"ashen-templar": {"act": 3},
	"trailblazer": {},
	"duelist": {"role_seals": 10},
	"featherguard": {"tower": 20},
	"warbrand": {"act": 2},
	"runeblade": {"act": 3},
	"rift-breaker": {"riftbreak_rank": "S"},
	"fieldscout": {},
	"slinger": {"tower": 20},
	"longshot": {"flawless_boss": 1},
	"blade-dancer": {"act": 2},
	"gale-marksman": {"tower": 45},
	"rift-piercer": {"act": 3},
	"trapper": {},
	"pathfinder": {"flawless_boss": 1},
	"sapling-keeper": {"act": 1},
	"warden": {"act": 2},
	"deadfall-hunter": {"seal_rank": "A"},
	"wintertide-archer": {"act": 3},
	"shadowtracker": {},
	"nightwarden": {"act": 1},
	"duskstalker": {"act": 2},
	"rift-ranger": {"tower": 30},
	"stormtracker": {"act": 3},
	"voidwalker": {"act": 3},
	"apprentice": {},
	"cinderling": {"tower": 10},
	"cinder-adept": {"role_seals": 10},
	"stormcaller": {"act": 2},
	"ashbound-theorist": {"act": 3},
	"pyromancer": {"tower": 70},
	"fledgling-seer": {},
	"frost-scholar": {"role_seals": 10},
	"stoneward-mystic": {"tower": 20},
	"wardweaver": {"act": 2},
	"rift-warden-magus": {"act": 3},
	"shade-adept": {},
	"thornweaver": {"tower": 20},
	"grim-conjurer": {"flawless_boss": 1},
	"verdant-oracle": {"act": 2},
	"duskglass-seer": {"tower": 45},
	"archon-of-storms": {"act": 3},
	"acolyte": {},
	"peddler": {"flawless_boss": 1},
	"herbalist": {"act": 1},
	"rift-medic": {"act": 2},
	"frost-anchorite": {"seal_rank": "A"},
	"dawnkeeper": {"act": 3},
	"alchemist": {"tower": 70},
	"frostward-sister": {},
	"hearth-warden": {"act": 1},
	"battle-chaplain": {"act": 2},
	"sanctified-shield": {"act": 3},
	"emberblessed-acolyte": {},
	"lay-brother": {"tower": 10},
	"vanguard-chaplain": {"role_seals": 10},
	"ember-confessor": {"act": 2},
	"zealot": {"act": 3},
	"radiant-vanguard": {"act": 3},
	"sainted-ember": {"riftbreak_rank": "S"},
	"cutpurse": {},
	"arcane-pilferer": {"role_seals": 10},
	"wraithstep": {"act": 2},
	"nightblade": {"freed": 1},
	"the-unseen-hand": {"act": 3},
	"runaway": {},
	"scavenger": {"tower": 20},
	"skirmisher": {"flawless_boss": 1},
	"glyphhand": {"act": 1},
	"footpad": {"tower": 10},
	"shadowfoot": {"act": 2},
	"rift-slipper": {"tower": 45},
	"wraithblade-adept": {"act": 3},
	"herbrunner": {},
	"ironhide-footpad": {"flawless_boss": 1},
	"bramblefoot": {"act": 2},
	"fleetblade": {"seal_rank": "A"},
	"duskrunner": {"act": 3},
	"rift-sovereign": {"tower": 100},
	"rift-eclipsed-warden": {"act": 6},
	"the-unbound": {"tower": 90, "act": 4},
	"last-light-martyr": {"act": 6},
	"the-final-cut": {"tower": 100},
}

# ---- hand-written below this line (the generator keeps it) ----
## The rank at which each stage's training opens (stage 1..3).
const STAGE_RANK := ["", "D", "B", "S"]
## A subclass training at the Training Yard, by stage: Gold and Essence up
## front, days away. A Legend is a stage-3 training of its own price.
const SUBCLASS_TRAINING := [{}, {"gold": 500, "essence": 200, "days": 3}, {"gold": 1000, "essence": 600, "days": 4}, {"gold": 2500, "essence": 1200, "days": 5}]
const LEGEND_TRAINING := {"gold": 3500, "essence": 1800, "days": 5}
## (0.62 sim: Gold-hungry rosters rarely afforded stage 2 at 1,500 while Essence piled up, so the prices lean on Essence.)
## Changing Path at a stage-2 or stage-3 training: this times the cost and days.
const PATH_CHANGE_MULT := 2
## Laurels to carry a remembered unlock to a new guild, by stage; a Legend.
const SUBCLASS_CARRY_LAURELS := [0, 3, 5, 8]
const LEGEND_CARRY_LAURELS := 12


## The Path a subclass belongs to ("" for a base class or a Legend, whose
## Path is the hero's own: Hero.path).
static func path_of(pool_id: String) -> String:
	for pid in PATHS:
		for st in PATHS[pid]["stages"]:
			if (st as Array).has(pool_id):
				return pid
	return ""


static func is_legend(pool_id: String) -> bool:
	return LEGENDS.values().has(pool_id)


## 0 for a base class (or anything unknown), else 1-3.
static func subclass_stage(pool_id: String) -> int:
	if is_legend(pool_id):
		return 3
	for pid in PATHS:
		var stages: Array = PATHS[pid]["stages"]
		for i in stages.size():
			if (stages[i] as Array).has(pool_id):
				return i + 1
	return 0


## The subclasses a hero on Path `path_id` can train at `stage` (stage 3 adds the role's Legend).
static func stage_options(path_id: String, stage: int) -> Array:
	if not PATHS.has(path_id) or stage < 1 or stage > 3:
		return []
	var out: Array = (PATHS[path_id]["stages"][stage - 1] as Array).duplicate()
	if stage == 3:
		out.append(str(LEGENDS[str(PATHS[path_id]["role"])]))
	return out


## The Paths of a role, in order.
static func role_paths(role: String) -> Array:
	return PATHS.keys().filter(func(pid): return str(PATHS[pid]["role"]) == role)


## A training's price and days for `pool_id` (x PATH_CHANGE_MULT when changing Path).
static func training_cost(pool_id: String, change: bool = false) -> Dictionary:
	var c: Dictionary = (LEGEND_TRAINING if is_legend(pool_id) else SUBCLASS_TRAINING[subclass_stage(pool_id)]).duplicate()
	if change:
		for k in c:
			c[k] = int(c[k]) * PATH_CHANGE_MULT
	return c


## A hero's trees (0.62): the role tree (the role's own package) and, once
## trained, their Path's tree; one entry when the two share a package. Each is
## {"kind", "label", "path"} ("path" true for the Path tree).
static func hero_tree_summaries(h: Hero) -> Array:
	var role := hero_role(h)
	var role_kind := str(ROLE_KIND.get(role, "dmg_pct"))
	var path_id := h.path if h.path != "" else path_of(h.pool_id)
	if path_id == "" or not PATHS.has(path_id):
		return [{"kind": role_kind, "label": role.capitalize(), "path": false}]
	var pk := str(PATHS[path_id]["kind"])
	if pk == role_kind:
		return [{"kind": pk, "label": str(PATHS[path_id]["name"]), "path": true}]
	return [{"kind": role_kind, "label": role.capitalize(), "path": false}, {"kind": pk, "label": str(PATHS[path_id]["name"]), "path": true}]


## A node's old level gate as a rank (role tree) and a stage (Path tree).
static func _gate_rank(req_level: int) -> int:
	return 0 if req_level <= 2 else (1 if req_level <= 5 else (2 if req_level <= 7 else (3 if req_level <= 9 else 4)))


static func _gate_stage(req_level: int) -> int:
	return 0 if req_level <= 2 else (1 if req_level <= 5 else (2 if req_level <= 7 else 3))


## "" if `h` has reached the point where `n` (in the tree of `kind`) opens,
## else what's missing (0.62: skill trees open by rank and Path stage, not level).
static func node_lock(h: Hero, kind: String, n: Dictionary) -> String:
	var req := int(n.get("req_level", 1))
	var trees := hero_tree_summaries(h)
	var stage := subclass_stage(h.pool_id)
	var reasons: Array[String] = []
	for t in trees:
		if str(t["kind"]) != kind and not (str(n.get("id", "")) in ["edge", "hide", "signature"]):
			continue
		if bool(t["path"]):
			var need := _gate_stage(req)
			if stage >= need:
				return ""
			reasons.append(String(TranslationServer.translate("Path stage %d (trained at Rank %s)")) % [need, STAGE_RANK[need]])
		else:
			var need_r := _gate_rank(req)
			if rank_index(h.rank) >= need_r:
				return ""
			reasons.append(String(TranslationServer.translate("Rank %s")) % str(RANKS[need_r]["id"]))
	return String(TranslationServer.translate("Opens at %s")) % String(TranslationServer.translate(" or ")).join(reasons) if not reasons.is_empty() else String(TranslationServer.translate("Not in this hero's trees"))


## Laurels to carry `pool_id`'s unlock to a new guild (0 = open from the start anyway).
static func carry_laurels(pool_id: String) -> int:
	if (SUBCLASS_UNLOCK.get(pool_id, {}) as Dictionary).is_empty():
		return 0
	return LEGEND_CARRY_LAURELS if is_legend(pool_id) else int(SUBCLASS_CARRY_LAURELS[subclass_stage(pool_id)])


# ---------------- Techniques (stage 2) as skills ----------------
## A Path's Technique takes the role's second skill slot from stage 2, so it
## rides the role-skill pipeline (buttons, hotkeys, Auto): id "tech_<path>",
## "_2" for a 2-Momentum Twist, "_hp" when it costs HP instead of Momentum.
const TECH_SHAPE := {
	"shieldwall": {"target": "none", "row": "front", "icon": "res://assets/skills/sk_shield_wall.png"},
	"bloodrage": {"target": "none", "row": "any", "icon": "res://assets/skills/sk_berserkers_peak.png", "hp": true},
	"weaponmaster": {"target": "foe", "row": "any", "icon": "res://assets/skills/sk_flawless_strike.png"},
	"marksman": {"target": "foe", "row": "back", "icon": "res://assets/skills/sk_trueshot_aim.png"},
	"trapper": {"target": "none", "row": "any", "icon": "res://assets/skills/sk_ambush_doctrine.png"},
	"stalker": {"target": "foe", "row": "any", "icon": "res://assets/skills/sk_hunters_mark.png"},
	"evocation": {"target": "none", "row": "any", "icon": "res://assets/skills/sk_arcane_surge.png"},
	"warding": {"target": "none", "row": "any", "icon": "res://assets/skills/sk_warding_sigil.png"},
	"augury": {"target": "foe", "row": "any", "icon": "res://assets/skills/sk_precise_read.png"},
	"mercy": {"target": "none", "row": "any", "icon": "res://assets/skills/sk_mending_chant.png"},
	"aegis": {"target": "none", "row": "any", "icon": "res://assets/skills/sk_sanctuary.png"},
	"zeal": {"target": "foe", "row": "any", "icon": "res://assets/skills/sk_smite.png"},
	"assassin": {"target": "foe", "row": "any", "icon": "res://assets/skills/sk_shadow_strike.png"},
	"skirmisher": {"target": "none", "row": "any", "icon": "res://assets/skills/sk_phantom_step.png"},
	"scrapper": {"target": "foe", "row": "front", "icon": "res://assets/skills/sk_opportunist.png"},
}
const TECH_COST := 3
## Subclasses whose Twist makes their Technique cost 2.
const TECH_CHEAP := ["aegis-bearer", "wardweaver", "rift-medic", "shadowfoot"]


static func hero_path_id(h: Hero) -> String:
	return h.path if h.path != "" else path_of(h.pool_id)


## The Technique skill dict for `h`, or {} before stage 2.
static func hero_technique(h: Hero) -> Dictionary:
	var pid := hero_path_id(h)
	if pid == "" or subclass_stage(h.pool_id) < 2 or not TECH_SHAPE.has(pid):
		return {}
	var suffix := ""
	if TECH_SHAPE[pid].get("hp", false) or h.pool_id == "zealot":
		suffix = "_hp"
	elif TECH_CHEAP.has(h.pool_id):
		suffix = "_2"
	var sk := technique_skill("tech_" + pid + suffix)
	if pid == "marksman" and h.pool_id == "gale-marksman":
		sk["row"] = "any"   # Twist: Called Shot from the front row too
	return sk


## Builds a Technique skill from its id (see TECH_SHAPE).
static func technique_skill(id: String) -> Dictionary:
	var rest := id.trim_prefix("tech_")
	var suffix := ""
	for s in ["_hp", "_2"]:
		if rest.ends_with(s):
			suffix = s
			rest = rest.trim_suffix(s)
	if not PATHS.has(rest):
		return {}
	var shape: Dictionary = TECH_SHAPE[rest]
	var t: Dictionary = PATHS[rest]["technique"]
	var desc := String(TranslationServer.translate(str(t["desc"])))
	return {"id": id, "name": str(t["name"]), "level": 6, "cost": 0 if suffix == "_hp" else (2 if suffix == "_2" else TECH_COST),
		"row": str(shape["row"]), "target": str(shape["target"]), "effect": "tech:" + rest, "value": 1.0,
		"icon": str(shape["icon"]), "desc": desc.substr(0, 1).to_upper() + desc.substr(1), "technique": true}


## The skills a hero can use in a fight: the role's (by rank), with the
## second replaced by the Path's Technique from stage 2.
static func hero_skills(h: Hero) -> Array:
	var out: Array = hero_role_skills(h).duplicate()
	var tech := hero_technique(h)
	if not tech.is_empty():
		if out.size() >= 2:
			out[1] = tech
		else:
			out.append(tech)
	return out


## A role skill or a Technique by id.
static func find_skill_def(id: String) -> Dictionary:
	return technique_skill(id) if id.begins_with("tech_") else find_role_skill(id)



## Resonance (0.62): two or more heroes of one element in a party.
## [2 heroes, 3+ heroes] (Combat._resonance_start applies them).
const RESONANCE_TEXT := {
	"Ember": ["+6% damage", "+12% damage, and a kill sets the other foes burning"],
	"Frost": ["foes act 5% slower", "foes act 10% slower, and the fight's first foe hit is chilled"],
	"Verdant": ["+3% mending a round", "+6% mending a round"],
	"Umbral": ["+5% dodge", "+10% dodge"],
	"Arcane": ["+1 starting Momentum", "+2 starting Momentum, and Abilities cost 1 less"],
}
