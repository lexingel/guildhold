extends "res://scripts/autoload/game_data/GameDataBreach.gd"
## GameData, part 6b: the Unwritten Accord, the story web across guilds.
## Fragments (50 words at most) are found in play and kept in the legacy;
## any two of a truth's fragments make it known; a known truth opens a
## branch (a choice with a price) in this guild or a later one. Witnesses'
## claims are struck through or confirmed as truths come in.
## Design doc: "The Unwritten Accord". Phase 1: the Ranger Who Left, the Clerk.
## Phase 2: the Key, the Lantern. Phase 3: the Far Side, the Witnesses, the epilogue.

## A seal that could turn up a fragment does so this often; after LORE_PITY
## dry seals the next one does (like the ledger).
const LORE_SEAL_CHANCE := 0.2
const LORE_PITY := 4
## Any this many of a truth's fragments make it known.
const TRUTH_NEEDS := 2
const FRAGMENT_MAX_WORDS := 50
## A payday turns to a lore scene this often when one is waiting.
const LORE_PAYDAY_CHANCE := 0.5

const LORE_ARCS := [
	["ranger", "The Ranger Who Left"],
	["clerk", "The Clerk"],
	["key", "The Key"],
	["lantern", "The Lantern"],
	["far", "The Far Side"],
	["witnesses", "The Witnesses"],
]

const TRUTHS := {
	"t_squad": {"arc": "ranger", "text": "Vaelith's squad took four posts in a row at Thornwood.",
		"hint": "Rangers' tags turn up in the Vale's rifts."},
	"t_why_left": {"arc": "ranger", "text": "Vaelith didn't desert. She heard children behind her door.",
		"hint": "Someone who knew Vaelith might say what she was listening for.",
		"opens": "At Act I's finale, a guild can let Vaelith go."},
	"t_held_open": {"arc": "ranger", "text": "The great Breach is the door Vaelith held open, and she is still in it.",
		"hint": "A guild that let Vaelith go would know where she went.",
		"opens": "Vaelith's Rangers joins the founding charters."},
	"t_clerk": {"arc": "clerk", "text": "Hesper wrote the Terms out fair. She knew every word.",
		"hint": "Hesper's handwriting is in more places than she admits."},
	"t_fever": {"arc": "clerk", "text": "There was no fever. Hesper wrote the note herself, and ran.",
		"hint": "Ask who nursed Hesper that week."},
	"t_blank_line": {"arc": "clerk", "text": "The Grandmaster let Hesper go, and left the forty-second line blank for her.",
		"hint": "The Grandmaster's own hall remembers who it waited for.",
		"opens": "At the Renew ending, Hesper can sign the forty-first line herself. The Clerk's Copy joins the founding gifts."},
	"t_key": {"arc": "key", "text": "The Accord's key opens any door, from either side.",
		"hint": "Whoever holds Morrow's key could say what it opens.",
		"opens": "Whoever holds the key may keep it or break it. Pip's Key joins the founding gifts."},
	"t_warden": {"arc": "key", "text": "Pip stole the key from the Warden of Rifts, a royal officer.",
		"hint": "Someone in a fine hat is missing a key.",
		"opens": "At the Crown's hearing, a guild that's losing can buy the Charter."},
	"t_paymaster": {"arc": "key", "text": "The Royal Treasury pays the Hollow Crown Company to open rifts.",
		"hint": "Follow the money behind the Company's contracts.",
		"opens": "In the Charter War, a guild can turn Morrow instead."},
	"t_apprentice": {"arc": "lantern", "text": "Ezra was the Ninth Lamp's last apprentice. He was below, measuring, on the Night.",
		"hint": "Ezra's lantern has a maker's mark."},
	"t_lantern": {"arc": "lantern", "text": "Ezra's lantern holds what the rifts took, from both sides.",
		"hint": "Ask what Ezra keeps in the lantern, and whose voices are in it.",
		"opens": "When Ezra visits, a guild can pour its kept echoes into the lantern."},
	"t_sky": {"arc": "lantern", "text": "Essence is the far side's sky. Every crystal burned is a piece of it falling.",
		"hint": "The Ninth Lamp measured something the Crown wanted kept quiet.",
		"opens": "The Ninth Lamp joins the founding charters."},
	"t_sister": {"arc": "lantern", "text": "The Last Lantern is the Ninth Lamp's sister hall. Mother Ilse has known all along.",
		"hint": "Mother Ilse signs her letters with more than her name."},
	"t_terms_hers": {"arc": "far", "text": "The Terms were the Grandmaster's own. The ledger's \"voice that offered terms\" was a lie.",
		"hint": "Read the ledger's third day beside the reply on its last page.",
		"opens": "With the right guild in the Hall, a sixth crossing comes to the door."},
	"t_knock": {"arc": "far", "text": "The Night of Breaking was the far side knocking on every door at once.",
		"hint": "Ask the ones who came through what they remember of that night.",
		"opens": "When the Choir crosses, a guild can let them sing."},
	"t_brannoch": {"arc": "far", "text": "Brannoch holds the door under the Inverted City, and promised a child he'd come back.",
		"hint": "Somebody once measured a child's height on a deep pillar.",
		"opens": "At Act VI's start, a guild can leave Brannoch holding, or free him."},
	"t_turns": {"arc": "far", "text": "A rewrite reaches both sides: the far side holds its doors in turns too.",
		"hint": "A guild that rewrote the Terms, or kept both worlds, would know."},
	"t_chorus": {"arc": "witnesses", "text": "The Iron Chorus marched for the Crown on the Night of Breaking, not for the Vale.",
		"hint": "The Iron Chorus is proud of an old order.",
		"opens": "A year of witnesses can come round."},
	"t_wolves": {"arc": "witnesses", "text": "The Ashen Wolves served the Ashen Crown, and fed it.",
		"hint": "Ask what the wolves did after the Night.",
		"opens": "A year of witnesses can come round."},
	"t_first_seal": {"arc": "witnesses", "text": "The first signature on the Terms is the Crown's seal.",
		"hint": "Someone on the far side kept the first page.", "needs": 3},
}
## Knowing all of these after Book II's ending opens the epilogue.
const EPILOGUE_TRUTHS := ["t_paymaster", "t_sky", "t_terms_hers", "t_knock", "t_first_seal"]

