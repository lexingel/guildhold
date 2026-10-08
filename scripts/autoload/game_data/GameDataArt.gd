extends Node
## Static data tables — a near-mechanical port of the `const` tables in
## guild-system.html. No behavior lives here, only data, mirroring the
## HTML prototype's data/logic split. Keys use snake_case per GDScript
## convention; the JS camelCase originals are named in comments where it
## helps cross-reference the source.

const BOSS_ENRAGE_ROUND := 4

# Icon paths — relic-type gems and item-category icons were extracted
# pixel-identical from guild-system.html's embedded base64 (RELIC_TYPE_ICON/
# ITEM_CATEGORY_ICON) into assets/icons/; monster sprites and the chest icon
# were already individually-named files from the earlier asset-slicing pass.
const RELIC_TYPE_ICON_PATH := {
	"Ember": "res://assets/icons/relic_ember.png",
	"Frost": "res://assets/icons/relic_frost.png",
	"Verdant": "res://assets/icons/relic_verdant.png",
	"Umbral": "res://assets/icons/relic_umbral.png",
	"Arcane": "res://assets/icons/relic_arcane.png",
}
const ITEM_CATEGORY_ICON_PATH := {
	"weapon": "res://assets/icons/item_weapon.png",
	"armor": "res://assets/icons/item_armor.png",
	"focus": "res://assets/icons/item_focus.png",
}
const CHEST_ICON_PATH := "res://assets/dungeon/chest_icon.png"

## AI-generated battle backdrops — one picked at random per encounter (stored
## on the combat state at start_combat so it doesn't change across renders of
## the same fight), not tied to monster type, matching "different rifts are
## different worlds" — the backdrop varies independent of what you're fighting.
const BATTLE_BACKGROUNDS: Array[String] = [
	"res://assets/battle/bg_dungeon.png",
	"res://assets/battle/bg_forest.png",
	"res://assets/battle/bg_cavern.png",
	"res://assets/battle/bg_ruins.png",
	"res://assets/battle/bg_volcanic.png",
	"res://assets/battle/bg_swamp.png",
	"res://assets/battle/bg_tundra.png",
	"res://assets/battle/bg_skyfallen_ruins.png",
	"res://assets/battle/bg_abyssal_chasm.png",
	"res://assets/battle/bg_arcane_observatory.png",
	# Book II stand-ins (recoloured): the Glass Coast 10-12, the Inverted City 13-15.
	"res://assets/battle/bg_glass_shore.png", "res://assets/battle/bg_glass_caves.png", "res://assets/battle/bg_glass_ruins.png",
	"res://assets/battle/bg_city_spires.png", "res://assets/battle/bg_city_vault.png", "res://assets/battle/bg_city_chasm.png",
]
const CURRENCY_ICON_PATH := {
	"coins": "res://assets/ui/icon_coins.png",
	"crystals": "res://assets/ui/icon_crystals.png",
	"reputation": "res://assets/skills/trophy.png",
}

## Escort quests: a fragile NPC that occasionally tags along on a "combat"
## node (Combat.start_combat), which monster retaliation can hit instead of
## a hero. Purely flavor text — reused across every escort roll, no per-name
## mechanical difference.
const ESCORT_NAMES := ["Wounded Survivor", "Lost Scout", "Stranded Merchant", "Frightened Pilgrim"]

## Guild Board: a rotating pool of "contract" (small, quick) and "daily"
## (bigger target, bigger reward including Reputation) quests. `type` is
## looked up against GameState.quest_progress()'s match — kept here only as
## the id/label pairing so a new type is a one-line add in both places.
## Features open up as the guild grows instead of all at once (the reveal
## schedule, docs/design/focus_2026_10.md). Each entry: its gate, read by
## GameState.feature_unlocked ("seals": rifts sealed, "act": campaign act
## reached, "act_days": days into that act; entries without a gate have their
## own rule there) and how it is announced: a story card from "who" when set,
## else a toast. Roster, Recruits, Rift Hall and the Codex are always open.
const FEATURE_UNLOCKS := {
	"inventory": {"name": "Inventory", "hint": "Opens once you find your first item", "news": "Loot you find is kept here — equip items on the Roster's Hero tab."},
	"medical": {"name": "Medical Bay", "hint": "Opens after your first rift run", "news": "Wounded and downed heroes recover faster in a bed."},
	"bestiary": {"name": "Bestiary", "hint": "Opens after your first fight", "news": "Every foe you meet is recorded here."},
	"quests": {"name": "Quests", "hint": "Opens after you seal your first rift", "seals": 1, "news": "Take on quests for Gold, Essence and Renown."},
	"training": {"name": "Training Yard", "hint": "Opens after you seal 2 rifts", "seals": 2, "who": "Wen, the Chronicler",
		"news": "\"Two rifts sealed, and the yard behind the barracks is finally clear of rubble. Send a hero there for a few days and they come back stronger: an attribute point, a new program. The Drill Yard room adds places.\""},
	"management": {"name": "Accord Hall", "hint": "Opens after you seal 2 rifts", "seals": 2, "who": "Wen, the Chronicler",
		"news": "\"This camp was an Accord hall once. The Barracks, the Infirmary and the Drill Yard can be rebuilt now, room by room, with Gold. Each level costs a little upkeep. More rooms open as the guild grows.\" (Guild > Accord Hall)"},
	"requests": {"name": "Hero requests", "hint": "Opens after you seal 3 rifts", "seals": 3, "news": "Twice a week a hero may ask for something: time off, a partner, a rift of their own. Say yes for their trust, or no."},
	"champions": {"name": "Champions", "hint": "Opens when you free your first champion (the end of Act I)", "news": "A champion oversees your rift runs: their Boon for the party and their Call. Choose one and level them up under Roster > Champions."},
	"forge": {"name": "The Smithy", "hint": "Opens when you complete Act I", "act": 2, "who": "Dobbs, the Quartermaster",
		"news": "\"Found a smith who'll work for our rates. Bring her any piece a hero wears and she'll temper it: every stat on it a little higher, for Gold. Each temper costs more than the last.\" (Roster > a hero's item)"},
	"relics": {"name": "Relics", "hint": "Opens when you complete Act I", "act": 2, "news": "Relics bend the rules of a fight for the whole guild. Equip them under Inventory > Relics; you have a few slots."},
	"rival": {"name": "Rival moves", "hint": "Opens a day into Act II", "act": 2, "act_days": 1, "news": "Once a week the rival guild may court a hero, dare you, or go after a contract. Answer before payday."},
	"resolve": {"name": "Resolve and the haul", "hint": "Opens a day into Act II", "act": 2, "act_days": 1, "who": "Old Hesper",
		"news": "\"The easy rifts are behind you. From now on a party carries Resolve: hard floors and hazards wear it down, rests and shrines bring it back, and a party that breaks hits softer. And what you carry is at risk: lose the boss, or run, and part of the haul stays down there.\""},
	"hall_rooms": {"name": "More hall rooms", "hint": "Opens two days into Act II", "act": 2, "act_days": 2, "news": "The Infrastructure and Logistics rooms can be rebuilt now: Essence Amplifiers, Wardstones, the Trade Network and the Scouts' Lodge (Guild > Accord Hall)."},
	"wardcraft": {"name": "Wardcraft", "hint": "Opens when the first rift swells into a breach", "news": "The Armory, Quartermaster, Palisade and Watchtower soften breach rifts (Guild > Accord Hall)."},
	"crafting": {"name": "Reforge and combine", "hint": "Opens when you complete Act II", "act": 3, "who": "Dobbs, the Quartermaster",
		"news": "\"The smith has taken on an apprentice. Now she can reforge one stat on an item for Essence, and melt three spare pieces into one better one.\" (Inventory > Crafting)"},
	"hall_research": {"name": "Research rooms", "hint": "Opens when you complete Act II", "act": 3, "news": "The Relic Vault and the Arcane Lab can be rebuilt now (Guild > Accord Hall)."},
	"daily": {"name": "Daily twist", "hint": "Opens when you complete Act II", "act": 3, "act_days": 1, "news": "Once a day a ladder rift can carry a twist: a special rule and a starting boon, for extra Essence. Tick it in the Rift Hall."},
	"tower": {"name": "Tower of Trials", "hint": "Opens when you complete Act III", "act": 4, "news": "100 fixed floors in the Rift Hall. Each floor is always the same fight, and pays the first time you clear it."},
}
## Which Accord Hall rooms (GameData.BRANCHES ids) each reveal opens.
const BRANCH_FEATURE := {"ops": "management", "infra": "hall_rooms", "log": "hall_rooms", "def": "wardcraft", "res": "hall_research"}

