extends "res://scripts/autoload/game_data/GameDataHeroes.gd"
## GameData, part 3: unique (Legendary) items and relics, Tower relics included.


## The attribute an item trains / needs.
static func item_attr_for(it) -> String:
	if it.unique_id != "":
		return str(UNIQUE_ARCH_ATTR.get(str(find_unique_item(it.unique_id).get("arch", "")), "might"))
	return str(ITEM_BASE_ATTR.get(item_base(it), "might"))

## Legendary items: fixed (never rolled) hero-bound gear. Their mechanic is
## plain data in "effects" — the shared EFFECT vocabulary Combat.hero_effects
## reads (see the doc comment above Combat.hero_effects for the entry shape) —
## plus, on most, a real drawback in the flat kind vocabulary so it still flows
## through hero_item_total/hero_skill_total for free. "locked_role"/
## "locked_subclasses" restrict who can equip it - "" / [] means no restriction.
const UNIQUE_ITEMS := [
	{"id": "bloodthirst_fang", "name": "Bloodthirst Fang", "category": "weapon", "arch": "sustain",
	 "effects": [{"trigger": "after_hit", "effect": "lifesteal", "value": 0.25}],
	 "drawback_kind": "hazard_guard_pct", "drawback_value": -0.15,
	 "locked_role": "", "locked_subclasses": [],
	 "desc": "Heals the wielder for 25% of the damage they deal each round they attack. -15% hazard severity guard."},
	{"id": "widows_edge", "name": "Widow's Edge", "category": "weapon", "arch": "executioner",
	 "effects": [{"trigger": "before_hit", "effect": "execute_below", "value": 0.15}],
	 "drawback_kind": "dmg_pct", "drawback_value": -0.10,
	 "locked_role": "", "locked_subclasses": [],
	 "desc": "Instantly finishes a foe this hero's attack would drop below 15% HP. -10% damage otherwise."},
	{"id": "last_stand_plate", "name": "Last Stand Plate", "category": "armor", "arch": "evasion",
	 "effects": [{"kind": "dodge_pct", "value": 0.30, "scale": "missing_hp"}],
	 "drawback_kind": "dodge_pct", "drawback_value": -0.10,
	 "locked_role": "", "locked_subclasses": [],
	 "desc": "The lower this hero's HP, up to +30% dodge chance near death. -10% dodge chance at full HP."},
	{"id": "oathbound_talisman", "name": "Oathbound Talisman", "category": "focus", "arch": "sustain",
	 "effects": [{"trigger": "party_mend", "effect": "shield_lowest", "value": 0.15}],
	 "drawback_kind": "dmg_pct", "drawback_value": -0.15,
	 "locked_role": "cleric", "locked_subclasses": [],
	 "desc": "Whenever the party mends, also shields the lowest-HP ally for 15% of their max HP. -15% damage. Cleric only."},
	# -- Build-defining additions, one or more per archetype, several built
	# around the speed/turn-order system specifically. --
	{"id": "reapers_due", "name": "Reaper's Due", "category": "weapon", "arch": "executioner",
	 "effects": [{"trigger": "on_kill", "effect": "extra_turn", "value": 1.0}],
	 "drawback_kind": "hp_pct", "drawback_value": -0.10,
	 "locked_role": "", "locked_subclasses": [],
	 "desc": "On a kill, this hero immediately acts again (once per round). -10% HP."},
	{"id": "quickening_band", "name": "Quickening Band", "category": "focus", "arch": "opener",
	 "effects": [{"kind": "dmg_pct", "value": 0.02, "scale": "speed_above_10"}],
	 "drawback_kind": "hp_pct", "drawback_value": -0.08,
	 "locked_role": "", "locked_subclasses": [],
	 "desc": "+2% damage for every point of Speed above 10. -8% HP."},
	{"id": "millstone_maul", "name": "Millstone Maul", "category": "weapon", "arch": "attrition",
	 "effects": [{"kind": "dmg_pct", "value": 0.50, "cond": {"acting_last": true}}],
	 "drawback_kind": "speed_pct", "drawback_value": -0.40,
	 "locked_role": "", "locked_subclasses": [],
	 "desc": "+50% damage when this hero is the last in the round to act. -40% Speed."},
	{"id": "hourglass_of_first_light", "name": "Hourglass of First Light", "category": "focus", "arch": "opener",
	 "effects": [{"kind": "dmg_pct", "value": 0.40, "cond": {"acting_first": true}}],
	 "drawback_kind": "hp_pct", "drawback_value": -0.08,
	 "locked_role": "", "locked_subclasses": [],
	 "desc": "+40% damage when this hero acts first in the round. -8% HP."},
	{"id": "wardens_oath", "name": "Warden's Oath", "category": "armor", "arch": "guardian",
	 "effects": [{"trigger": "ally_targeted", "effect": "intercept", "value": 0.60}],
	 "drawback_kind": "dodge_pct", "drawback_value": -0.10,
	 "locked_role": "", "locked_subclasses": [],
	 "desc": "60% chance to step in front of a blow aimed at an ally below half HP. -10% dodge chance."},
	{"id": "ember_of_the_last_hour", "name": "Ember of the Last Hour", "category": "focus", "arch": "executioner",
	 "effects": [{"kind": "dmg_pct", "value": 0.45, "cond": {"hp_below": 0.35}}],
	 "drawback_kind": "hp_pct", "drawback_value": -0.10,
	 "locked_role": "", "locked_subclasses": [],
	 "desc": "+45% damage while this hero is below 35% HP. -10% HP."},
	{"id": "chronoblade", "name": "Chronoblade", "category": "weapon", "arch": "evasion",
	 "effects": [{"trigger": "evade_or_heavy", "effect": "gain_momentum", "value": 0.60}],
	 "drawback_kind": "dmg_pct", "drawback_value": -0.08,
	 "locked_role": "", "locked_subclasses": [],
	 "desc": "60% chance to cool every Ability by 1 round when this hero dodges or takes a heavy hit. -8% damage."},
	{"id": "bossbane_spear", "name": "Bossbane Spear", "category": "weapon", "arch": "executioner",
	 "effects": [{"kind": "dmg_pct", "value": 0.40, "cond": {"vs_boss": true}}],
	 "drawback_kind": "first_round_pct", "drawback_value": -0.10,
	 "locked_role": "", "locked_subclasses": [],
	 "desc": "+40% damage in Boss fights. -10% first-strike damage."},
]