## channel: where it's found.
##   relic   a sealed rift's relic carries it (gate: region, rank_min)
##   seal    a sealed rift turns it up (gate: region, rank_min, ...)
##   ledger  a sealed rift, once the ledger has `pages` pages
##   payday  a pay-table scene ("lines")
##   letter  a postscript to the rival's weekly letter (gate: rival)
##   echo / finale / crossing / line / hall / ending: at that event ("on")
##   morrow / bestiary / mercenary / charter / ezra / echo_kept / hearing: Phase 2's events
## gate keys: region, rank_min, truth, rival, charter, branch ("id:value"), hall, pages,
## morrow (beaten or turned), upgrade ("node:level").
const FRAGMENTS := {
	# I · The Ranger Who Left
	"f_corin": {"truth": "t_squad", "channel": "relic", "gate": {"region": "vale"}, "title": "Corin's tag",
		"relic": "Corin's Tag",
		"text": "Accord ranger's tag, Thornwood post. \"Corin\" stamped on the front. On the back, in someone else's knife-work: \"V. said wait. I waited.\""},
	"f_mags": {"truth": "t_squad", "channel": "relic", "gate": {"region": "vale", "rank_min": "D"}, "title": "Mags's tag",
		"relic": "Mags's Tag",
		"text": "Accord ranger's tag, Thornwood post: \"Mags\". Something chewed one corner and gave up. Scratched under the name, in the same hand as Corin's: \"Third in line. V. fourth.\""},
	"f_face": {"truth": "t_squad", "channel": "echo", "on": "face", "title": "The face in the echo",
		"text": "Wen copies the ranger's face before the crystal goes home. On the collar, too small for the elder to notice, is a squad mark: a V with four notches."},
	"f_listening": {"truth": "t_why_left", "channel": "finale", "on": "1", "gate": {"truth": "t_squad"}, "title": "Vaelith, listening",
		"text": "Wen's note for the Bestiary: twice in the fight Vaelith stopped, turned her head to the Breach, and listened. Not to us. To something small behind it."},
	"f_two_sides": {"truth": "t_why_left", "channel": "payday", "gate": {"truth": "t_squad"}, "title": "Two sides",
		"lines": [["Hesper", "Vaelith asked me once if doors had two sides."], ["Wen", "What did you say?"], ["Hesper", "That rifts don't. She looked at me like I'd failed a test I didn't know I was taking."]]},
	"f_orla_deserter": {"truth": "t_why_left", "channel": "letter", "gate": {"rival": "The Iron Chorus"}, "title": "Orla Venn's postscript", "claim": "orla_deserter",
		"text": "P.S. Your Vaelith was a deserter, whatever the songs say. She walked off her post toward the noise, not away from it. The Chorus has never decided which was worse."},
	"f_footprints": {"truth": "t_held_open", "channel": "seal", "gate": {"region": "vale", "hall": "spared_vaelith"}, "title": "Footprints",
		"text": "Small bare footprints in the frost at the rift's mouth, leading out, not in. They stop at the road, where someone in ranger's boots picked them up."},
	"f_shorthand": {"truth": "t_held_open", "channel": "payday", "gate": {"branch": "vaelith:spared"}, "title": "Ranger shorthand",
		"lines": [["Wen", "A note on the pay table, in ranger shorthand."], ["Dobbs", "Saying?"], ["Wen", "\"Door holding. Four more through. Don't pay me. Feed them.\""], ["Dobbs", "Feed whom?"]]},
	"f_ranger_door": {"truth": "t_held_open", "channel": "crossing", "on": "family", "gate": {"truth": "t_why_left"}, "title": "The green lady's door",
		"text": "The eldest points at your crest, then up at the Vale. \"The green lady's door,\" she says. \"She let our cousins through. She said you were kinder than you look.\""},
	# II · The Clerk
	"f_clerk_piece": {"truth": "t_clerk", "channel": "line", "on": "2", "title": "The clerk",
		"text": "Hesper says she was the Grandmaster's clerk, and wrote the Terms out fair: forty-one lines, in her own hand."},
	"f_quiet_coin": {"truth": "t_clerk", "channel": "hall", "on": "quiet_coin", "title": "Quiet Coin's copies",
		"text": "In Quiet Coin's counting room Dobbs finds the Accord's copies of the Terms, all in one neat hand. He holds one up beside this week's wage sheet. Hesper's."},
	"f_spelling": {"truth": "t_clerk", "channel": "payday", "gate": {"charter": "accord", "pages": 2}, "title": "A spelling",
		"lines": [["Wen", "Page two says \"refuse them properly\"."], ["Hesper", "She wrote \"proper\". She never could spell. I fixed it when I wrote them out fair."], ["Wen", "When you what?"]]},
	"f_ink": {"truth": "t_fever", "channel": "payday", "gate": {"truth": "t_clerk"}, "title": "The green ink",
		"lines": [["Wen", "Hesper, your fever note is in green ink."], ["Wen", "The Terms are in green ink."], ["Hesper", "It was the ink I had."]]},
	"f_ilse_never_sick": {"truth": "t_fever", "channel": "letter", "gate": {"rival": "The Last Lantern"}, "title": "Mother Ilse's postscript",
		"text": "P.S. My regards to Hesper. I still have the blanket she lent me on the night she was meant to be in bed with a fever. She was never sick a day in her life."},
	"f_green_hand": {"truth": "t_fever", "channel": "hall", "on": "green_hand", "title": "The Green Hand's ledger",
		"text": "The Green Hand wrote down everyone they nursed. The week of the Night of Breaking has eleven names: burns, a broken arm, a midwife's twins. No fevers. Wen closes it gently."},
	"f_day11": {"truth": "t_blank_line", "channel": "ledger", "gate": {"truth": "t_fever", "pages": 5}, "title": "Day 11, the clerk's copy",
		"text": "Day 11, in a clerk's neat hand: \"V. asked who holds the last post. G. said the ledger. After, G. told me to go home with a fever. I said I wasn't ill. She said: you will be, and you'll come back.\""},
	"f_dusted_stool": {"truth": "t_blank_line", "channel": "hall", "on": "grandmaster", "title": "The clerk's stool",
		"text": "Forty-one chairs at the long table, thick with dust. At the end, the clerk's stool is clean, and the inkwell beside it is full. Someone kept it ready for twenty years."},
	"f_her_hand": {"truth": "t_blank_line", "channel": "ending", "on": "rewrite", "gate": {"truth": "t_fever"}, "title": "Her hand",
		"text": "Hesper writes the forty-second line without looking at the page. \"I had twenty years to practise,\" she says. \"She left it blank for me. I just never came back.\""},
	# III · The Key
	"f_key_turns": {"truth": "t_key", "channel": "morrow", "on": "down", "title": "The wrong way",
		"text": "Dobbs tries Morrow's key in the rift's door, to lock it. It turns the wrong way, and keeps turning. Something on the other side knocks back, twice, politely."},
	"f_pip_theft": {"truth": "t_key", "channel": "payday", "gate": {"morrow": true}, "title": "Pip's story",
		"lines": [["Pip", "I nicked it off a rift-lord. Big hat. Smelled of ink."], ["Wen", "Last week he smelled of fish."], ["Pip", "Long night. He opened three doors with it before I got it off him."]]},
	"f_fresh_bolts": {"truth": "t_key", "channel": "bestiary", "on": "Company Crossbowman", "title": "Fresh bolts",
		"text": "Wen's note for the Bestiary: the crossbowmen's bolts are tipped with fresh Essence, and fresh means a rift opened this week. Their quartermaster keeps a calendar of rifts opening, which is a strange thing to be able to keep."},
	"f_aldric_cousin": {"truth": "t_warden", "channel": "letter", "gate": {"rival": "The Gilded Lance"}, "title": "Ser Aldric's postscript", "claim": "aldric_cousin",
		"text": "P.S. My cousin is Warden of the Crown's Rifts, and the Vale is safe in his hands. He did lose a key once, to a girl no taller than a sword. We don't mention it."},
	"f_warden_ring": {"truth": "t_warden", "channel": "relic", "gate": {"rank_min": "B", "truth": "t_key"}, "title": "The Warden's ring",
		"relic": "The Warden's Ring",
		"text": "A signet ring from a deep rift: a crowned door, and under it, Warden of Rifts. The inside of the band is worn smooth where a key on a cord used to rub."},
	"f_watermark": {"truth": "t_warden", "channel": "mercenary", "on": "offer", "title": "A royal watermark",
		"text": "Dobbs holds the Company's offer up to the window. Under Morrow's seal the paper carries a watermark: a crowned door. \"That's not a Company mark,\" he says. \"That's the Warden's.\""},
	"f_ilse_page": {"truth": "t_paymaster", "channel": "charter", "on": "turn", "gate": {"rival": "The Last Lantern", "hall": "kept_quiet"}, "title": "Ilse's whole page",
		"text": "This time Ilse brings the whole page, not the torn half. Beside the list of rifts and dates is a second column, headed Paid: every amount signed for by the Royal Treasury."},
	"f_treasury_footer": {"truth": "t_paymaster", "channel": "charter", "on": "quiet", "title": "The small print",
		"text": "At the foot of Morrow's first generous contract, in very small print: \"Disbursed by the Royal Treasury, Office of Rifts.\" Dobbs reads it three times, then stops reading it."},
	"f_confession": {"truth": "t_paymaster", "channel": "morrow", "on": "down", "gate": {"charter": "mercenary"}, "title": "One hireling to another",
		"text": "Morrow, bleeding, looks at your charter and laughs. \"Hired swords. Then you know. Someone always pays. The Crown pays me to open them and pays you to close them. Ask who's richer.\""},
	# IV · The Lantern
	"f_my_lamp": {"truth": "t_apprentice", "channel": "ezra", "on": "visit", "title": "His Lamp's",
		"text": "As Ezra leaves, Wen asks where the lantern came from. \"My Lamp's,\" he says, then corrects himself. \"The Ninth Lamp's. I was their last apprentice. I was below that night, measuring.\""},
	"f_lamps_light": {"truth": "t_apprentice", "channel": "hall", "on": "ninth_lamp", "title": "One name in the register",
		"text": "The Ninth Lamp's register lists every member. The lamps along the wall light for one name only, the last apprentice taken on: Ezra, aged sixteen, \"good with depths\"."},
	"f_notebook": {"truth": "t_apprentice", "channel": "relic", "gate": {"rank_min": "C", "upgrade": "res.lab:3"}, "title": "A notebook, signed E.",
		"relic": "Ezra's Notebook",
		"text": "A notebook of depth readings from the Night of Breaking, each rift measured twice. The last page, in a shaking hand: \"Deeper than the Assay. Not a wound. A door. Someone is on the other side of all of them.\""},
	"f_oath_voice": {"truth": "t_lantern", "channel": "echo_kept", "on": "oath", "title": "Not our voice",
		"text": "Kept, the Oath echo plays in the vault at night. The words are the Accord's, but the voice isn't human. When Ezra hears of it, he only says: \"Theirs took ours, too.\""},
	"f_lantern_full": {"truth": "t_lantern", "channel": "payday", "gate": {"hall": "kept_echoes"}, "title": "The lantern, full",
		"lines": [["Dobbs", "Ezra's lantern was on the step again this morning."], ["Wen", "Empty, like last time?"], ["Dobbs", "Full. Hundreds of little lights. Some of them are saying names. Not ours."]]},
	"f_choir_name": {"truth": "t_lantern", "channel": "crossing", "on": "choir", "gate": {"truth": "t_apprentice"}, "title": "A name in the song",
		"text": "Halfway through, the choir sings a name nobody in the Vale knows, then asks after a pale man with a lantern. \"He has some of ours,\" the eldest says. \"We would like them back.\""},
	"f_last_finding": {"truth": "t_sky", "channel": "hall", "on": "ninth_lamp", "gate": {"truth": "t_lantern"}, "title": "The last finding",
		"text": "Under a royal seal, the Ninth Lamp's last finding, a year before the Night: \"Essence is not ours. It is their sky, hardening as it falls. Every crystal we burn, we pull down.\" Stamped across it: Not for circulation."},
	"f_weather": {"truth": "t_sky", "channel": "crossing", "on": "glassblower", "gate": {"truth": "t_apprentice"}, "title": "Weather",
		"text": "He turns a crystal of your Essence in his glass fingers. \"You burn these for light? Down there we called it weather. It was the part of the sky that rained.\""},
	"f_tide_wrack": {"truth": "t_sky", "channel": "seal", "gate": {"region": "marsh", "hall": "tides5"}, "title": "A tide-wrack journal",
		"text": "A sodden journal from a Marsh rift, kept by a guild that held the tides: \"Every tide follows a good harvest. The more Essence the Vale burns, the harder the Hollow comes up, as if chasing something it lost.\""},
	"f_ilse_mark": {"truth": "t_sister", "channel": "letter", "gate": {"rival": "The Last Lantern", "truth": "t_apprentice"}, "title": "Nine flames",
		"text": "P.S. Under Ilse's signature, smaller than a fingernail, someone has drawn a lamp with nine flames. The Last Lantern's own mark has one."},
	"f_lamp_oil": {"truth": "t_sister", "channel": "payday", "gate": {"charter": "smugglers"}, "title": "Lamp oil",
		"lines": [["Dobbs", "The smugglers' crates came in. I was promised Essence."], ["Wen", "And?"], ["Dobbs", "Lamp oil. Nine casks. Mother Ilse's compliments, and \"keep the Lamp lit\"."]]},
	"f_ilse_table": {"truth": "t_sister", "channel": "hearing", "on": "won", "gate": {"rival": "The Last Lantern"}, "title": "Left on the table",
		"text": "Mother Ilse is gone before the herald finishes, but she has left something on your table: a brass key to the Ninth Lamp's hall, and a note. \"You'll need this one day. I kept it warm.\""},
	# V · The Far Side
	"f_reply": {"truth": "t_terms_hers", "channel": "book2", "on": "start", "title": "We accept your Terms",
		"text": "Wen reads the reply's first words again. \"We accept your Terms.\" Yours. Not theirs. The Grandmaster's ledger says a voice from the deep offered them. Someone is lying, and it isn't the far side."},
	"f_side_by_side": {"truth": "t_terms_hers", "channel": "payday", "gate": {"book2": true, "pages": 2}, "title": "Side by side",
		"lines": [["Wen", "Day three: \"A voice offered terms.\""], ["Wen", "The last page: \"We accept your Terms.\""], ["Dobbs", "Read them both again. Slower."], ["Wen", "I have. Nobody wants the last biscuit."]]},
	"f_wrote_first": {"truth": "t_terms_hers", "channel": "through", "on": "through", "title": "A polite letter", "claim": "hollow_answered",
		"text": "Safe on our side, the eldest asks which of you wrote to them first. \"Your Grandmaster's letter. It was very polite. It said: stay where you are.\""},
	"f_every_door": {"truth": "t_knock", "channel": "crossing", "on": "child", "title": "Every door rang", "claim": "hollow_knocked",
		"text": "She remembers the night every door rang. \"We all knocked,\" she says. \"Everyone at once, on every door there was. Somebody told us someone would come.\""},
	"f_running": {"truth": "t_knock", "channel": "seal", "gate": {"region": "glass", "hall": "broke"}, "title": "Running, not hunting",
		"text": "A tide-wrack journal on the Glass Coast, from a guild that burned the Terms: \"Most of what came up with the tides wasn't hunting. It was running, and looking back.\""},
	"f_choir_oath": {"truth": "t_knock", "channel": "crossing", "on": "choir", "gate": {"song": true}, "title": "The Choir's song",
		"text": "The Choir's song is the Accord's oath, word for word, learned from a guild that came down twenty years ago. They sing it the way the village does now, a little off-key."},
	"f_day10": {"truth": "t_brannoch", "channel": "ledger", "gate": {"truth": "t_fever", "pages": 4}, "title": "Day 10, the clerk's copy",
		"text": "Day 10, in the clerk's hand: \"B. asked for the deepest post, under the city. A child watched from the other side. He told her: wait there, I'll come back for you. G. let him go first.\""},
	"f_height_marks": {"truth": "t_brannoch", "channel": "descent", "on": "6", "title": "Height marks",
		"text": "Knife-marks on a deep pillar's base, a hand's width apart, climbing: a child's height, measured every year. They stop at about the height of a girl of twelve."},
	"f_knock_signal": {"truth": "t_brannoch", "channel": "gate", "on": "held", "title": "Relief coming", "claim": "hollow_promised",
		"text": "After the gate holds, someone knocks from below. Three times, then twice, then three times: the Accord's old signal for relief coming."},
	"f_turns_wall": {"truth": "t_turns", "channel": "book2", "on": "start", "gate": {"hall": "rewrite"}, "title": "A list on the wall",
		"text": "On the far side of the first door, someone has painted a list on the wall: names and seasons, in turns. Some of the names are ours."},
	"f_our_keepers": {"truth": "t_turns", "channel": "payday", "gate": {"hall": "both"}, "title": "Our keepers",
		"lines": [["Dobbs", "The new recruit asked when \"our keepers\" get paid."], ["Wen", "Which keepers?"], ["Dobbs", "The ones holding their side of the doors. She says they take turns, like ours."]]},
	"f_signatory": {"truth": "t_turns", "channel": "crossing", "on": "signatory", "title": "The First Signatory",
		"text": "She is older than the Accord's last guild, and she has walked a long way. \"Your guilds took turns,\" she says. \"So did we. I held our side of the first door.\""},
	# VI · The Witnesses
	"f_marching_order": {"truth": "t_chorus", "channel": "contest", "on": "won", "gate": {"rival": "The Iron Chorus"}, "title": "The marching order",
		"text": "Orla Venn sends the contest prize with a copy of her proudest possession: the Chorus's marching order from the Night of Breaking. It is addressed to the Crown's garrison, not to the Vale."},
	"f_blue_stones": {"truth": "t_chorus", "channel": "hall", "on": "iron_oath", "title": "Blue stones",
		"text": "In the Iron Oath's drill yard one row of stones is painted royal blue. The old drillmaster's note: \"Chorus recruits stand here. They take their orders from further up.\""},
	"f_no_collars": {"truth": "t_wolves", "channel": "finale", "on": "3", "title": "No collars",
		"text": "Wen's note for the Bestiary: Sythrane's wolves wore no collars, and never once turned on her. Wolves don't do that for a crown. They do it for whoever feeds them."},
	"f_kael_job": {"truth": "t_wolves", "channel": "hearing", "on": "won", "gate": {"rival": "The Ashen Wolves"}, "title": "Kael asks for work",
		"text": "Kael Ashborn asks for a job, and for once says why. \"My wolves fed the Ashen Crown for ten years. Somebody has to feed them now, and it shouldn't be that.\""},
	"f_first_page": {"truth": "t_first_seal", "channel": "signatory", "on": "through", "title": "The first page",
		"text": "The First Signatory unfolds a page she has carried for twenty years: the Terms' first line. Above forty signatures, in red wax, is a seal: a crowned door."},
	"f_ring_match": {"truth": "t_first_seal", "channel": "payday", "gate": {"fragment": "f_warden_ring", "truth": "t_terms_hers"}, "title": "The same seal",
		"lines": [["Wen", "The Warden's ring. I've seen this seal before."], ["Dobbs", "Where?"], ["Wen", "On the Terms. Above every signature."]]},
	"f_stipend": {"truth": "t_first_seal", "channel": "hall", "on": "quiet_coin", "gate": {"truth": "t_paymaster"}, "title": "A royal stipend",
		"text": "Quiet Coin's last ledger: a royal stipend, paid to the Grandmaster every year since the Night of Breaking, \"for keeping the doors\". It stops the year she fell."},
	"f_stranger": {"truth": "t_first_seal", "channel": "seal", "gate": {"year": "wanderers", "truth": "t_terms_hers"}, "title": "Copies for a copper",
		"text": "A wanderer at the rift's mouth sells copies of a page for a copper each: the Terms' first line, and above it, a crowned seal. Nobody buys one. Dobbs buys three."},
	"f_recalled": {"truth": "t_first_seal", "channel": "letter", "gate": {"rival": "The Gilded Lance", "truth": "t_warden"}, "title": "Recalled",
		"text": "P.S. My cousin has been recalled to the capital. Something about a seal, a ring, and questions he would rather not answer. The Lance is, of course, above such things."},
}