## One-shot SFX, all CC0 (Kenney.nl — Interface Sounds/RPG Audio/Impact
## Sounds packs, see assets/audio/sfx/KENNEY_LICENSE.txt). Every key here is
## safe to reference from any call site regardless of whether the file
## exists yet — AudioManager.play_sfx no-ops gracefully on a missing path,
## the same contract GameData.monster_anim_frames uses for its own gaps.
const SFX_PATH := {
	"ui_click": "res://assets/audio/sfx/ui_click.ogg",
	"ui_back": "res://assets/audio/sfx/ui_back.ogg",
	"ui_confirm": "res://assets/audio/sfx/ui_confirm.ogg",
	"ui_error": "res://assets/audio/sfx/ui_error.ogg",
	"coin": "res://assets/audio/sfx/coin.ogg",
	"attack": "res://assets/audio/sfx/attack.ogg",
	"hit": "res://assets/audio/sfx/hit.ogg",
	"hit_heavy": "res://assets/audio/sfx/hit_heavy.ogg",
	"knockout": "res://assets/audio/sfx/knockout.ogg",
	"victory": "res://assets/audio/sfx/victory.ogg",
	"craft": "res://assets/audio/sfx/craft.ogg",
	# 0.69: made from the sounds here by tools/derive_sfx.py (a Path's moment,
	# foes by region, camp, the map, Resolve).
	"path_shieldwall": "res://assets/audio/sfx/path_shieldwall.ogg",
	"path_bloodrage": "res://assets/audio/sfx/path_bloodrage.ogg",
	"path_weaponmaster": "res://assets/audio/sfx/path_weaponmaster.ogg",
	"path_marksman": "res://assets/audio/sfx/path_marksman.ogg",
	"path_trapper": "res://assets/audio/sfx/path_trapper.ogg",
	"path_stalker": "res://assets/audio/sfx/path_stalker.ogg",
	"path_evocation": "res://assets/audio/sfx/path_evocation.ogg",
	"path_warding": "res://assets/audio/sfx/path_warding.ogg",
	"path_augury": "res://assets/audio/sfx/path_augury.ogg",
	"path_mercy": "res://assets/audio/sfx/path_mercy.ogg",
	"path_aegis": "res://assets/audio/sfx/path_aegis.ogg",
	"path_zeal": "res://assets/audio/sfx/path_zeal.ogg",
	"path_assassin": "res://assets/audio/sfx/path_assassin.ogg",
	"path_skirmisher": "res://assets/audio/sfx/path_skirmisher.ogg",
	"path_scrapper": "res://assets/audio/sfx/path_scrapper.ogg",
	"foe_hit_vale": "res://assets/audio/sfx/foe_hit_vale.ogg",
	"foe_hit_marsh": "res://assets/audio/sfx/foe_hit_marsh.ogg",
	"foe_hit_ashen": "res://assets/audio/sfx/foe_hit_ashen.ogg",
	"foe_hit_glass": "res://assets/audio/sfx/foe_hit_glass.ogg",
	"foe_hit_city": "res://assets/audio/sfx/foe_hit_city.ogg",
	"foe_down_vale": "res://assets/audio/sfx/foe_down_vale.ogg",
	"foe_down_marsh": "res://assets/audio/sfx/foe_down_marsh.ogg",
	"foe_down_ashen": "res://assets/audio/sfx/foe_down_ashen.ogg",
	"foe_down_glass": "res://assets/audio/sfx/foe_down_glass.ogg",
	"foe_down_city": "res://assets/audio/sfx/foe_down_city.ogg",
	"dodge": "res://assets/audio/sfx/dodge.ogg",
	"guard": "res://assets/audio/sfx/guard.ogg",
	"ward": "res://assets/audio/sfx/ward.ogg",
	"boss_down": "res://assets/audio/sfx/boss_down.ogg",
	"elite_down": "res://assets/audio/sfx/elite_down.ogg",
	"camp_event": "res://assets/audio/sfx/camp_event.ogg",
	"camp_dilemma": "res://assets/audio/sfx/camp_dilemma.ogg",
	"camp_omen": "res://assets/audio/sfx/camp_omen.ogg",
	"tab": "res://assets/audio/sfx/tab.ogg",
	"node_pick": "res://assets/audio/sfx/node_pick.ogg",
	"resolve_down": "res://assets/audio/sfx/resolve_down.ogg",
	"resolve_waver": "res://assets/audio/sfx/resolve_waver.ogg",
	"relic_pick": "res://assets/audio/sfx/relic_pick.ogg",
	"title": "res://assets/audio/sfx/title.ogg",
	"payday": "res://assets/audio/sfx/payday.ogg",
	# CC0 sounds picked by ear (see assets/audio/sfx/CREDITS.txt); burn and
	# chill are still synthesized by tools/gen_sfx.py.
	"windup": "res://assets/audio/sfx/windup.ogg",
	"stun": "res://assets/audio/sfx/stun.ogg",
	"burn": "res://assets/audio/sfx/gen_burn.wav",
	"chill": "res://assets/audio/sfx/gen_chill.wav",
	"shield": "res://assets/audio/sfx/shield.ogg",
	"heal": "res://assets/audio/sfx/heal.ogg",
	"ability": "res://assets/audio/sfx/ability.ogg",
	"relic": "res://assets/audio/sfx/relic.ogg",
	"level_up": "res://assets/audio/sfx/level_up.ogg",
	"unlock": "res://assets/audio/sfx/unlock.ogg",
	"story": "res://assets/audio/sfx/story.ogg",
	"defeat": "res://assets/audio/sfx/defeat.ogg",
	"boss": "res://assets/audio/sfx/boss.ogg",
}

## The tester build: what changed lately and what to try, shown on the title
## screen (newest first, a few lines each).
## The languages the game speaks: [locale, its own name for itself].
const LANGUAGES := [["en", "English"], ["tr", "Türkçe (beta)"], ["es", "Español (beta)"], ["zh_CN", "简体中文 (beta)"]]