## Legendary relics: same idea as UNIQUE_ITEMS but party-wide. `effect`/`value`
## dispatch via Combat.party_has_unique_relic; drawback kinds are restricted
## to ones relic specials already aggregate into (mend/dodge/escalate/
## hazard_guard/first_round/wipe_guard - never dmg_pct/hp_pct, which relics
## have no path into). "combo_with" is another unique_id that, when also
## equipped, doubles this relic's own effect (checked by combo_partner_id).
const UNIQUE_RELICS := [
	{"id": "gamblers_coin", "name": "The Gambler's Gold", "type": "Ember",
	 "effect": "coinflip_dmg", "value": 0.0,
	 "drawback_kind": "", "drawback_value": 0.0, "drawback_label": "",
	 "combo_with": "",
	 "desc": "Each round: 50% chance the party's damage is doubled, 50% chance it's halved."},
	{"id": "ashes_of_the_fallen", "name": "Ashes of the Fallen", "type": "Umbral",
	 "effect": "desperation_dmg", "value": 0.30,
	 "drawback_kind": "hazard_guard_pct", "drawback_value": -0.10, "drawback_label": "-10% hazard severity guard",
	 "combo_with": "twin_embers",
	 "desc": "+damage the more wounded the party collectively is, up to +30% at the brink of death. -10% hazard severity guard."},
	{"id": "sable_standard", "name": "Sable Standard", "type": "Arcane",
	 "effect": "mono_role_dmg", "value": 0.25,
	 "drawback_kind": "", "drawback_value": 0.0, "drawback_label": "",
	 "combo_with": "",
	 "desc": "+25% team damage, but only while every living hero shares the same role."},
	{"id": "twin_embers", "name": "Twin Embers", "type": "Ember",
	 "effect": "", "value": 0.0,
	 "drawback_kind": "", "drawback_value": 0.0, "drawback_label": "",
	 "combo_with": "ashes_of_the_fallen",
	 "special_kind": "escalate_pct", "special_value": 0.02,
	 "desc": "+2% dmg/round (stacking) on its own. Paired with Ashes of the Fallen, that relic's desperation bonus doubles."},
	{"id": "phoenix_feather", "name": "Phoenix Feather", "type": "Ember", "effect": "phoenix", "value": 0.30,
	 "drawback_kind": "", "drawback_value": 0.0, "drawback_label": "", "combo_with": "",
	 "desc": "Once per rift, when the whole party falls, everyone rises again at 30% HP."},
	{"id": "wardens_seal", "name": "Warden's Seal", "type": "Umbral", "effect": "", "value": 0.0,
	 "drawback_kind": "", "drawback_value": 0.0, "drawback_label": "", "combo_with": "",
	 "special_kind": "hazard_guard_pct", "special_value": 0.2,
	 "desc": "-20% hazard severity."},
	{"id": "crown_of_oaths", "name": "Crown of Oaths", "type": "Arcane", "effect": "double_call", "value": 0.0,
	 "drawback_kind": "", "drawback_value": 0.0, "drawback_label": "", "combo_with": "",
	 "desc": "The Champion's Call can be used twice per rift."},
	{"id": "bloodpact", "name": "Bloodpact Dagger", "type": "Umbral", "effect": "bloodpact", "value": 0.35,
	 "drawback_kind": "", "drawback_value": 0.0, "drawback_label": "", "combo_with": "",
	 "desc": "+35% team damage, but the party never mends between rounds."},
	{"id": "quartermasters_ledger", "name": "Quartermaster's Ledger", "type": "Arcane", "effect": "quest_bonus", "value": 0.5,
	 "drawback_kind": "", "drawback_value": 0.0, "drawback_label": "", "combo_with": "",
	 "special_kind": "loot_rarity_pct", "special_value": 0.05,
	 "desc": "Quests pay 50% more Gold and Essence. +5% odds toward Rare/Epic loot."},
	{"id": "lantern_of_the_lost", "name": "Lantern of the Lost", "type": "Verdant", "effect": "free_carry", "value": 0.0,
	 "drawback_kind": "", "drawback_value": 0.0, "drawback_label": "", "combo_with": "",
	 "special_kind": "mend_pct", "special_value": 0.02,
	 "desc": "Carrying a downed hero out of a rift costs no day. Mends 2% HP/round."},
	{"id": "stopped_clock", "name": "The Stopped Clock", "type": "Frost", "effect": "frozen_round", "value": 0.0,
	 "drawback_kind": "first_round_pct", "drawback_value": -0.15, "drawback_label": "-15% first-strike damage", "combo_with": "",
	 "desc": "Foes can't act in the first round of a fight. -15% first-strike damage."},
	{"id": "mirror_shard", "name": "Mirror Shard", "type": "Frost", "effect": "mirror", "value": 0.0,
	 "drawback_kind": "", "drawback_value": 0.0, "drawback_label": "", "combo_with": "",
	 "desc": "Copies every special of your best other equipped relic."},
	{"id": "stormcaller_idol", "name": "Stormcaller Idol", "type": "Ember", "effect": "", "value": 0.0,
	 "drawback_kind": "", "drawback_value": 0.0, "drawback_label": "", "combo_with": "",
	 "trigger": {"trigger": "round_third", "effect": "nova", "value": 0.6},
	 "desc": "Every third round, lightning strikes every foe for 60% of the party's damage."},
	{"id": "prism_heart", "name": "Prism Heart", "type": "Arcane", "effect": "prism_heart", "value": 0.05,
	 "drawback_kind": "", "drawback_value": 0.0, "drawback_label": "", "combo_with": "",
	 "desc": "+5% team damage for each different element among your standing heroes."},
]