## The witnesses (the Chronicle's Accounts). Each claim is heard once and
## kept; `truth` known turns it "struck", "confirmed" or "half".
const WITNESSES := [
	{"id": "ledger", "name": "The Grandmaster's ledger", "claims": [
		{"id": "ledger_voice", "text": "A voice from the deepest rift offered terms.", "truth": "t_terms_hers", "verdict": "struck"},
		{"id": "ledger_hold", "text": "The posts hold the Hollow back.", "truth": "t_knock", "verdict": "half"},
		{"id": "ledger_time", "text": "All the Grandmaster wanted was more time.", "truth": "t_blank_line", "verdict": "confirmed"}]},
	{"id": "hesper", "name": "Old Hesper", "claims": [
		{"id": "hesper_fever", "text": "She had a fever on the Night of Breaking, and missed it.", "truth": "t_fever", "verdict": "struck"},
		{"id": "hesper_spared", "text": "The Grandmaster sent her home to spare her.", "truth": "t_blank_line", "verdict": "confirmed"},
		{"id": "hesper_unread", "text": "She copied the Terms without reading them.", "truth": "t_clerk", "verdict": "struck"}]},
	{"id": "orla", "name": "Marshal Orla Venn, the Iron Chorus", "claims": [
		{"id": "orla_attack", "text": "The Hollow attacked the Vale.", "truth": "t_knock", "verdict": "struck"},
		{"id": "orla_deserter", "text": "Vaelith was a deserter who doomed her post.", "truth": "t_why_left", "verdict": "struck"},
		{"id": "orla_crown", "text": "The Crown saved the Vale by paying for the posts.", "truth": "t_first_seal", "verdict": "struck"}]},
	{"id": "ilse", "name": "Mother Ilse, the Last Lantern", "claims": [
		{"id": "ilse_betrayed", "text": "The Grandmaster betrayed the guilds.", "truth": "t_terms_hers", "verdict": "half"},
		{"id": "ilse_profit", "text": "The Hollow Crown Company opens rifts for profit.", "truth": "t_key", "verdict": "confirmed"},
		{"id": "ilse_paid", "text": "Someone pays Morrow to do it.", "truth": "t_paymaster", "verdict": "confirmed"}]},
	{"id": "morrow", "name": "Captain Morrow, the Hollow Crown Company", "claims": [
		{"id": "morrow_no_hollow", "text": "There is no Hollow, only doors and whoever holds the keys.", "truth": "t_key", "verdict": "half"},
		{"id": "morrow_himself", "text": "He works for nobody but himself.", "truth": "t_paymaster", "verdict": "struck"},
		{"id": "morrow_receipts", "text": "Every guild sells rifts; his just keeps receipts.", "truth": "t_paymaster", "verdict": "confirmed"}]},
	{"id": "aldric", "name": "Ser Aldric Vane, the Gilded Lance", "claims": [
		{"id": "aldric_sold", "text": "The guilds sold too much Essence, and the Hollow came to collect.", "truth": "t_sky", "verdict": "half"},
		{"id": "aldric_cousin", "text": "His cousin, the Warden of Rifts, keeps the Vale safe.", "truth": "t_warden", "verdict": "struck"},
		{"id": "aldric_myth", "text": "The key that opens rifts is a myth.", "truth": "t_key", "verdict": "struck"}]},
	{"id": "kael", "name": "Kael Ashborn, the Ashen Wolves", "claims": [
		{"id": "kael_hunger", "text": "The Hollow is hunger: you feed it or you burn it.", "truth": "t_sky", "verdict": "struck"},
		{"id": "kael_crown", "text": "The Ashen Crown kept the Vale alive.", "truth": "t_wolves", "verdict": "half"},
		{"id": "kael_owe", "text": "His wolves owe nobody.", "truth": "t_wolves", "verdict": "struck"}]},
	{"id": "hollow", "name": "The Hollow's people", "claims": [
		{"id": "hollow_knocked", "text": "They knocked, everyone at once, on every door.", "truth": "t_knock", "verdict": "confirmed"},
		{"id": "hollow_answered", "text": "Someone on this side wrote to them first.", "truth": "t_terms_hers", "verdict": "confirmed"},
		{"id": "hollow_promised", "text": "They were promised someone would come back.", "truth": "t_brannoch", "verdict": "confirmed"}]},
]
## When each claim is heard: the ledger's by page count, Hesper's by moment.
const CLAIM_PAGES := {"ledger_voice": 2, "ledger_hold": 3, "ledger_time": 7}
## Orla's claims come one per Iron Chorus letter, in order (the deserter
## claim rides on its fragment, f_orla_deserter).
const RIVAL_CLAIM_LETTERS := {"The Iron Chorus": [
	["orla_attack", "P.S. Keep your walls up. The Hollow came for the Vale once, the night the old guilds fell, and it will come again."],
	["orla_deserter", ""],
	["orla_crown", "P.S. Remember who paid for the posts. The Crown kept the Vale alive when the guilds could not. The Chorus remembers."]],
	"The Last Lantern": [
	["ilse_betrayed", "P.S. Whatever they tell you about the old guilds, remember that they were betrayed by the one they trusted most. I knew her."],
	["ilse_profit", "P.S. Watch the Hollow Crown Company. Count the rifts that open on their roads, and the contracts that follow."],
	["ilse_paid", "P.S. Morrow hasn't the coin to do what he does. Someone pays him. I'm still finding out who."]],
	"The Hollow Crown Company": [
	["morrow_no_hollow", "P.S. There's no Hollow, friend. There are doors, and whoever holds the keys. The rest is sermons."],
	["morrow_himself", "P.S. And before you ask: I work for nobody but myself. Ask anyone."],
	["morrow_receipts", "P.S. Every guild sells rifts. Mine just keeps receipts."]],
	"The Gilded Lance": [
	["aldric_sold", "P.S. My grandfather said the old guilds sold too much Essence to too many buyers, and the Hollow came to collect. Grandfather was rarely wrong."],
	["aldric_cousin", ""],
	["aldric_myth", "P.S. And no, there is no key that opens rifts. That's a story for children and smugglers."]],
	"The Ashen Wolves": [
	["kael_hunger", "P.S. The Hollow is a mouth. You feed it or you burn it. My wolves know which."],
	["kael_crown", "P.S. Say what you like about the Ashen Crown. For ten years nobody in the ash starved. Count that."],
	["kael_owe", "P.S. And my wolves owe nobody. Not the Crown, not the old guilds, not you."]]}