const WHATS_NEW := [
	"One new thing at a time. A new guild starts with heroes, rifts, fights and payday; the rest comes in turn, brought in by Wen, Dobbs or Hesper: the Training Yard and the hall's first rooms after two seals, the Smithy and relics with Act I's finale, the rival, Resolve and the haul a day into Act II, reforging and the Daily twist in Act III, the Tower in Act IV. A player whose past guild got past Act I has all of Act II's from day 1. The Accord Hall is one tree now: its 13 rooms are built with Gold, and at the end of Acts I, III and V you choose one of two wings (3 of 6 per guild), each with a new effect. Heroes on a Path can train Path Mastery for Essence: each rank makes their Path rule 4% stronger.",
	"Fixes from the review: a reload in the middle of a fight puts the party back as it stood before it, so the fight starts over fairly (and running from it afterwards costs the haul, as fleeing does). The hazard card now shows exactly what lands, Pathfinder and Scavenger included. A key left waiting in Settings no longer catches a later press; moved keys stay in fights and the hints name them. Resolve isn't sold while it doesn't count. The daily score counts Resolve only where it drains and scales with the difficulty. Phones: the map's legend wraps, Resolve shows in a fight, and the attack shows its damage on the foe. Story cards waiting to be read survive a reload. The sound effects are loudness-matched. Settings > Send feedback can share play milestones with the developer, if you tick it.",
	"Five Path relics now carry a drawback, as designed: Bulwark Chain, Red Tooth Torc, Brimming Chalice, Burning Psalter and Feather-Step Wraps. Each stop on the rift map says what it costs or gives back in Resolve. Hardship levels were checked in a full simulation: the Recommended power stays honest at every level.",
	"Deeper rifts and a busier guild. Resolve: a party sets out with 8 and loses some with every floor, elite, risky hazard and fled fight; campfires, shrines and some events give it back. At 3 or less foes strike first; at 0 the heroes also lose their Momentum. Sealing a Rank D or higher rift offers one of 30 Path relics, each bending a Path's rule (or Essence instead). The camp has 15 new events and heroes 20 new requests, twice a week, that leave quirks, bonds and titles; heroes earn titles for their deeds and can be renamed on their page. A new guild picks its difficulty: Story, Standard, or a Hardship once a guild has reached Act IV. Hovering a fight command shows the damage it would deal, and Settings > Controls moves the fight keys. About 40 new sounds. The game speaks Spanish, and Simplified Chinese on desktop (both beta). A sealed daily twist has a score you can post to the day's board.",
	"A simpler, deeper guild. Rifts are maps now: lanes that cross (3 at the low ranks, up to 5 at the top), so you plan a route, with a campfire before every boss and new stops along the way (an anvil that tempers a piece for free, a Path's shrine, a trainer's echo); from Rank S the far floors stay unseen unless a Trapper or a Stalker scouts. The camp lives: on about a third of days a merchant, a visiting hero, a wandering recruit or a dilemma turns up, and threats like fire, fever, bandits and storms are foretold the evening before, so you can pay, send a hero, or take the loss. Breaches are held in a breach rift (fights back to back, no camp between them) instead of the tower defense, and the Defenses research is now Wardcraft, which softens them. The real-time Endless Rift is resting for now: its gate leads down the Descent. A saved Descent also remembers its depth now.",
	"Attack and skill animations no longer snap back to the stance after the blow: heroes and foes now play the motion back out, so every swing, shot and cast finishes.",
	"Attacks hit harder on screen: warriors and rogues wind up before they dash in and the blow lands with a jolt; rangers draw and the arrow leaves the bow on the release; mages and clerics gather light in the hand before the bolt flies. New attack animations: the base Ranger, Mage and Cleric, seven rangers who now raise and draw their bows, the Ashen Templar and the Hearth-Warden.",
	"Raising Abilities (Faster Than the Wounds, One More Round) raise a fallen ally once a fight now, at 35% and 30% HP; after that they heal. Mercy's Overflow no longer counts the party's mend, and its tree's mend nodes are lower. The Marksman's Signature is now called Held Breath, so it isn't confused with the ranger's Overwatch row bonus.",
	"A hero's page has a Path tab now: their Path's three stages side by side, the Twist, and the rank and XP bar with Evolve and training. The Skills tab is shorter, so the skill tree starts higher up. Base-class heroes animate in fights. Tuning: Called Shot hits harder, snares bite harder, Benediction heals 10% (was 15%) and Overflow turns half the overhealing into a ward.",
	"Paths: heroes are hired as base classes and grow into one of 15 Paths (3 per role). Every rank is levels 1-10 now, and evolving at 10 starts the next rank at level 1 with +20% XP for two runs; raised heroes end up a little stronger than hired ones, hired ones bring more skill points. At Ranks D, B and S a hero trains at the Training Yard: stage 1 brings the Path's rule (a Bloodrager hits harder the more hurt they are, a Marksman lines up a steady shot), stage 2 a Technique in place of the role's second skill, stage 3 a once-a-fight Signature moment or the role's Legend. Every subclass bends its Path with its own Twist. New subclasses unlock with acts, Tower floors and deeds (Codex › Paths), and a new guild can carry them over with Laurels. Heroes sharing an element now Resonate in a party. Your heroes keep their subclasses; their skill points were refunded to spend again.",
	"Before each fight the room now shows your party's health and the foes waiting there (the same ones you'll fight), so Engage or Retreat is an informed choice.",
	"When Essence piles up, the Grow line now also names a relic level on the Relic Altar or a Guild Management level that strengthens the party (Arcane Lab, Relic Vault, Wardstones).",
	"The Guild status board's Grow line now speaks up whenever Gold or Essence is piling up, not only when the guild is stuck: it names a Forge temper, a hall wing, an evolution or a stronger recruit you can afford.",
	"Recommended power now tells the truth: at Recommended a party seals a rift about 2 times in 3. Rank E and up, and especially the act finales, used to read Even when the odds were 1 in 5 to 1 in 2, so the numbers are higher now (fights themselves are unchanged).",
	"Gold buys power now. The Forge tempers any item for Gold (up to 5 times, +6% to its stats each), from the item's pop-up or the gear slot a hero wears it in. Hall Works rebuild your guild hall wing by wing once Act I is done: War Room, Chapel, Smithy, Library, Healers' Wing and Reliquary, each a lasting bonus for the whole guild (Guild Hall > Hall Works). Your first party starts with your three heroes already in it.",
	"The credits now have a Founding Testers section: play this test build and send your feedback to have your name there. A long guild name no longer pushes the top bar off the screen.",
	"The opening's eight pictures are redrawn in the crisp new style, from the Accord's hall to the villagers waiting for a guild.",
	"The title screen, the Rift Hall, the Roster, Items, Management, Medical Bay and Crafting backdrops, the rift shop and every hazard are redrawn in the crisp new style. Spoken lines now dip the music while they play, and the opening's narration is never interrupted by the camp's music or a story card.",
	"A hero can now be dismissed from their own page in the Roster, as well as from the payroll on the Ledger.",
	"Music: every region now has its own theme. The Shattered Vale, the Drowned Marches, the Ashen Wastes, the Glass Coast and the Inverted City each play theirs for the whole rift run, and the Endless Rift and the Descent play the Accord Hall's.",
	"End day: a campfire button in the top bar ends the day from any camp screen, without a run. Hover it to see what tomorrow brings: payday and whether you can pay, who finishes training, who is back on their feet, and a rift about to break.",
	"The Training Yard: send heroes to train Might, Agility or Focus for 1, 2 or 3 days. Each day gives +1 attribute point, longer courses also give XP (up to your best hero's level), and you can watch them drill in the camp's courtyard. Trainees sit out runs; the yard has 2 stations and grows to 4 with the Drill Yard. It replaces buying points with Gold.",
	"A new look: every fight now has a crisp, detailed backdrop drawn to match the heroes and foes, and the camp has become the ruins of an old Accord guild hall that your guild rebuilds as it grows, from scaffolding to a restored hall. Long sealing reports no longer stretch the screen.",
	"The haul: what a rift run earns is only safe once the party is home. If the party falls, half of it is lost; fleeing a fight drops a quarter; sealing the rift or leaving between floors keeps it all. The run bar shows the haul, and at a boss's door you see what's at stake and can still retreat. A guild's first three seals are spared.",
	"Pixel-perfect fights: heroes and foes are now drawn at a whole number of screen pixels per art pixel at any window size, so no pixel comes out wider than its neighbours. Heroes use their full art canvas like the foes, so they no longer change size when they attack, and Morrow and the First Signatory fight in their own portraits.",
	"Playtest build. The Feedback report now notes when you reached each milestone (founding, first seal, first payday, each act), still only on your screen until you paste it. The Grow goal only suggests hiring or drilling once a guild is really stuck, the founding options' toggle draws properly, and narrow desktop windows no longer ask you to turn your phone.",
	"The guild status board now opens on three goals: the story's next step, the best way to grow stronger, and one thing worth doing on the side. New item icons for every weapon, armour and legendary, the Pearl Colossus and the Ember Whelp redrawn, and a smaller download: the game loads about a fifth faster.",
	"Fights hit harder: every blow flashes and lands with a short pause, attacks wind up before they strike, and each way of fighting has its own effect: a cleave for warriors, a twin cut for rogues, an arrow strike, a holy strike, a burst for each mage element, and claws, spells or acid from foes. Cards have pixel corners, and icons stay crisp.",
	"Foes face the right way: in Riftbreak they no longer walk backwards down the road, and Korrath, Captain Morrow, the Spire Oracle, the Rooftop Harrier and the Tideglass Moth turn toward your heroes. Founding a guild is calmer: name and crest up front, everything else under Founding options. Loot is mostly gear now (8 in 10 drops in Act I, 7 in 10 after), so fewer spare relics pile up.",
	"Skip the opening and the narrator still reads the Night of Breaking to you, Hesper's version too for a guild founded on the old oath.",
	"The Vale has voices: the narrator reads the story cards, Wen, Dobbs and Hesper talk at the pay table, and the rival leaders read out their letters, Brannoch his memory. Settings has a Voice volume and an on/off switch, and Listen plays a scene again. English only for now.",
	"Four foes redrawn to match the rest of the Vale: the Mire Sniper, the Voidling Sprite, the Choir Sprite and the Falling Sky itself, each with new attacks and walks. The Glass Coast and Inverted City grounds are calmer, so heroes stand out on them.",
	"Every hero now has new art: the clerics in white and gold and the rogues in dark violet join the warriors, rangers and mages, each with a new portrait, new attack, hit and skill animations and a new Endless Rift walk. Champions swing, flinch and cast as themselves instead of turning into a plain warrior mid-fight. Every skill has its own icon, the Tower's and the Endless Rift's legendary relics have theirs, the Glass Coast and the Inverted City have their own ground, the Open Hollow has a picture, and two heroes of the same kind keep their role's colour.",
	"New portraits for every warrior, ranger and mage, in their role colours: red tabards on the warriors, green cloaks on the rangers, blue robes on the mages. Each has new attack, hit and skill animations and a new walk in the Endless Rift. Clerics and rogues are next.",
	"The story has pictures: every act, the big choices and every ending now open on an illustration, from the rift splitting the Vale to the last door between the worlds.",
	"The Terms, Act IV's finale, has its own shape at last: the Grandmaster's, written in green ink. The rival guilds' leaders have their own portraits, Morrow included, and Wen, Dobbs and Hesper have faces at the pay table.",
	"New art for the Sky Beneath: all 30 foes of the Glass Coast and the Inverted City, with their own attacks and walks, and six new battle backgrounds. Hesper and Vaelith have their own portraits as champions, with a walk and a signature move in the Endless Rift; Morrow and the First Signatory have theirs when they join your guild; and the seven Accord halls have pictures on the Keepers of the Vale tab.",
	"When a guild is stuck on an act's objectives because its heroes are too weak, the Act panel now says what would help after a week, not only once the finale is open. And Act III's wardens stop hiding: while Korrath or Drevok is still to be beaten, a rift in his region always ends with him.",
	"A new choice at the Drowned Spire: carry out the Accord's archive or save Hollin, the village down the hill. Every guild meets it, and both sides come back later. Choices you already make come back too: the crossings you let through and Brannoch's door change Book II's ending, keeping quiet or holding the Royal Charter changes Book II, and Vaelith, Ezra's lantern, Mother Ilse and Morrow each turn up again. Holding the Charter, the Crown pays double for turning crossings back.",
	"When a finale is out of reach, the Act panel now says what would help, with costs: evolve this hero, hire that recruit, build the Drill Yard, level your champion. A finished guild can endow the next one with its spare Gold, and a lost tide costs half as much. The Vale remembers more: heirs of remembered heroes, Accord-Sworn and Tide-Hardened recruits after a past guild's ending, one Bestiary across guilds, banner colours earned in the Hall, rivals with a grudge, and the Hall's records.",
	"Feats: every elite, boss, pillar and finale sets one optional objective that suits the fight: break a wind-up, win by round 4, bank 8 Momentum, down a named foe first, two at once, or stay on your feet. Done by hand, it pays 40% more Gold and Essence, and an elite offers a fourth boon. Also: a past guild's choices only open the story web's gates for later guilds, not for itself.",
	"The Unwritten Accord, part three: the Far Side and the Witnesses. Whose Terms they really were, what knocked on the Night of Breaking, and who signed first. Kael Ashborn and the Hollow's own people tell their versions. New choices for guilds that know enough: let the Choir sing, leave Brannoch at his door or free him, and a sixth crossing. And for a player who has learned it all, an epilogue that changes the Vale for every guild after.",
	"The Unwritten Accord, part two: the Key and the Lantern. Who opens the rifts, who pays for it, and what Essence really is. Mother Ilse, Captain Morrow and Ser Aldric tell their own versions in their letters. New choices for guilds that know enough: buy Morrow, buy the Crown's hearing, keep or break the key, pour your echoes into Ezra's lantern. And two charters a truth opens: Vaelith's Rangers and the Ninth Lamp.",
	"The Unwritten Accord, part one: the Vale's story now spreads across your guilds. Fragments turn up in rifts, on relics, in rival letters and at the pay table, and every later guild keeps them. Any two of a truth's fragments make it known (Library > Codex > Truths), and witnesses' claims are struck through or confirmed as you learn. Some truths open choices a first guild never gets.",
	"Text that matches the game: the Mercenary and Temple charters say how much more or less Gold they start with, the Break ending describes its weekly tides, the Warded boss and some Awakened Abilities say what they really do, and the Laurels count lists every source.",
	"The Accord Hall's finale grows less with every lost champion you free (2% each, was 5%), and when a finale is beyond your best party, the Act panel says how far, and what raises your power.",
	"The Sky Beneath, continued: the real-time Endless Rift can now be run on the Glass Coast and in the Inverted City once you reach them, Hollow-born heroes look like they came from the far side, and the Hall of Guilds remembers whether a guild kept the doors open.",
	"Book II, the Sky Beneath: after the Accord's ending (any of the three), a reply turns up on the ledger's last page, and two more acts open under the Accord Hall. Act V, the Glass Coast; Act VI, the Inverted City. 30 new foes, crossings to answer, a gate to hold, and one more choice at the end. (The new regions use recoloured art for now; their own art is coming.)",
	"New systems now arrive more gradually: the rival's moves at the third sealed rift, Crafting at the fifth, and the Daily twist at the seventh, after Act I's finale.",
	"The Grandmaster's ledger no longer hides behind bad luck: after three sealed rifts without a page (while one is waiting in the current act), the next one finds it.",
	"For playtesters: the founding screen can skip Act I, so you start with it done and can try the middle game straight away (champions, Riftbreaks, the rival's moves).",
	"There is more to Hesper's story than she has told you. Each guild that finishes Act III hears a little more of it, and those who hear all of it, from guilds that have both kept and broken the Accord, may find a third way to end it.",
	"The Vale this year: after your first guild, each new one is founded in a different year. Two of eight year modifiers (a dry year, restless rifts, the Hollow stirring in one region, a hard winter...) each change the campaign one way for better and one for worse, and the rival has a temperament: hiring, boasting or undercutting. Roll the year again for 2 Laurels; Guild > Records shows it.",
	"The Descent: a new way into the Endless Rift, turn-based, with your heroes. Go down depth after depth, each harder and better paid; every second depth ends at a pillar where a lost champion waits. Climb out any time and keep everything. Pillars also turn up on Rank B and higher rifts, and the real-time Endless Rift is still there for your champions. Act IV now asks you to free a lost champion by any of the three.",
	"Two new founding gifts for your next guild (Laurels): Veteran start begins with Act I already done, with the heroes, gear and Gold a guild has by then; Old contacts puts two Rank C recruits on the first board.",
	"Tidewalls: a guild that broke the Accord can raise walls against the Open Hollow (Guild > Management). Each makes every tide 6% weaker against the guild, and costs more than the last; Gold and Essence finally have somewhere to go in that postgame.",
	"Postgame tuning: the old Accord halls cost about half as much (all seven: 45,000 Gold and 40,000 Essence). Tides of the Open Hollow now really break every week, with three days' warning, and grow 15% stronger only with each tide you hold: losing one doesn't make the next harder.",
	"Hesper, Wen and Dobbs remember your past guilds: on a quiet payday the talk at the pay table can turn to one of them, and to the heroes it left behind.",
	"Your past guilds' banners now hang in camp, either side of the Guild Hall. Hover one for its record; click it for the Hall of Guilds.",
	"After your first guild: found the next one under a charter (Mercenary Company, Temple Order, the Lantern's Smugglers, Last of the Accord) and swear oaths for more Laurels. And the ending now sets the postgame: Keepers of the Vale restore the old Accord halls; a guild that broke the Accord holds back a tide of the Open Hollow every week. The Chronicle lists what a guild can still finish.",
	"Legacy: when your guild chooses the Accord's ending (or retires, from Act III on, under Guild > Records), it joins the Hall of Guilds. Up to two of its heroes come back as champions in your later guilds, waiting to be freed in the Endless Rift, and it leaves Laurels to spend on gifts when you found the next one.",
	"Captain Morrow is a real fight now: tougher than other bosses of his rank, and he whistles up his sellswords twice, at two-thirds and again at one-third health.",
	"Party Assembly is simpler: your party stands on four slots facing the foes. Press + on a slot to pick a hero, or drag one from the roster onto it (onto someone to swap). Each hero has a small F/B switch for the Front or Back row.",
	"The boon after an elite is now a pop-up too: one card per boon in its family's colours, with the set it would complete, Take (or keys 1-3) and Skip.",
	"After a won fight, choosing your reward is now its own pop-up: the loot as cards with every stat on its own line, who it suits, and a Take button (or keys 1-3).",
	"Move a guild between devices: Settings > Backup > Send to another device gives a short code and a QR code. Scan it with your phone, or choose Receive a guild on the title screen and type the code. A code works once, for 15 minutes.",
	"Easier to read: the game's text is now set in Lato, wider and clearer at 1080p and below, and the opening's captions sit on a dark plate in a sturdier book face. Back on Settings works again after pressing the gear a second time.",
	"The Hollow Crown Company strikes back: expose them and from Act III their sellswords ambush your rifts, and Captain Morrow waits at the bottom of a Rank C+ rift with the key he opens rifts with. A kept echo can now touch a hero who recognises what's in it (Echo-Touched); the third echo brings Ezra the Pale, and the campaign's end says what the Vale remembers. A hero's fiftieth rift gets a line in the Chronicle.",
	"New sound effects throughout (free CC0 sounds, picked by ear). The Charter War comes to a head: as Act III opens, Mother Ilse brings proof the Hollow Crown Company opens rifts for profit. Expose them or keep quiet; when Act III ends, the Crown grants its Royal Charter to the guild with the most Renown. Wen now writes a line for every hero on the Memorial, and a scene when a bond reaches its peak.",
	"The opening is narrated now, over its own music, with two new scenes: the Accord sealing a rift, and the villagers waiting for a guild. Watch it again from Settings or the Chronicle.",
	"An opening cinematic: the Night of Breaking, how the old guilds of the Accord vanished, ending on your own guild. It plays when you found a guild; watch it again from Settings or Library > Codex > Chronicle.",
	"From Act II a sealed rift sometimes leaves an echo: Essence that holds something the Hollow took from someone. Give it back to the village, or keep it. Stranger, gentler things now turn up in rifts too. And when a hero first reaches Rank B, the guild marks their new calling with a scene of its own.",
	"Act IV: the Accord Hall. After Sythrane, the posts are tiring, and the Terms of the old bargain wait at the bottom of the Endless Rift (stronger for every post you've emptied). Beat them and choose how the story ends: renew the Accord, or break it. Guilds that already finished Act III can start it now.",
	"The guild has people now. Wen the Chronicler, Dobbs the Quartermaster and Old Hesper, the last of an Accord guild, talk at the pay table every payday (see the Ledger). The rival's leader signs every move with a letter of their own, and the Crown has promised a Royal Charter to the best guild. Freeing a champion in the Endless Rift leaves a post empty: the next Riftbreak comes sooner.",
	"The story has a past now: the Broken Accord. Why the old guilds vanished on the Night of Breaking, what the champions remember of it, and pages of the Grandmaster's ledger to find in sealed rifts. Read it all in Library > Codex > Chronicle.",
	"Recruiting is a board now: new faces arrive every day and wait a few days before moving on, payday fills it, and the rival may sign your best offer first. Each card shows the recruit's attributes and born quirk. Rerolls double in price until payday. Party screens have three saved loadouts: save a party with its rows, load it in one click.",
	"The Guild Ledger runs the payroll now: put a hero on half pay to save Gold (it costs morale) or give a bonus to keep them Inspired, see the vault against payday at a glance, and who would go unpaid. Skills aimed at one foe ask which: click the foe. Any save can be deleted from Load Game.",
	"A lighter interface: cards and buttons lose their outlines (an edge now means something needs you), the main tabs moved into the header, lists and ledgers sit on a calm background, the hero page says each number once, and notices stack less. Key numbers on fight buttons are a setting now (Settings > Key hints).",
	"Act finales are real climaxes: each is built on the rank you sealed to reach it, a step harder (they had fallen below it, and a quarter of finale fights ended in the first round). The Recommended power on the party screen follows. Champion cards line up in an even grid.",
	"Inventory and Guild Management open straight on their contents: the room's art is a slim strip with its sections as buttons, and each opens where you left it.",
	"Cleaner screens on a laptop: shops, treasure, events and hazards no longer sit under the path map (it shows while you choose a path), Victory puts the rewards beside the results, the quest board fits every note, pre-fight art is shorter, and notices moved to the bottom right.",
	"Recruits: commission a hero of the role you want (3 rerolls' Gold), and each offer shows power, HP and wage. Hazards now hurt in line with the rift's rank and always pay about a fight's worth, with a chance of double. Agility gives +1.5% dodge a point (was 0.8%).",
	"From player feedback: click a foe to target it (click again to attack). Auto lasts one fight. Quick fight also opens for a Favored party and says why when it can't. Every Ability shows its numbers. Shield Bash can't stun the same foe two rounds running. Fixed Legendary relics no longer take Essence for levels (refunded). Items say which slot they take. The party screen remembers your last party and rows. Clearer Medical Bay, rewards, run summary and skill tree.",
	"The bonus for winning by hand (+30% Gold and Essence, no one down) now pays on elites, bosses and every fight on a rank you haven't sealed: the fights where playing by hand matters.",
	"Fights: Quick fight now opens on a rank once you've sealed it, so a new rank and the act finales are fought where you can see them. Auto pauses when a hero is about to fall. The bonus for winning by hand shows before every fight.",
	"Balance: from Rank E up, monsters hit harder and last longer, so a party at Recommended power now seals about 3 rifts in 5 and Deadly means it. Hero wages are 50% higher, so a big roster has to earn its keep.",
	"A new guild meets its systems one at a time: Quests after your first seal, Management after the second, then Crafting, the daily twist and the rival's moves after the third. A broke guild with fewer than 3 heroes now gets free volunteers at payday.",
	"Phones: no keyboard hints where there's no keyboard, and a larger turn-your-phone prompt.",
	"Phones: hold your phone sideways and the game now fits, with larger text and buttons and the whole fight on one screen. Press and hold anything to read what it does. A fight won by hand with no one down now pays +30% Essence as well as Gold.",
	"A guild now holds 6 heroes from the start (a party is 4), so there's a bench to choose from. Act I and Act II have new goals. The Feedback report now includes how long you've played and how your fights and runs went.",
	"Fixes from a full play-through: a foe that has wound up keeps its red warning until the blow lands, the first fight's lessons come in order, the rival's contract grab can't point at a contract that's gone, rift bosses belong to their region (no Act III boss in the Vale), and the rival keeps pace in the Renown race. New: Add strongest on the party screen.",
	"New foes and stories: six new monsters, two per region (Blight Hound, Lantern Wight, Tide Caller, Mudscale Brute, Cinder Hound, Obsidian Sentinel) in six new designed fights, and 21 new rift events, some found only in one region. Upgrading a facility, hiring a hero, levelling a champion or buying from a shop now lands with a banner and a burst of sparks.",
	"The rival acts: once a week it may court one of your heroes, dare you to seal a rift by payday, or go for a posted contract, and you decide how to answer. Hero requests and the rival's moves pop up as cards when you're home. The Ledger opens on a week board: every day to payday and what falls on it.",
	"Fewer, clearer modes: the Daily Rift is now a daily twist on the Rift Ladder (tick it and your next ladder rift, any rank, carries the day's rule and boon for bonus Essence). Echoes are gone: the Endless Rift pays Essence, and Essence levels champions (old Echoes were converted). Renown is the one race with the rival: the monthly contest counts Renown gained, and the Renown tile turns green when you lead.",
	"New loot: items roll fewer, bigger stats (two per item type), and Rare and Epic items carry a named effect such as Ambush, Thunderclap, Riposte or Renewal. Picking gear shows the Power change. Your current items are unchanged.",
	"Phase 1 of the design pass: fights fit on screen without scrolling, notices sit in the top-right corner (two at a time, click to dismiss, never over a fight), new guilds start with three heroes, one tip at a time, and a tidier Rift Hall and Ledger.",
	"Hero pages are tidier: the header is a row of chips, clicking a slot opens a pop-up of item cards (gains in green, losses in red), and the passive and build notes moved to the Skills tab.",
	"Hero pages between fights: click a hero in the rift's top bar (or Hero pages) for the same page as the Roster — gear, attribute and skill points, with tabs for the whole party. It replaces the old Gear Up panel.",
	"Riftbreak defenses have painted roads, the Defenses research stands on the war-room map, and a lost defense never touches the Gold set aside for payday. Champions' signature mods are spread evenly: each of the 12 on four champions.",
	"Riftbreaks: from Act II a rift swells now and then, with a countdown in days. Seal a rift of its rank in time to close it, or it breaks and your guild defends: build towers on the road, post your idle heroes and steer a champion. Losing costs Gold, Essence and a damaged building. New Defenses research in Guild > Manage, paid in Gold.",
	"Endless Rift level-ups are built around your champions now: each champion's signature move has two mods of its own (Aftershock, Kindled, Leech, Bulwark and more). From level 10, fuse two champions: their signatures fire together, 25% harder, and share their mods.",
	"Endless Rift: gentler when it first opens, and it grows stronger with every champion you free and every act you pass (the party screen shows its strength).",
	"Endless Rift: every champion now walks with their own animation and plays a signature move when their Call fires.",
	"Champions, reworked: 24 named champions with their own art, and each new guild meets a different 12. Three are freed by the story, nine are lost in the Endless Rift (stand in their light to free them). One oversees your rift runs with a Boon and a Call; Echoes level them up.",
	"The Endless Rift is now the champions' rift: only champions go in, each with a signature move. It pays Echoes and a little gold, and costs the guild a day.",
	"Türkçe (beta): Settings or the title screen. Menus, fights, tips, names and descriptions are all in Turkish.",
	"Settings > Hearing aid: captions for sounds that tell you something (a boss arriving, a heavy blow, a hero going down, a wind-up), and the screen's edges pulse on the biggest moments.",
	"Two heroes of the same subclass no longer look like twins: the second wears different colours, everywhere they appear.",
	"Endless Rift: fixed the field going grey after a stutter; the ground has grass, reeds, cracks and embers; the party stands out in the middle; banners no longer pile up.",
	"New look: the title, camp and Rift Hall fill the screen, with flickering torches, breathing portals, stars and fireflies; screens fade between each other and a rift opens as you step in.",
	"Endless Rift: waves every minute, elite packs with chests, archers, a Rift Warden at 20:00 to beat, evolutions, rift relics, terrain and braziers.",
	"Fights: the main actions fit one row (More holds the rest); hover to preview Momentum; winning by hand with no one down pays +30% Gold.",
	"Guild: a This-week strip in camp, hero requests to answer, a rival with a face and a monthly contest.",
	"New music, larger text, and rank rules shown in the rift.",
]
## Moving a guild between devices: a short code for a save held 15 minutes
## by a tiny relay (tools/transfer-relay, a Cloudflare Worker), and the play
## link a QR code opens to receive it.
const TRANSFER_URL := "https://guildhold-transfer.lexingel.workers.dev"
const TRANSFER_PLAY_URL := "https://lexingel.github.io/guildhold/"
const FEEDBACK_DISCORD_URL := "https://discord.gg/85XrXjBUmk"   # the playtest Discord (the Feedback panel opens it)
## The players who tested the early builds and sent feedback, as they want to be
## credited (0.60.3). Until there are some, the credits invite players to join.
const FOUNDING_TESTERS: Array[String] = []

