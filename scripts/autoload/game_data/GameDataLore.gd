extends "res://scripts/autoload/game_data/GameDataBreach.gd"
## GameData, part 6b: the Unwritten Accord, the story web across guilds.
## Fragments (50 words at most) are found in play and kept in the legacy;
## any two of a truth's fragments make it known; a known truth opens a
## branch (a choice with a price) in this guild or a later one. Witnesses'
## claims are struck through or confirmed as truths come in.
## Design doc: "The Unwritten Accord". Phase 1: the Ranger Who Left, the Clerk.

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
]

const TRUTHS := {
	"t_squad": {"arc": "ranger", "text": "Vaelith's squad took four posts in a row at Thornwood.",
		"hint": "Rangers' tags turn up in the Vale's rifts."},
	"t_why_left": {"arc": "ranger", "text": "Vaelith didn't desert. She heard children behind her door.",
		"hint": "Someone who knew Vaelith might say what she was listening for.",
		"opens": "At Act I's finale, a guild can let Vaelith go."},
	"t_held_open": {"arc": "ranger", "text": "The great Breach is the door Vaelith held open, and she is still in it.",
		"hint": "A guild that let Vaelith go would know where she went."},
	"t_clerk": {"arc": "clerk", "text": "Hesper wrote the Terms out fair. She knew every word.",
		"hint": "Hesper's handwriting is in more places than she admits."},
	"t_fever": {"arc": "clerk", "text": "There was no fever. Hesper wrote the note herself, and ran.",
		"hint": "Ask who nursed Hesper that week."},
	"t_blank_line": {"arc": "clerk", "text": "The Grandmaster let Hesper go, and left the forty-second line blank for her.",
		"hint": "The Grandmaster's own hall remembers who it waited for.",
		"opens": "At the Renew ending, Hesper can sign the forty-first line herself. The Clerk's Copy joins the founding gifts."},
}

## channel: where it's found.
##   relic   a sealed rift's relic carries it (gate: region, rank_min)
##   seal    a sealed rift turns it up (gate: region, rank_min, ...)
##   ledger  a sealed rift, once the ledger has `pages` pages
##   payday  a pay-table scene ("lines")
##   letter  a postscript to the rival's weekly letter (gate: rival)
##   echo / finale / crossing / line / hall / ending: at that event ("on")
## gate keys: region, rank_min, truth, rival, charter, branch ("id:value"), hall, pages.
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
]
## When each claim is heard: the ledger's by page count, Hesper's by moment.
const CLAIM_PAGES := {"ledger_voice": 2, "ledger_hold": 3, "ledger_time": 7}
## Orla's claims come one per Iron Chorus letter, in order (the deserter
## claim rides on its fragment, f_orla_deserter).
const RIVAL_CLAIM_LETTERS := {"The Iron Chorus": [
	["orla_attack", "P.S. Keep your walls up. The Hollow came for the Vale once, the night the old guilds fell, and it will come again."],
	["orla_deserter", ""],
	["orla_crown", "P.S. Remember who paid for the posts. The Crown kept the Vale alive when the guilds could not. The Chorus remembers."]]}
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