## Hesper's last claim, told at the pay table once the ledger has 3 pages.
const HESPER_UNREAD_SCENE := [["Wen", "Did you read the Terms, back then?"], ["Hesper", "I copied them. A clerk copies. Reading is for the people who sign."]]

## B1 · Let Vaelith go (Act I's finale, once t_why_left is known).
const VAELITH_SPARE_ESSENCE := 40     # of the act's 80
const VAELITH_FINALE_CUT := 0.05      # Act IV's finale is this much weaker
const VAELITH_CHORUS_RENOWN := 5      # an Iron Chorus rival: "harbouring a deserter"
const VAELITH_CHOICE := {"kind": "vaelith", "title": "Vaelith, listening", "subtitle": "Vaelith's Breach",
	"text": "Vaelith is down on one knee at the mouth of the Breach. She isn't looking at your heroes. She is listening to something behind it, and you know now what it is.",
	"choices": ["end", "spare"]}
const VAELITH_SPARED := {"title": "Let go", "subtitle": "Vaelith's Breach",
	"text": "Your heroes lower their weapons. Vaelith looks at them for a long moment, then walks back into the Breach on her own feet. At dawn she comes out carrying a child wrapped in her cloak, and does not explain. She asks for work.\n\n(Vaelith joins as a champion. No relic from this finale, and half its Essence.)"}