## Looping background music (AudioManager.play_music loops it).
## The pools the game picks from: a new camp track each time you come home,
## a combat track per rift or Endless run (not the last one's).
const COMBAT_MUSIC := ["res://assets/audio/music/combat.ogg", "res://assets/audio/music/metal_deep.ogg", "res://assets/audio/music/iron_deep_2.ogg"]
const CAMP_MUSIC := ["res://assets/audio/music/camp.ogg", "res://assets/audio/music/nocturnal_dread.ogg", "res://assets/audio/music/nocturnal_dread_2.ogg"]


## Each region's theme (0.59.1): a rift run plays its region's for the whole
## run; the Descent, the real-time Endless Rift and Act IV's finale (beneath
## the posts) play the Accord Hall's. The Tower keeps the combat pool.
const REGION_MUSIC := {
	"vale": "res://assets/audio/music/region_vale.ogg", "marsh": "res://assets/audio/music/region_marsh.ogg",
	"ashen": "res://assets/audio/music/region_ashen.ogg", "glass": "res://assets/audio/music/region_glass.ogg",
	"city": "res://assets/audio/music/region_city.ogg",
}
const ACCORD_MUSIC := "res://assets/audio/music/accord_hall.ogg"


## The theme a run plays, or "" for the combat pool (the Tower).
static func run_track(run: Dictionary) -> String:
	if run.is_empty() or run.has("tower"):
		return ""
	if run.has("descent") or int(run.get("finale", 0)) == 4:
		return ACCORD_MUSIC
	return str(REGION_MUSIC.get(str(run.get("biome", "vale")), ""))