static func find_unique_item(unique_id: String) -> Dictionary:
	for u in UNIQUE_ITEMS:
		if u["id"] == unique_id:
			return u
	return {}


## A relic's icon: a Legendary's own, else its first special's, else its type gem.
static func relic_icon(r) -> String:
	var path := ""
	if r.unique_id != "":
		path = "res://assets/relics/u_%s.png" % r.unique_id
	elif not r.specials.is_empty():
		path = "res://assets/relics/%s.png" % str(r.specials[0]["kind"])
	if path != "" and ResourceLoader.exists(path):
		return path
	return RELIC_TYPE_ICON_PATH.get(r.type, CHEST_ICON_PATH)


static func find_unique_relic(unique_id: String) -> Dictionary:
	for u in UNIQUE_RELICS + TOWER_RELICS.values() + ENDLESS_RELICS.values() + PATH_RELICS:
		if u["id"] == unique_id:
			return u
	return {}

## Path relics (0.65): each bends one Path's rule (Combat._pm reads "pmod").
## Sealing a Rank D+ ladder rift offers 1 of 3 (two for the party's Paths).
## Legendary, fixed power; five carry a drawback ("pmod2"). Same lookup as the uniques.
const PATH_RELICS := [
	{"id": "p_bulwark_chain", "name": "Bulwark Chain", "type": "Ember", "path": "shieldwall", "pmod": "guard_share", "value": 0.15, "pmod2": "guard_taken", "value2": 0.1,
	 "desc": "Guardian takes 40% of the blows aimed at the back row (was 25%), but Shieldwall heroes take 10% more from blows aimed at them."},
	{"id": "p_oathplate_rivets", "name": "Oathplate Rivets", "type": "Ember", "path": "shieldwall", "pmod": "guard_momentum", "value": 1.0,
	 "desc": "When the Guardian takes a share of a blow: +1 Momentum, once a round."},
	{"id": "p_red_tooth_torc", "name": "Red Tooth Torc", "type": "Ember", "path": "bloodrage", "pmod": "rage_cap", "value": 0.2, "pmod2": "rage_heal_cut", "value2": 0.5,
	 "desc": "Bloodrage climbs to +60% damage (was +40%), but Bloodrage heroes heal half as much."},
	{"id": "p_grudge_knot", "name": "Grudge Knot", "type": "Ember", "path": "bloodrage", "pmod": "rage_pierce", "value": 0.3,
	 "desc": "Below 30% HP, a Bloodrage hero's hits ignore armour and wards."},
	{"id": "p_whetstone_of_habit", "name": "Whetstone of Habit", "type": "Ember", "path": "weaponmaster", "pmod": "combo_cap", "value": 2.0,
	 "desc": "Combo stacks two higher."},
	{"id": "p_duelists_ribbon", "name": "Duelist's Ribbon", "type": "Ember", "path": "weaponmaster", "pmod": "combo_pierce", "value": 1.0,
	 "desc": "At 4 Combo, hits on the same foe ignore armour and wards."},
	{"id": "p_owl_feather", "name": "Owl-Feather Fletching", "type": "Verdant", "path": "marksman", "pmod": "steady_keep", "value": 1.0,
	 "desc": "Steady Aim shrugs off the first hit each fight."},
	{"id": "p_long_sightline", "name": "Long Sightline", "type": "Verdant", "path": "marksman", "pmod": "steady_back", "value": 0.2,
	 "desc": "Steady Aim gives +55% from the back row (was +35%)."},
	{"id": "p_bramble_coil", "name": "Bramble Coil", "type": "Verdant", "path": "trapper", "pmod": "snare_two", "value": 1.0,
	 "desc": "In round 1 the snares take two foes."},
	{"id": "p_tripwire_bells", "name": "Tripwire Bells", "type": "Verdant", "path": "trapper", "pmod": "snare_dmg", "value": 0.15,
	 "desc": "Snared foes take 15% more damage from everyone."},
	{"id": "p_hunters_chalk", "name": "Hunter's Chalk", "type": "Verdant", "path": "stalker", "pmod": "mark_jump", "value": 1.0,
	 "desc": "When a marked foe falls, the Mark jumps to the next foe."},
	{"id": "p_blood_scent", "name": "Blood Scent", "type": "Verdant", "path": "stalker", "pmod": "mark_bonus", "value": 0.1,
	 "desc": "The party deals +25% to a marked foe (was +15%)."},
	{"id": "p_kindling_box", "name": "Kindling Box", "type": "Arcane", "path": "evocation", "pmod": "heat_start", "value": 2.0,
	 "desc": "Evocation heroes start every fight with 2 Heat."},
	{"id": "p_cinder_glass", "name": "Cinder Glass", "type": "Arcane", "path": "evocation", "pmod": "heat_at", "value": 1.0,
	 "desc": "Heat detonates one step sooner."},
	{"id": "p_loomed_sigil", "name": "Loomed Sigil", "type": "Arcane", "path": "warding", "pmod": "ward_two", "value": 1.0,
	 "desc": "Ward Weave covers the two most-hurt allies."},
	{"id": "p_thrice_knotted_thread", "name": "Thrice-Knotted Thread", "type": "Arcane", "path": "warding", "pmod": "ward_frac", "value": 0.04,
	 "desc": "Ward Weave wards 12% of max HP (was 8%)."},
	{"id": "p_second_sight", "name": "Second Sight", "type": "Arcane", "path": "augury", "pmod": "cancels", "value": 1.0,
	 "desc": "Foresight cancels one more heavy blow each fight."},
	{"id": "p_omen_bones", "name": "Omen Bones", "type": "Arcane", "path": "augury", "pmod": "cancel_momentum", "value": 2.0,
	 "desc": "A blow cancelled by Foresight gives +2 Momentum."},
	{"id": "p_brimming_chalice", "name": "Brimming Chalice", "type": "Frost", "path": "mercy", "pmod": "overflow", "value": 0.5, "pmod2": "heal_cut", "value2": 0.1,
	 "desc": "Overflow turns all overheal into a ward (was half), but all healing is 10% weaker."},
	{"id": "p_saints_tally", "name": "Saint's Tally", "type": "Frost", "path": "mercy", "pmod": "miracle_hp", "value": 0.15,
	 "desc": "A Miracle raises the fallen with 15% more HP."},
	{"id": "p_hallowed_mortar", "name": "Hallowed Mortar", "type": "Frost", "path": "aegis", "pmod": "sanctuary", "value": 0.03,
	 "desc": "Sanctuary cuts damage to the party by 9% (was 6%)."},
	{"id": "p_sanctum_chime", "name": "Sanctum Chime", "type": "Frost", "path": "aegis", "pmod": "aegis_hazard", "value": 0.25,
	 "desc": "With an Aegis hero in the party, hazards deal 25% less."},
	{"id": "p_burning_psalter", "name": "Burning Psalter", "type": "Frost", "path": "zeal", "pmod": "fervor", "value": 0.1, "pmod2": "zeal_taken", "value2": 0.1,
	 "desc": "Fervor heals 35% of damage dealt (was 25%), but Zeal heroes take 10% more damage."},
	{"id": "p_judgment_nail", "name": "Judgment Nail", "type": "Frost", "path": "zeal", "pmod": "zeal_momentum", "value": 1.0,
	 "desc": "A Zeal hero's kill gives +1 Momentum."},
	{"id": "p_widows_thread", "name": "Widow's Thread", "type": "Umbral", "path": "assassin", "pmod": "execute_at", "value": 0.1,
	 "desc": "Execute works below 45% HP (was 35%)."},
	{"id": "p_quiet_coin", "name": "Quiet Coin", "type": "Umbral", "path": "assassin", "pmod": "execute_resolve", "value": 1.0,
	 "desc": "The first Assassin kill each fight restores 1 Resolve."},
	{"id": "p_feather_step", "name": "Feather-Step Wraps", "type": "Umbral", "path": "skirmisher", "pmod": "evasion", "value": 0.1, "pmod2": "skirm_taken", "value2": 0.1,
	 "desc": "Evasion gives +25% dodge (was +15%), but a Skirmisher who is hit takes 10% more."},
	{"id": "p_riposte_cord", "name": "Riposte Cord", "type": "Umbral", "path": "skirmisher", "pmod": "jab", "value": 0.6,
	 "desc": "The dodge jab hits 60% harder."},
	{"id": "p_brawlers_knuckle", "name": "Brawler's Knuckle", "type": "Umbral", "path": "scrapper", "pmod": "scrappy", "value": 0.1,
	 "desc": "Scrappy heals 25% of damage dealt (was 15%)."},
	{"id": "p_pit_fighters_tape", "name": "Pit-Fighter's Tape", "type": "Umbral", "path": "scrapper", "pmod": "scrap_back", "value": 1.0,
	 "desc": "Scrappy's patch-up works in the back row too."},
]