const VAELITH_SPARED_OUTRO := "The Breach closes behind Vaelith, by her own hand this time. Under her cloak is an Accord badge with the oath scratched out: she was one of them, and she left her post. Whatever the old guilds did that night, she has been undoing it. Greater Rifts are open to your guild."

## B5 · Hesper signs (the Renew ending, once t_blank_line is known): she
## takes the forty-first post, and is gone from the pay table in every
## later guild, until a guild rewrites the Terms and brings her home.
const HESPER_POST_LORE := "The Grandmaster's clerk, who wrote the Terms out fair and ran from them. Twenty years later she came back and signed the forty-first line herself, for %s."
const HESPER_POST_MEMORY := "Tell Wen to keep the books straight. Tell Dobbs the green ink is in the bottom drawer. Tell %s it was my turn."
## Texts that change while Hesper holds the post.
const HESPER_POSTED_ALT := {
	"sky_beneath": "Wen finds the last page of the Grandmaster's ledger stuck to the back cover, in a hand neither she nor Dobbs knows. It is a reply. \"We accept your Terms. Hold your doors, and we will not come through them. Our sky is falling. We will not ask again.\" Wen reads it twice and puts on her coat.",
	"rewrite_hint": "There is a third way. Hesper left the forty-second line open before she signed: rewrite the Terms, and the posts are held in turns. She would come home.",
	"rewrite": "Your guild climbs down to the forty-first post with the Terms, and Hesper writes the forty-second line there, in her own hand, because hers is the only one the Terms accept: the posts are held in turns. Then she climbs out with you. The forty in the pillars walk home, and nobody holds the Hollow alone any more.\n\n(Riftbreaks have ended, every champion of this guild is free, Hesper is home, and the old Accord halls can be restored.)",
	"line_2": "A letter comes up from the forty-first post, in green ink. \"I was the clerk. I wrote her letters and her contracts, and I wrote the Terms out fair: forty-one lines. The night they were signed, she sent me home with a note that said I had a fever. I kept the note. I never told %s. I'm telling you. H.\"",
	"line_3": "Another letter from the post, in green ink. \"There was a line under the forty-first. She made me leave it blank. It says the Terms can be changed, once, by a guild that has both kept them and broken them, and a guild is everyone who came before it. %s kept them. %s burned them. Write the forty-second line, and come and fetch me. H.\"",
	"line_3_wait": "Another letter from the post, in green ink. \"There was a line under the forty-first. She made me leave it blank. It says the Terms can be changed, once, by a guild that has both kept them and broken them, and a guild is everyone who came before it. None of ours has done both yet. H.\"",
	"charter_quiet": "Morrow's contracts start arriving on your board, generous ones. Wen reads the first, folds it, and doesn't write anything down. She doesn't have to.\n\n(Contracts pay 25% more Gold for the rest of the campaign.)",
	"echo_oath": "Wen holds it a long time, then sends it down to the forty-first post. It comes back with a note in green ink: \"That was the Grandmaster, before. Give it to the village.\" They give it to the village.",
	"iron_oath": "The Iron Oath trained shield-walls. Their drill yard is still marked out in white stones, and Dobbs walks it once, end to end, counting, before he lets the recruits in.",
	"tooltip": "Wen keeps the guild's chronicle and Dobbs keeps its books. Old Hesper, the last of an Accord guild, holds the forty-first post; her letters come up in green ink.",
}
## The pay table while Hesper holds the post: one quiet scene of its own.
const HESPER_POSTED_SCENE := [["Dobbs", "I keep setting four cups."], ["Wen", "Send one down to the post."], ["Dobbs", "It'd be cold by the time it got there."], ["Wen", "She'd drink it anyway."]]