## The next batch of the user's tracks (0.60.2): each plays once its file is
## in assets/audio/music, and until then the music that played before does.
## Built from the folder, not written out whole: test_media checks that every
## asset path in the code exists, and these are optional until they arrive.
const PENDING_MUSIC := "res://assets/audio/music/"
const BOSS_MUSIC := PENDING_MUSIC + "boss.ogg"
const FINALE_MUSIC := {
	1: PENDING_MUSIC + "finale_1.ogg", 2: PENDING_MUSIC + "finale_2.ogg", 3: PENDING_MUSIC + "finale_3.ogg",
	4: PENDING_MUSIC + "finale_4.ogg", 5: PENDING_MUSIC + "finale_5.ogg", 6: PENDING_MUSIC + "finale_6.ogg",
}
const RIFTBREAK_MUSIC := PENDING_MUSIC + "riftbreak.ogg"
const CAMP_EXTRA := [PENDING_MUSIC + "camp_hall.ogg"]


## The camp's rotation: the three tracks, plus any new camp track that's in.
static func camp_pool() -> Array:
	return CAMP_MUSIC + CAMP_EXTRA.filter(func(p): return ResourceLoader.exists(p))


## A boss fight's own track (a pillar's warden counts): the act's finale
## track on its finale, else the boss track; "" when that file isn't in.
static func fight_track(run: Dictionary, kind: String) -> String:
	if kind not in ["boss", "pillar"] or run.has("tower"):
		return ""
	var finale := str(FINALE_MUSIC.get(int(run.get("finale", 0)), ""))
	if finale != "" and ResourceLoader.exists(finale):
		return finale
	return BOSS_MUSIC if ResourceLoader.exists(BOSS_MUSIC) else ""


## A track from `pool`, not `last` when there's another to choose.
static func pick_track(pool: Array, last: String = "") -> String:
	var options: Array = pool.filter(func(p): return p != last)
	return str((options if not options.is_empty() else pool)[randi() % (options if not options.is_empty() else pool).size()])

## The 4 new generic action icons Phase 14 needed on top of the existing
## assets/skills/ set (which already covered swords/shields/potions/gems/a
## star/a trophy/a heart/boots/rings/armor — enough for most button actions
## without new art at all).
const BUTTON_ICON_PATH := {
	"confirm": "res://assets/skills/icon_confirm.png",
	"back": "res://assets/skills/icon_back.png",
	"dice": "res://assets/skills/icon_dice.png",
	"sort": "res://assets/skills/icon_sort.png",
}
const CREST_PATH: Array[String] = [
	"res://assets/camp/crest_1.png", "res://assets/camp/crest_2.png",
	"res://assets/camp/crest_3.png", "res://assets/camp/crest_4.png",
	"res://assets/camp/crest_5.png", "res://assets/camp/crest_6.png",
	"res://assets/camp/crest_7.png", "res://assets/camp/crest_8.png",
]
const CAMP_BG := "res://assets/camp/camp_bg.png"
const TITLE_BG := "res://assets/screens/title_bg.png"
const MEDICAL_BG := "res://assets/screens/medical_bg.png"
const MANAGEMENT_BG := "res://assets/screens/management_bg.png"
const BED_ICON := "res://assets/screens/bed_icon.png"
const RIFTHALL_BG := "res://assets/screens/rifthall_bg.png"
const INVENTORY_BG := "res://assets/screens/inventory_bg.png"
const CRAFTING_BG := "res://assets/screens/crafting_bg.png"
const SHOP_BG := "res://assets/screens/shop_bg.png"
const CAMP_HUB_ICON_PATH := {
	"roster": "res://assets/camp/icon_roster.png",
	"inventory": "res://assets/camp/icon_inventory.png",
	"recruits": "res://assets/camp/icon_recruits.png",
	"medical": "res://assets/camp/icon_medical.png",
	"management": "res://assets/camp/icon_management.png",
	"rift": "res://assets/camp/icon_rift.png",
	"bestiary": "res://assets/camp/icon_bestiary.png",
	"crafting": "res://assets/camp/icon_crafting.png",
	"settings": "res://assets/skills/gear.png",
	"compendium": "res://assets/camp/icon_compendium.png",
	"quests": "res://assets/camp/icon_quests.png",
}