## Relics the real-time Endless Rift gave (until 0.63); kept for the guilds that hold them.
const ENDLESS_RELICS := {
	"e_warden_shard": {"id": "e_warden_shard", "name": "Warden's Shard", "type": "Arcane", "trigger": {"trigger": "on_kill", "effect": "mend_party", "value": 0.06},
		"desc": "Every kill mends the party 6%."},
	"e_rift_heart": {"id": "e_rift_heart", "name": "Heart of the Rift", "type": "Umbral", "trigger": {"trigger": "round_third", "effect": "nova", "value": 0.4},
		"desc": "Every third round, a nova hits every foe for 40% of your damage."},
}

## Relics only the Tower's guardians give (first clear of that floor). Same
## schema as UNIQUE_RELICS; only special_kind/trigger, no bespoke effects.
const TOWER_RELICS := {
	10: {"id": "t_gate_key", "name": "Gatekeeper's Key", "type": "Arcane", "special_kind": "first_round_pct", "special_value": 0.3,
		"desc": "+30% first-strike damage."},
	20: {"id": "t_mire_lantern", "name": "Mire Lantern", "type": "Verdant", "special_kind": "mend_pct", "special_value": 0.04,
		"desc": "Mends 4% HP every round."},
	30: {"id": "t_cinder_brand", "name": "Cinder Brand", "type": "Ember", "special_kind": "escalate_pct", "special_value": 0.04,
		"desc": "+4% damage every round (stacking)."},
	40: {"id": "t_choir_bell", "name": "Choir Bell", "type": "Arcane", "trigger": {"trigger": "round_third", "effect": "shield_party", "value": 0.15},
		"desc": "Every third round, shields the whole party for 15% of max HP."},
	50: {"id": "t_tide_mirror", "name": "Tide Mirror", "type": "Frost", "special_kind": "dodge_pct", "special_value": 0.12,
		"desc": "+12% dodge chance."},
	60: {"id": "t_regent_crown", "name": "Regent's Crown", "type": "Ember", "special_kind": "boss_alpha_strike", "special_value": 0.6,
		"desc": "+60% opening volley against bosses."},
	70: {"id": "t_grave_thread", "name": "Gravewright's Thread", "type": "Umbral", "special_kind": "wipe_guard", "special_value": 0.35,
		"desc": "Relic ward: once a fight, survive a wipe at 35% HP."},
	80: {"id": "t_oracle_eye", "name": "Oracle's Eye", "type": "Frost", "special_kind": "counter_pct", "special_value": 0.3,
		"desc": "+30% chance to counter when evading or hit hard."},
	90: {"id": "t_ashfather_coal", "name": "Ashfather's Coal", "type": "Ember", "trigger": {"trigger": "round_third", "effect": "nova", "value": 0.8},
		"desc": "Every third round, fire strikes every foe for 80% of the party's damage."},
	100: {"id": "t_summit_star", "name": "Summit Star", "type": "Arcane", "special_kind": "escalate_pct", "special_value": 0.05,
		"trigger": {"trigger": "round_third", "effect": "nova", "value": 1.0},
		"desc": "+5% damage every round (stacking), and every third round a starfall hits every foe for 100% of the party's damage."},
}