## B2 · Turn Morrow (the Charter War, once t_paymaster is known): a bribe;
## the Company stops hunting, Morrow joins on double wages, and the Crown
## remembers at its hearing.
const MORROW_TURN_COST := 500
const MORROW_TURN_HEARING := 15     # Renown to the rival at the Crown's hearing
const MORROW_HERO_LEVEL := 6
const MORROW_TURNED := {"title": "Morrow, turned", "subtitle": "The Charter War",
	"text": "You don't take the page to the herald. You take it to Morrow, with the second column showing, and the coin. He reads it, counts the coin, and laughs for a long time. \"The Treasury's man, bought by a guild. Fine. I was tired of their calendar.\"\n\n(Morrow joins your guild as a Rank S rogue on double wages, and the Company stops hunting. Miss his pay once and he's gone. The Crown will remember at its hearing.)"}

## B3 · Buy the hearing (the Crown's hearing, when losing, once t_warden is
## known): the Charter at a price, paying less, and an audit in Act IV.
const HEARING_BUY_COST := 1500
const HEARING_BUY_PAY := 1.1        # instead of CHARTER_PAY
const HEARING_AUDIT_SHARE := 0.2    # of Gold, once, at Act IV's first payday
const HEARING_CHOICE := {"kind": "hearing", "title": "By Royal Hand", "subtitle": "The Crown's hearing",
	"text": "The herald's list has another guild's name at the top. The Warden of Rifts' office, you happen to know, has a price, and a cousin who once mislaid a key.",
	"choices": ["accept", "buy"]}