## Window sizes offered by the Settings screen — Godot's existing
## stretch/mode="canvas_items" + aspect="expand" (project.godot) already
## scales the UI to whatever size the window ends up, so switching entries
## here is just get_window().size = Vector2i(w, h), no stretch-system change.
const RESOLUTION_OPTIONS := [
	{"label": "1280×800 (Default)", "w": 1280, "h": 800},
	{"label": "1200×800", "w": 1200, "h": 800},
	{"label": "1600×900", "w": 1600, "h": 900},
	{"label": "1920×1080", "w": 1920, "h": 1080},
]

## Ornate slot-frame borders, one per rarity tier — reused everywhere a
## rarity needs to read at a glance: equip slots on the paper-doll Roster
## screen and the battle screen's action-bar slots (which always use the
## "common" frame, since actions aren't items). AI-generated (PixelLab),
## same pipeline as every other UI asset this project uses.
const RARITY_FRAME_PATH := {
	"common": "res://assets/ui/frame_common.png",
	"rare": "res://assets/ui/frame_rare.png",
	"epic": "res://assets/ui/frame_epic.png",
	"legendary": "res://assets/ui/frame_legendary.png",
}
const SKILL_NODE_FRAME_PATH := "res://assets/ui/skill_node_hex.png"
const STATUS_PLATE_PATH := "res://assets/ui/status_plate.png"
const PORTRAIT_FRAME_PATH := "res://assets/ui/portrait_frame.png"
const ABILITY_BAR_STRIP_PATH := "res://assets/ui/ability_bar_strip.png"
const HERO_DETAIL_BG := "res://assets/screens/hero_detail_bg.png"
## Hue turns for hero colour variants (look 0 keeps the art as drawn): small
## enough that a warrior's red stays a red and a ranger's green a green (0.49),
## the most different first. A 6th hero sharing one portrait wraps round to 1.
const HERO_LOOK_HUES := [0.0, -0.06, 0.05, -0.03, 0.03]
## Hollow-born heroes (the Sky Beneath) wear a sea-glass variant of their own.
const HOLLOW_LOOK := 99
## Story cards' pictures (assets/story/<id>.png): a card's own "art", else
## by its choice's kind, else its act (an act's intro and outro share one).
const STORY_ART_KIND := {"vaelith": "vaelith", "spire": "spire", "charter": "charter", "brannoch": "brannoch", "sky": "sky_choice", "epilogue": "epilogue_choice"}


static func story_art(card: Dictionary) -> String:
	var id := str(card.get("art", ""))
	if id == "":
		id = str(STORY_ART_KIND.get(str(card.get("kind", "")), ""))
	if id == "" and card.has("act_intro"):
		id = "act_%d" % int(card["act_intro"])
	if id == "" and card.has("act_outro"):
		id = "act_%d" % int(card["act_outro"])
	var p := "res://assets/story/%s.png" % id
	return p if id != "" and ResourceLoader.exists(p) else ""
const HOLLOW_LOOK_HUE := 0.45
const HERO_PORTRAIT_PATH := {
	"warrior": "res://assets/heroes/warrior.png",
	"ranger": "res://assets/heroes/ranger.png",
	"mage": "res://assets/heroes/mage.png",
	"cleric": "res://assets/heroes/cleric.png",
	"rogue": "res://assets/heroes/rogue.png",
}

## One bespoke portrait per subclass (hand-picked and background-removed from
## the free Batareya character pack, same pipeline as the 5 HERO_PORTRAIT_PATH
## renders) — gives all 50 CLASS_POOL entries a distinct look instead of
## sharing their role's single portrait.
const SUBCLASS_PORTRAIT_PATH := {
	"squire": "res://assets/heroes/subclass/squire.png",
	"footman": "res://assets/heroes/subclass/footman.png",
	"duelist": "res://assets/heroes/subclass/duelist.png",
	"bulwark": "res://assets/heroes/subclass/bulwark.png",
	"berserker": "res://assets/heroes/subclass/berserker.png",
	"iron-guard": "res://assets/heroes/subclass/iron-guard.png",
	"bloodletter": "res://assets/heroes/subclass/bloodletter.png",
	"runeblade": "res://assets/heroes/subclass/runeblade.png",
	"ashen-templar": "res://assets/heroes/subclass/ashen-templar.png",
	"rift-sovereign": "res://assets/heroes/subclass/rift-sovereign.png",
	"trapper": "res://assets/heroes/subclass/trapper.png",
	"slinger": "res://assets/heroes/subclass/slinger.png",
	"pathfinder": "res://assets/heroes/subclass/pathfinder.png",
	"longshot": "res://assets/heroes/subclass/longshot.png",
	"blade-dancer": "res://assets/heroes/subclass/blade-dancer.png",
	"warden": "res://assets/heroes/subclass/warden.png",
	"stormtracker": "res://assets/heroes/subclass/stormtracker.png",
	"rift-ranger": "res://assets/heroes/subclass/rift-ranger.png",
	"deadfall-hunter": "res://assets/heroes/subclass/deadfall-hunter.png",
	"voidwalker": "res://assets/heroes/subclass/voidwalker.png",
	"apprentice": "res://assets/heroes/subclass/apprentice.png",
	"cinderling": "res://assets/heroes/subclass/cinderling.png",
	"fledgling-seer": "res://assets/heroes/subclass/fledgling-seer.png",
	"cinder-adept": "res://assets/heroes/subclass/cinder-adept.png",
	"frost-scholar": "res://assets/heroes/subclass/frost-scholar.png",
	"wardweaver": "res://assets/heroes/subclass/wardweaver.png",
	"stormcaller": "res://assets/heroes/subclass/stormcaller.png",
	"pyromancer": "res://assets/heroes/subclass/pyromancer.png",
	"archon-of-storms": "res://assets/heroes/subclass/archon-of-storms.png",
	"the-unbound": "res://assets/heroes/subclass/the-unbound.png",
	"peddler": "res://assets/heroes/subclass/peddler.png",
	"acolyte": "res://assets/heroes/subclass/acolyte.png",
	"herbalist": "res://assets/heroes/subclass/herbalist.png",
	"lay-brother": "res://assets/heroes/subclass/lay-brother.png",
	"battle-chaplain": "res://assets/heroes/subclass/battle-chaplain.png",
	"zealot": "res://assets/heroes/subclass/zealot.png",
	"rift-medic": "res://assets/heroes/subclass/rift-medic.png",
	"dawnkeeper": "res://assets/heroes/subclass/dawnkeeper.png",
	"sanctified-shield": "res://assets/heroes/subclass/sanctified-shield.png",
	"alchemist": "res://assets/heroes/subclass/alchemist.png",
	"scavenger": "res://assets/heroes/subclass/scavenger.png",
	"runaway": "res://assets/heroes/subclass/runaway.png",
	"cutpurse": "res://assets/heroes/subclass/cutpurse.png",
	"skirmisher": "res://assets/heroes/subclass/skirmisher.png",
	"footpad": "res://assets/heroes/subclass/footpad.png",
	"shadowfoot": "res://assets/heroes/subclass/shadowfoot.png",
	"fleetblade": "res://assets/heroes/subclass/fleetblade.png",
	"nightblade": "res://assets/heroes/subclass/nightblade.png",
	"wraithstep": "res://assets/heroes/subclass/wraithstep.png",
	"duskrunner": "res://assets/heroes/subclass/duskrunner.png",
	"rift-eclipsed-warden": "res://assets/heroes/subclass/rift-eclipsed-warden.png",
	"last-light-martyr": "res://assets/heroes/subclass/last-light-martyr.png",
	"the-final-cut": "res://assets/heroes/subclass/the-final-cut.png",
	# The 40 "content-pass" subclasses (added in an earlier session) never got
	# portrait art at all — PixelLab-generated, matching the hand-picked set's
	# proportions/style, to close that gap the same way the 3 new S-ranks were.
	"fieldmender": "res://assets/heroes/subclass/fieldmender.png",
	"featherguard": "res://assets/heroes/subclass/featherguard.png",
	"trailblazer": "res://assets/heroes/subclass/trailblazer.png",
	"frostguard": "res://assets/heroes/subclass/frostguard.png",
	"warbrand": "res://assets/heroes/subclass/warbrand.png",
	"aegis-bearer": "res://assets/heroes/subclass/aegis-bearer.png",
	"stormguard": "res://assets/heroes/subclass/stormguard.png",
	"rift-breaker": "res://assets/heroes/subclass/rift-breaker.png",
	"shadowtracker": "res://assets/heroes/subclass/shadowtracker.png",
	"fieldscout": "res://assets/heroes/subclass/fieldscout.png",
	"nightwarden": "res://assets/heroes/subclass/nightwarden.png",
	"sapling-keeper": "res://assets/heroes/subclass/sapling-keeper.png",
	"duskstalker": "res://assets/heroes/subclass/duskstalker.png",
	"gale-marksman": "res://assets/heroes/subclass/gale-marksman.png",
	"rift-piercer": "res://assets/heroes/subclass/rift-piercer.png",
	"wintertide-archer": "res://assets/heroes/subclass/wintertide-archer.png",
	"thornweaver": "res://assets/heroes/subclass/thornweaver.png",
	"shade-adept": "res://assets/heroes/subclass/shade-adept.png",
	"stoneward-mystic": "res://assets/heroes/subclass/stoneward-mystic.png",
	"grim-conjurer": "res://assets/heroes/subclass/grim-conjurer.png",
	"verdant-oracle": "res://assets/heroes/subclass/verdant-oracle.png",
	"duskglass-seer": "res://assets/heroes/subclass/duskglass-seer.png",
	"ashbound-theorist": "res://assets/heroes/subclass/ashbound-theorist.png",
	"rift-warden-magus": "res://assets/heroes/subclass/rift-warden-magus.png",
	"emberblessed-acolyte": "res://assets/heroes/subclass/emberblessed-acolyte.png",
	"frostward-sister": "res://assets/heroes/subclass/frostward-sister.png",
	"vanguard-chaplain": "res://assets/heroes/subclass/vanguard-chaplain.png",
	"hearth-warden": "res://assets/heroes/subclass/hearth-warden.png",
	"ember-confessor": "res://assets/heroes/subclass/ember-confessor.png",
	"frost-anchorite": "res://assets/heroes/subclass/frost-anchorite.png",
	"radiant-vanguard": "res://assets/heroes/subclass/radiant-vanguard.png",
	"sainted-ember": "res://assets/heroes/subclass/sainted-ember.png",
	"herbrunner": "res://assets/heroes/subclass/herbrunner.png",
	"arcane-pilferer": "res://assets/heroes/subclass/arcane-pilferer.png",
	"ironhide-footpad": "res://assets/heroes/subclass/ironhide-footpad.png",
	"glyphhand": "res://assets/heroes/subclass/glyphhand.png",
	"bramblefoot": "res://assets/heroes/subclass/bramblefoot.png",
	"rift-slipper": "res://assets/heroes/subclass/rift-slipper.png",
	"wraithblade-adept": "res://assets/heroes/subclass/wraithblade-adept.png",
	"the-unseen-hand": "res://assets/heroes/subclass/the-unseen-hand.png",
}

