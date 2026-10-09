extends "res://tests/base_test.gd"
## 0.70: Spanish and Chinese join Turkish. Each language builds hero, warden
## and item names in its own word order (NameTranslation.SHAPES); Spanish
## keeps the English -s plural; Chinese is offered once its font is there
## (or off the web).


func run() -> void:
	var codes: Array = GameData.LANGUAGES.map(func(p): return str(p[0]))
	check(codes.has("es") and codes.has("zh_CN") and ResourceLoader.exists("res://locale/es.po") and ResourceLoader.exists("res://locale/zh_CN.po"), "Spanish and Chinese are listed and have their files")
	var NT = load("res://scripts/autoload/NameTranslation.gd")
	var es = NT.new("es")
	var zh = NT.new("zh_CN")
	var tr_ = NT.new("tr")
	var hero := "Roth the %s" % str(GameData.CLASSES[0]["name"])
	check(str(es._get_message(hero, "")).begins_with("Roth, "), "Spanish: the name, then the class (%s)" % es._get_message(hero, ""))
	check(str(zh._get_message(hero, "")).ends_with("·Roth"), "Chinese: the class, then the name (%s)" % zh._get_message(hero, ""))
	check(str(tr_._get_message(hero, "")).ends_with(" Roth"), "Turkish unchanged (%s)" % tr_._get_message(hero, ""))
	var before := TranslationServer.get_locale()
	TranslationServer.set_locale("es")
	var es_pl := GameData.pl(3)
	var es_heroes := GameData.pl(3, "es")
	TranslationServer.set_locale("zh_CN")
	var zh_pl := GameData.pl(3)
	TranslationServer.set_locale(before)
	check(es_pl == "s" and zh_pl == "", "plural suffix: Spanish keeps it, Chinese drops it")
	check(es_heroes == "s", "hero%s is héroe%s in Spanish: héroes, not héroees (%s)" % es_heroes)
	check(GameState.language_ready("es") and GameState.language_ready("en"), "Spanish is always offered")