const HEARING_BOUGHT := {"title": "By Royal Hand", "subtitle": "The Royal Charter is yours, at a price",
	"text": "The herald clears his throat, turns his list over, and reads your name off the back of it. Nobody shakes your hand.\n\n(Contracts pay 10% more Gold and Essence. A bought Charter earns no Laurels, and the Crown's auditors will come in Act IV.)"}
const HEARING_AUDIT := {"title": "The Crown's auditors", "subtitle": "Act IV",
	"text": "Two clerks in grey arrive with the Warden's seal and go through Dobbs's books for three days. They leave with a fifth of the vault and a receipt.\n\n(-20% of your Gold.)"}

## B4 · Pip's Key (once Morrow is beaten or turned, and t_key is known).
const KEY_BREAK_RENOWN := 5
const KEY_HALL_FORCED := 1.25       # the Grandmaster's Hall, its doors forced
const KEY_CHOICE := {"kind": "key", "title": "The key", "subtitle": "The Charter War",
	"text": "Morrow's key is on the table: old iron with the Accord's sigil, warm in a way iron shouldn't be. It opens any rift's door, from either side. Pip wants it back. Wen wants it in the river.",
	"choices": ["keep", "break"]}
const KEY_KEPT := {"title": "The key, kept", "subtitle": "The Charter War",
	"text": "The key goes on a cord round the quartermaster's neck. Dobbs says it hums when a rift is near, and it does.\n\n(Choose each rift's region in the Rift Hall. Every Riftbreak comes a rank higher: the doors know who has the key.)"}
const KEY_BROKEN := {"title": "The key, broken", "subtitle": "The Charter War",
	"text": "It takes the smith, two hammers and most of a morning. When the key breaks, every dog in the Vale barks at once, then stops.\n\n(+5 Renown. Riftbreaks warn you a day earlier. The Grandmaster's Hall will have to be forced open, at a quarter more.)"}
const KEY_HALL_TEXT := "The last hall is the one the Accord was sworn in. Its doors open for no key now; the guild forces them with bars and patience. Inside is a long table, forty-one chairs, and one that someone has dusted every year. The Vale has its keepers again."

## B6 · Pour out the lantern (Ezra's visit, once t_lantern is known).
const LANTERN_PER_ECHO := 50        # Essence for each kept echo
const LANTERN_ESSENCE := 0.10       # contracts pay this much more Essence
const EZRA_CHOICE_TEXT := "\n\nHe holds the lantern out to you, open. You know now what's in it, and that the echoes in your vault would fit."
const LANTERN_POURED := {"title": "The lantern, full", "subtitle": "What the Rifts Take",
	"text": "You pour the vault's kept echoes into Ezra's lantern, one crystal at a time. The heroes they touched sit down, suddenly tired, and look lighter. Ezra bows, which nobody in the Vale has seen him do, and gives you the Ninth Lamp's own reckoning of what Essence is worth.\n\n(Contracts pay 10% more Essence for the rest of the campaign. The Vale will remember what you gave.)"}