## AI-generated combat animation frames (5 each: frame 0 is the static portrait,
## 1-4 are the motion). Only combos that actually produced usable motion exist —
## Warrior/hurt and Ranger/attack never did after 3 rounds of prompt iteration,
## and Ranger/skill didn't either on the first attempt despite using the
## limb-specific wording that lesson taught — so those three intentionally
## have no frames; callers fall back to tweening the static portrait instead
## of frame-swapping when this returns [].
const HERO_ANIM_COMBOS := {
	"warrior": ["attack", "skill"],
	"ranger": ["hurt"],
	"mage": ["attack", "hurt", "skill"],
	"cleric": ["attack", "hurt", "skill"],
	"rogue": ["attack", "hurt", "skill"],
}


static func hero_anim_frames(role: String, action: String) -> Array[String]:
	var frames: Array[String] = []
	if not HERO_ANIM_COMBOS.get(role, []).has(action):
		return frames
	for i in 5:
		frames.append("res://assets/heroes/anim/%s_%s_%d.png" % [role, action, i])
	if not ResourceLoader.exists(frames[1]):
		return []   # the class-level frames were retired in 0.53: every hero has a subclass's own
	return frames


## Subclass-specific combat frames (same 5-frame shape as hero_anim_frames,
## generated the same way — frame 0 duplicates the static portrait). Checked
## via ResourceLoader.exists rather than a static combo table since these were
## generated per-subclass after the fact and coverage varies by role (see
## hero_combat_frames).
static func subclass_anim_frames(pool_id: String, action: String) -> Array[String]:
	var frames: Array[String] = []
	for i in 5:
		frames.append("res://assets/heroes/subclass_anim/%s_%s_%d.png" % [pool_id, action, i])
	if not ResourceLoader.exists(frames[1]):
		return []
	if not ResourceLoader.exists(frames[0]):   # frame 0 is the still itself (0.53: not stored twice)
		frames[0] = ("res://assets/champions/%s.png" % pool_id.trim_prefix("champ_")) if pool_id.begins_with("champ_") else str(SUBCLASS_PORTRAIT_PATH.get(pool_id, HERO_PORTRAIT_PATH.get(pool_id, frames[0])))
	return frames


## The single entry point _play_round should use to decide what to
## frame-animate. A hero with a subclass-specific portrait (SUBCLASS_PORTRAIT_
## PATH) must never play the generic role's frames — those are a different-
## looking character and that mismatch is exactly what caused heroes to
## visibly "change look" mid-hit. So subclassed heroes only ever get their own
## subclass_anim_frames (or no frames at all, falling back to a tween on their
## correct portrait); only Champions and other non-subclassed heroes fall back
## to the generic role animation, since portrait_for_hero shows them that same
## generic art at rest.
static func hero_combat_frames(cls_id: String, pool_id: String, action: String) -> Array[String]:
	# Champions have their own portraits, so the role's frames would be a
	# stranger mid-swing: only their own (subclass_anim/champ_<id>_*), else a tween.
	if SUBCLASS_PORTRAIT_PATH.has(pool_id) or pool_id.begins_with("champ_") or HERO_PORTRAIT_PATH.has(pool_id):   # 0.62: a base class (pool_id = role) has its own frames too
		return subclass_anim_frames(pool_id, action)
	return hero_anim_frames(cls_id, action)