## Branch prices with the Sworn to the Ledger oath.
const LEDGER_OATH_COST := 1.5
const LEDGER_OATH_FRAGMENTS := 2.0
## Founding options a truth opens (charters in FOUNDINGS, the gift in
## LEGACY_GIFTS, the oath in OATHS carry "truth" / "truths").
const PIPS_KEY_UNTIL_ACT := 3       # the gift: choose rift regions while campaign_act <= this


## B7 · Brannoch's door (Act VI's start, once t_brannoch is known): leave
## him holding (the City's gate never breaks) or free him (a champion, and
## the gate comes at Rank SS).
const BRANNOCH_LEVEL := 3
const BRANNOCH_CHOICE := {"kind": "brannoch", "title": "Brannoch's door", "subtitle": "The Inverted City",
	"text": "Under the City, at the deepest door, a knight in chains is still holding. Brannoch. He promised a child on the other side he would come back for her, and he never left the door to do it.",
	"choices": ["leave", "free"]}
const BRANNOCH_LEFT := {"title": "Still holding", "subtitle": "The Inverted City",
	"text": "You tell him she's grown, and safe, and waiting on our side. He laughs, once, and sets his shoulder against the door again. \"Then it can wait for me a little longer.\"\n\n(The City's gate holds: Act VI's gate objective is met. Brannoch stays at his post.)"}
const BRANNOCH_FREED := {"title": "Relieved", "subtitle": "The Inverted City",
	"text": "Your heroes take the door's weight together, and Brannoch steps out of the light for the first time in twenty years. The door shudders. Something on the other side has noticed.\n\n(Brannoch joins as a champion. The City's gate will come at Rank SS.)"}

## B8 · Let the Choir sing (their crossing, once t_knock is known).
const CHOIR_SING_RENOWN := 5
const CHOIR_SING_MORALE := 15
const CHOIR_SANG := {"title": "The Choir sings", "subtitle": "A crossing",
	"text": "They sing the Accord's oath in the square, badly and beautifully, and the whole village joins in the second verse. The song carries. Far below, something hears it.\n\n(+5 Renown and +15 morale for every hero. A Riftbreak swells in two days.)"}

## B9 · The First Signatory: a hidden sixth crossing, once the Hall holds a
## guild that kept both worlds open and t_terms_hers is known.
const SIGNATORY_BOUNTY := 300
const SIGNATORY := {"id": "signatory", "title": "The First Signatory",
	"text": "An old woman at the door, with a satchel she won't let go of. She says she signed for her side, once, and has come to see who signed for ours."}
const SIGNATORY_TIPS := ["She joins as a Hollow-born Rank A cleric, and opens her satchel", "+300 Gold: the Crown pays three times the usual for this one"]

## The epilogue: the first signature (after Book II's ending, once every
## EPILOGUE_TRUTHS is known; once per player). Read the first page aloud,
## or burn it: either way, every later guild lives in the Vale you made.
const EPILOGUE_LAURELS := 30
const EPILOGUE_PENSION := 1000      # burn: this guild, every CONTEST_DAYS
const EPILOGUE_TITHE := 0.10        # burn: later guilds, every CONTEST_DAYS
const EPILOGUE_READ_GOLD := 0.9     # read: contracts' Gold (no Treasury)
const EPILOGUE_READ_ESSENCE := 0.9  # read: Essence gains
const EPILOGUE_READ_LAURELS := 1.1  # read: each guild's Laurels
const EPILOGUE_MOOT_WAGES := 0.9    # read: winning the Vale's Moot lowers wages
const EPILOGUE_BURN_GOLD := 1.15    # burn: contracts' Gold (royal patronage)
const EPILOGUE_CHOICE := {"kind": "epilogue", "title": "The first signature", "subtitle": "Epilogue",
	"text": "The Crown's herald has come to the Vale to read the new Royal Charter in the square. Wen has the Terms' first page in her satchel, with the Crown's seal above every name. The square is full. Everyone is waiting for someone to speak.",
	"choices": ["read", "burn"]}
const EPILOGUE_ENDING := {
	"read": {"title": "Read aloud", "subtitle": "Epilogue",
		"text": "Wen reads the first page in the square, slowly, so the back rows can hear. The herald leaves before she finishes. By winter the Charter is gone from every wall, and the villages choose their own guilds at a moot.\n\n(+30 Laurels. In every later guild: the Crown's hearing is the Vale's Moot, contracts pay 10% less Gold, rifts 10% less Essence, guilds earn 10% more Laurels, and Hollow-born heroes come from the start.)"},
	"burn": {"title": "Burned", "subtitle": "Epilogue",
		"text": "The page burns green, like the Terms did. The herald reads the Charter to a quiet square and leaves your guild a letter of thanks with a pension in it. Nobody mentions the smell of smoke.\n\n(+30 Laurels, and 1,000 Gold every 28 days for this guild. In every later guild: royal patronage, contracts pay 15% more Gold, the Crown takes a tenth of the vault every 28 days, and the Iron Chorus is always the rival.)"},
}
const MOOT_HEARING := {
	"won": {"title": "The Vale's Moot", "subtitle": "The villages choose your guild",
		"text": "Every village sends someone to the moot, and the show of hands isn't close. No herald, no seal: the Vale's own say-so hangs in your hall.\n\n(Wages are 10% lower: heroes want to work for the Vale's guild.)"},
	"lost": {"title": "The Vale's Moot", "subtitle": "The villages choose %s",
		"text": "The moot is long, and loud, and %s takes it. The villages will bring their troubles to another door for a while. The rifts don't care whose name the villages call."},
}
const MOOT_NOTICE := {"title": "The Vale's Moot", "subtitle": "A notice on every guild door in the Vale",
	"text": "At the end of the year the villages will hold a moot and choose the guild they trust most. Until then, every guild works for its Renown.\n\nThe loudest of them, %s, led by %s, has noticed your guild."}