const MONSTER_SPRITE_PATH := {
	"company_sellsword": "res://assets/monsters/company_sellsword.png",
	"company_crossbowman": "res://assets/monsters/company_crossbowman.png",
	"captain_morrow": "res://assets/monsters/captain_morrow.png",
	"ember_whelp": "res://assets/monsters/ember_whelp.png",
	"sable_fang": "res://assets/monsters/sable_fang.png",
	"marrow_crawler": "res://assets/monsters/marrow_crawler.png",
	"hollow_reaver": "res://assets/monsters/hollow_reaver.png",
	"husk_brute": "res://assets/monsters/husk_brute.png",
	"cinder_moth": "res://assets/monsters/cinder_moth.png",
	"gloom_stalker": "res://assets/monsters/gloom_stalker.png",
	"rift_wisp": "res://assets/monsters/rift_wisp.png",
	# Content pass: 8 new regular monsters, plus dedicated art for every
	# elite/boss name that previously fell through to a hash-picked sprite
	# from the pool above (a boss used to be able to look identical to a
	# common goblin).
	"bog_wretch": "res://assets/monsters/bog_wretch.png",
	"silt_crawler": "res://assets/monsters/silt_crawler.png",
	"glass_wisp": "res://assets/monsters/glass_wisp.png",
	"mirror_fiend": "res://assets/monsters/mirror_fiend.png",
	"frost_stalker": "res://assets/monsters/frost_stalker.png",
	"ashclad_ghoul": "res://assets/monsters/ashclad_ghoul.png",
	"deep_anchorite": "res://assets/monsters/deep_anchorite.png",
	"voidling_sprite": "res://assets/monsters/voidling_sprite.png",
	"warbound_elite": "res://assets/monsters/warbound_elite.png",
	"blightfang_elite": "res://assets/monsters/blightfang_elite.png",
	"rift_touched_colossus": "res://assets/monsters/rift_touched_colossus.png",
	"iron_revenant": "res://assets/monsters/iron_revenant.png",
	"storm_called_elite": "res://assets/monsters/storm_called_elite.png",
	"ashen_broodlord": "res://assets/monsters/ashen_broodlord.png",
	"vaelith": "res://assets/monsters/vaelith.png",
	"korrath": "res://assets/monsters/korrath.png",
	"nyxara": "res://assets/monsters/nyxara.png",
	"drevok": "res://assets/monsters/drevok.png",
	"sythrane": "res://assets/monsters/sythrane.png",
	"hedge_warden": "res://assets/monsters/hedge_warden.png",
	"carrion_crier": "res://assets/monsters/carrion_crier.png",
	"rootbound_thrall": "res://assets/monsters/rootbound_thrall.png",
	"leech_priest": "res://assets/monsters/leech_priest.png",
	"mire_sniper": "res://assets/monsters/mire_sniper.png",
	"drowned_bellringer": "res://assets/monsters/drowned_bellringer.png",
	"slag_golem": "res://assets/monsters/slag_golem.png",
	"ember_oracle": "res://assets/monsters/ember_oracle.png",
	"ash_harrier": "res://assets/monsters/ash_harrier.png",
	"blight_hound": "res://assets/monsters/blight_hound.png",
	"lantern_wight": "res://assets/monsters/lantern_wight.png",
	"tide_caller": "res://assets/monsters/tide_caller.png",
	"mudscale_brute": "res://assets/monsters/mudscale_brute.png",
	"cinder_hound": "res://assets/monsters/cinder_hound.png",
	"obsidian_sentinel": "res://assets/monsters/obsidian_sentinel.png",
	"shell_wretch": "res://assets/monsters/shell_wretch.png",
	"pearl_wisp": "res://assets/monsters/pearl_wisp.png",
	"tidewalker": "res://assets/monsters/tidewalker.png",
	"brine_sniper": "res://assets/monsters/brine_sniper.png",
	"coral_brute": "res://assets/monsters/coral_brute.png",
	"mirror_crab": "res://assets/monsters/mirror_crab.png",
	"undertow_priest": "res://assets/monsters/undertow_priest.png",
	"shore_crier": "res://assets/monsters/shore_crier.png",
	"pearl_colossus": "res://assets/monsters/pearl_colossus.png",
	"glassback_elite": "res://assets/monsters/glassback_elite.png",
	"the_tidewarden": "res://assets/monsters/the_tidewarden.png",
	"saltmother": "res://assets/monsters/saltmother.png",
	"the_terms": "res://assets/monsters/the_terms.png",
	"falling_watchman": "res://assets/monsters/falling_watchman.png",
	"lamp_wight": "res://assets/monsters/lamp_wight.png",
	"rooftop_harrier": "res://assets/monsters/rooftop_harrier.png",
	"bell_thrall": "res://assets/monsters/bell_thrall.png",
	"upside_hound": "res://assets/monsters/upside_hound.png",
	"stair_golem": "res://assets/monsters/stair_golem.png",
	"choir_sprite": "res://assets/monsters/choir_sprite.png",
	"cord_reaver": "res://assets/monsters/cord_reaver.png",
	"skyfallen_sentinel": "res://assets/monsters/skyfallen_sentinel.png",
	"broodwarden": "res://assets/monsters/broodwarden.png",
	"the_falling_sky": "res://assets/monsters/the_falling_sky.png",
	"queens_herald": "res://assets/monsters/queens_herald.png",
	"salt_hound": "res://assets/monsters/salt_hound.png",
	"pearl_thrall": "res://assets/monsters/pearl_thrall.png",
	"tideglass_moth": "res://assets/monsters/tideglass_moth.png",
	"cord_stalker": "res://assets/monsters/cord_stalker.png",
	"spire_oracle": "res://assets/monsters/spire_oracle.png",
	"gate_sentinel": "res://assets/monsters/gate_sentinel.png",
}
const MONSTER_NAME_SPRITE := {
	"Gloom Stalker": "gloom_stalker", "Rift Wisp": "rift_wisp", "Husk Brute": "husk_brute",
	"Sable Fang": "sable_fang", "Ember Whelp": "ember_whelp", "Marrow Crawler": "marrow_crawler",
	"Hollow Reaver": "hollow_reaver", "Cinder Moth": "cinder_moth",
	"Bog Wretch": "bog_wretch", "Silt Crawler": "silt_crawler",
	"Glass Wisp": "glass_wisp", "Mirror Fiend": "mirror_fiend",
	"Frost Stalker": "frost_stalker", "Ashclad Ghoul": "ashclad_ghoul",
	"Deep Anchorite": "deep_anchorite", "Voidling Sprite": "voidling_sprite",
	"Warbound Elite": "warbound_elite", "Blightfang Elite": "blightfang_elite",
	"Rift-Touched Colossus": "rift_touched_colossus", "Iron Revenant": "iron_revenant",
	"Storm-Called Elite": "storm_called_elite", "Ashen Broodlord": "ashen_broodlord",
	"Vaelith": "vaelith", "Korrath": "korrath", "Nyxara": "nyxara",
	"Drevok": "drevok", "Sythrane": "sythrane", "The Terms": "the_terms",
	"Company Sellsword": "company_sellsword", "Company Crossbowman": "company_crossbowman", "Captain Morrow": "captain_morrow",
	"Hedge Warden": "hedge_warden", "Carrion Crier": "carrion_crier", "Rootbound Thrall": "rootbound_thrall",
	"Leech Priest": "leech_priest", "Mire Sniper": "mire_sniper", "Drowned Bellringer": "drowned_bellringer",
	"Slag Golem": "slag_golem", "Ember Oracle": "ember_oracle", "Ash Harrier": "ash_harrier",
	"Blight Hound": "blight_hound", "Lantern Wight": "lantern_wight", "Tide Caller": "tide_caller",
	"Mudscale Brute": "mudscale_brute", "Cinder Hound": "cinder_hound", "Obsidian Sentinel": "obsidian_sentinel",
	# Tower of Trials guardians reuse elite/boss art.
	"The Gatekeeper": "iron_revenant", "Mirelord Oskan": "deep_anchorite", "Cindermaw": "ashen_broodlord",
	"The Hollow Choir": "hollow_reaver", "Tidewarden Selk": "blightfang_elite", "The Ember Regent": "drevok",
	"Gravewright Mourn": "korrath", "The Drowned Oracle": "nyxara", "Ashfather": "rift_touched_colossus",
	"The Summit Keeper": "sythrane",
	# Book II (stand-in art).
	"Shell Wretch": "shell_wretch",
	"Pearl Wisp": "pearl_wisp",
	"Tidewalker": "tidewalker",
	"Brine Sniper": "brine_sniper",
	"Coral Brute": "coral_brute",
	"Mirror Crab": "mirror_crab",
	"Undertow Priest": "undertow_priest",
	"Shore Crier": "shore_crier",
	"Pearl Colossus": "pearl_colossus",
	"Glassback Elite": "glassback_elite",
	"The Tidewarden": "the_tidewarden",
	"Saltmother": "saltmother",
	"Falling Watchman": "falling_watchman",
	"Lamp Wight": "lamp_wight",
	"Rooftop Harrier": "rooftop_harrier",
	"Cord Bellringer": "bell_thrall",
	"Upside Hound": "upside_hound",
	"Stair Golem": "stair_golem",
	"Choir Sprite": "choir_sprite",
	"Cord Reaver": "cord_reaver",
	"Skyfallen Sentinel": "skyfallen_sentinel",
	"Broodwarden": "broodwarden",
	"The Falling Sky": "the_falling_sky",
	"The Queen's Herald": "queens_herald",
	"Salt Hound": "salt_hound",
	"Pearl Thrall": "pearl_thrall",
	"Tideglass Moth": "tideglass_moth",
	"Cord Stalker": "cord_stalker",
	"Spire Oracle": "spire_oracle",
	"Gate Sentinel": "gate_sentinel",
}


## Any monster name resolves to a sprite key: a name match first (bosses by
## the part before the comma), else a stable hash-based pick so an unknown
## name still gets a deterministic sprite.
static func monster_sprite_key(monster_name: String) -> String:
	# Bosses are named "Korrath, Lesser Warden" — their art is keyed by the
	# name before the comma.
	var base_name := monster_name.split(",")[0]
	if MONSTER_NAME_SPRITE.has(base_name):
		return MONSTER_NAME_SPRITE[base_name]
	var keys: Array = MONSTER_SPRITE_PATH.keys()
	var hash_sum := 0
	for c in monster_name:
		hash_sum += c.unicode_at(0)
	return keys[hash_sum % keys.size()]


## Which way every foe sprite is drawn (0.52): reviewed by eye, battle sprite
## and walk frames together. Foes stand on the right facing left, so a foe
## drawn facing right is mirrored (the arena, the Endless Rift and Riftbreak).
## Every foe sprite needs an entry (test_sprite_facing), so new art can't slip
## in facing the wrong way unnoticed.
const FOE_FACING := {
	"company_sellsword": "front", "company_crossbowman": "left", "captain_morrow": "right", "ember_whelp": "left", "sable_fang": "left",
	"marrow_crawler": "front", "hollow_reaver": "front", "husk_brute": "front", "cinder_moth": "front", "gloom_stalker": "left",
	"rift_wisp": "front", "bog_wretch": "front", "silt_crawler": "front", "glass_wisp": "front", "mirror_fiend": "front",
	"frost_stalker": "left", "ashclad_ghoul": "front", "deep_anchorite": "front", "voidling_sprite": "left", "warbound_elite": "front",
	"blightfang_elite": "front", "rift_touched_colossus": "front", "iron_revenant": "front", "storm_called_elite": "front",
	"ashen_broodlord": "front", "vaelith": "front", "korrath": "right", "nyxara": "front", "drevok": "front", "sythrane": "front",
	"hedge_warden": "right", "carrion_crier": "right", "rootbound_thrall": "left", "leech_priest": "front", "mire_sniper": "left",
	"drowned_bellringer": "left", "slag_golem": "front", "ember_oracle": "front", "ash_harrier": "left", "blight_hound": "left",
	"lantern_wight": "right", "tide_caller": "right", "mudscale_brute": "left", "cinder_hound": "right", "obsidian_sentinel": "left",
	"shell_wretch": "front", "pearl_wisp": "front", "tidewalker": "front", "brine_sniper": "left", "coral_brute": "front",
	"mirror_crab": "left", "undertow_priest": "front", "shore_crier": "left", "pearl_colossus": "front", "glassback_elite": "left",
	"the_tidewarden": "front", "saltmother": "left", "the_terms": "front", "falling_watchman": "left", "lamp_wight": "left",
	"rooftop_harrier": "right", "bell_thrall": "left", "upside_hound": "left", "stair_golem": "front", "choir_sprite": "left",
	"cord_reaver": "front", "skyfallen_sentinel": "left", "broodwarden": "left", "the_falling_sky": "left", "queens_herald": "left",
	"salt_hound": "left", "pearl_thrall": "front", "tideglass_moth": "right", "cord_stalker": "left", "spire_oracle": "right",
	"gate_sentinel": "front",
}
## Hero art drawn facing left (heroes stand on the left facing right). Every
## hero and champion is drawn facing right or front since the 0.49-0.50 redo.
const HERO_FACES_LEFT := {}
## The sprites to mirror, from the two tables above.
static var SPRITE_FACES_AWAY: Dictionary = _faces_away_table()


static func _faces_away_table() -> Dictionary:
	var out := HERO_FACES_LEFT.duplicate()
	for k in FOE_FACING:
		if FOE_FACING[k] == "right":
			out[k] = true
	return out


## `key_or_path`: a sprite path, a monster sprite key or an Endless walk key.
static func faces_away(key_or_path: String) -> bool:
	return SPRITE_FACES_AWAY.has(key_or_path.get_file().get_basename().trim_prefix("sub_"))


static func sprite_for_monster(monster_name: String) -> String:
	return MONSTER_SPRITE_PATH[monster_sprite_key(monster_name)]


## Combat animation frames for a monster (5 each, same shape as
## hero_anim_frames). Every monster's base sprite and frames share one crop
## box, so swapping frames never shifts the sprite. A monster with no frames
## falls back to a tween, the same contract hero_anim_frames has.
static func monster_anim_frames(monster_name: String, action: String) -> Array[String]:
	var key := monster_sprite_key(monster_name)
	var frames: Array[String] = []
	for i in 5:
		frames.append("res://assets/monsters/anim/%s_%s_%d.png" % [key, action, i])
	if not ResourceLoader.exists(frames[1]):
		return []
	if not ResourceLoader.exists(frames[0]):   # frame 0 is the battle sprite itself (0.53: not stored twice)
		frames[0] = str(MONSTER_SPRITE_PATH[key])
	return frames
