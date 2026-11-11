class_name Demo
extends RefCounted
## Демо-сцены для автоматических скриншотов (--demo=имя --shot=файл.png).

static var rest_plan: Array = []       # кто куда садится и ложится в сценах rest… (забирает WorldView.rest_plan)

static func create(kind: String) -> GameState:
	var g := GameState.new_game(1990)
	var p: GameState.Player = g.players[0]
	p.name = "Тест"
	g.real_clock = false          # у снимков своё время суток
	g.time = 11 * 60.0
	match kind:
		"inside", "inv":
			_into_house(g, p)
		"night":
			g.time = 23 * 60.0
		"evening":
			g.time = 19 * 60.0 + 50.0
		"gear", "outfit", "crowd", "knocked", "armed", "chat", "chatlog", "rp", "rpopen":
			_open_street(g, p)
			p.wear = {"torso": "suit_jacket", "legs": "pants", "feet": "shoes"}
			p.face = Vector2(0, 1)
			for id in ["hoodie", "jeans", "work_vest", "boots", "medkit"]:
				Items.add_to(p.inv, id, 1)
	if kind == "crowd" or kind == "knocked" or kind == "armed" or kind == "chat" or kind == "chatlog" or kind == "rp" or kind == "rpopen":
		var outfits := [{"torso": "hoodie", "legs": "shorts", "feet": "sneakers"}, {"torso": "work_vest", "legs": "work_pants", "feet": "boots"},
			{"torso": "dress", "feet": "shoes"}, {"torso": "biker_vest", "legs": "jeans", "feet": "boots"}]
		var genders := ["m", "m", "f", "f"]
		for k in 4:
			var q := GameState.Player.new(k + 1)
			q.pos = g.unstick(p.pos + Vector2.from_angle(k * 1.4 + 0.5) * 1.6, GameState.PLAYER_R)
			q.rpos = q.pos
			q.face = (p.pos - q.pos).normalized()
			q.wear = outfits[k]
			q.look = GameState.default_look(k + 1, genders[k])
			q.name = ["Джек", "Майк", "Сара", "Тони"][k]
			g.players.append(q)
		if kind == "knocked":
			g.knock_out(g.players[1])
		if kind == "armed":
			var arms := ["bat", "pistol", "knife", "crowbar", "hammer"]
			for k in 5:
				g.players[k].eq = arms[k]
	if kind == "catalog":
		_open_street(g, p)
		p.face = Vector2(0, 1)
		var looks := [
			["m", {"head": "hard_hat", "torso": "work_vest", "legs": "work_pants", "feet": "boots"}],
			["m", {"head": "swat_helmet", "torso": "tactical", "legs": "tactical_pants", "feet": "combat_boots"}],
			["m", {"head": "farmer_hat", "torso": "overalls", "feet": "rubber_boots"}],
			["m", {"torso": "biker_vest", "legs": "ripped_jeans", "feet": "high_boots"}],
			["m", {"torso": "shirt", "legs": "cargo", "feet": "hiking_boots"}],
			["m", {"torso": "hoodie_red", "legs": "jeans", "feet": "sneakers"}],
			["m", {"torso": "tshirt_yellow", "legs": "shorts", "feet": "sneakers"}],
			["f", {"torso": "tactical", "legs": "tactical_pants", "feet": "combat_boots"}],
			["f", {"head": "hard_hat", "torso": "work_vest", "legs": "work_pants", "feet": "boots"}],
			["f", {"torso": "dress_red", "feet": "shoes"}],
			["f", {"torso": "dress_black", "feet": "high_boots"}],
			["f", {"torso": "tshirt_navy", "legs": "jeans", "feet": "hiking_boots"}],
		]
		for k in looks.size():
			var q := GameState.Player.new(k + 1)
			q.pos = g.unstick(p.pos + Vector2((k % 6) * 1.1 - 2.75, 0.4 + floorf(k / 6.0) * 2.4), GameState.PLAYER_R)
			q.rpos = q.pos
			q.face = Vector2(0, 1)
			q.look = GameState.default_look(k + 1, looks[k][0])
			q.wear = looks[k][1]
			q.name = ""
			g.players.append(q)
	if kind.begins_with("mil"):
		# витрина мебели военной части: стена, перед ней пол, мебель в ряд; milN — игрок у N-го участка
		_open_street(g, p)
		var w := g.world
		var row := "bbklegGarmmBfq"
		var x0 := int(p.pos.x) - 7
		var y0 := int(p.pos.y) - 3
		for i in range(-1, row.length() + 1):
			w.set_t(x0 + i, y0, GameWorld.WALL)
			for dy in range(1, 6):
				w.set_t(x0 + i, y0 + dy, GameWorld.TILEFLOOR)
		for i in row.length():
			w.set_t(x0 + i, y0 + 1, GameWorld.MAP_CHARS.find(row[i]))
		var keep := []                     # фонари и прочие объекты улицы с витрины убрать
		for e in w.props:
			if absf(e[1] - (x0 + 7)) > 12 or absf(e[2] - (y0 + 3)) > 8:
				keep.append(e)
		w.props = keep
		w.index_props()
		w.compute_buildings()
		var sect := int(kind.substr(3)) if kind.length() > 3 else 0
		p.pos = Vector2(x0 + 7.0, y0 + (4.6 if sect > 0 else 3.2))
		p.rpos = p.pos
		p.face = Vector2(0, -1)
		p.wear = {"head": "swat_helmet", "torso": "tactical", "legs": "tactical_pants", "feet": "combat_boots"}
	if kind.begins_with("din"):
		# витрина мебели столовой: у стены — раздача и кухня, в зале — столы со стульями и скамьями
		_open_street(g, p)
		var w := g.world
		var rows := ["hhNuPoizssyp",       # у стены
			"............",
			".hh..jj..hh.",
			".nn..nn..nn.",
			".hh..jj.....",
			"............"]
		var x0 := int(p.pos.x) - 6
		var y0 := int(p.pos.y) - 4
		for i in range(-1, 13):
			w.set_t(x0 + i, y0, GameWorld.WALL)
			for dy in range(1, 9):
				w.set_t(x0 + i, y0 + dy, GameWorld.TILEFLOOR)
		for r in rows.size():
			for i in 12:
				if rows[r][i] != ".":
					w.set_t(x0 + i, y0 + 1 + r, GameWorld.MAP_CHARS.find(rows[r][i]))
		var keep := []
		for e in w.props:
			if absf(e[1] - (x0 + 6)) > 12 or absf(e[2] - (y0 + 4)) > 10:
				keep.append(e)
		w.props = keep
		w.index_props()
		w.compute_buildings()
		p.pos = Vector2(x0 + 6.0, y0 + (7.6 if kind.length() > 3 else 6.5))
		p.rpos = p.pos
		p.face = Vector2(0, -1)
	if kind.begins_with("pol") or kind.begins_with("jail"):
		# витрины мебели полицейского участка: pol — приёмная, кабинеты, дежурная часть; jail — камеры и допросная
		_open_street(g, p)
		var w := g.world
		var rows := ["1YXXU7456.QZJKI.",
			"..........3.....",
			"................",
			"..3...3..3....+.",
			".000..2..VV.....",
			"......h..hh.....",
			"................"]
		if kind.begins_with("jail"):
			rows = ["EE..H#EE.jH#",
				".....#.....#",
				"99A99#99A99#",
				"............",
				"..hh....3...",
				"..88....8...",
				"..hh....3..."]
		var cols: int = rows[0].length()
		var x0 := int(p.pos.x) - cols / 2
		var y0 := int(p.pos.y) - 4
		for i in range(-1, cols + 1):
			w.set_t(x0 + i, y0, GameWorld.WALL)
			for dy in range(1, 10):
				w.set_t(x0 + i, y0 + dy, GameWorld.TILEFLOOR)
		for r in rows.size():
			for i in cols:
				if rows[r][i] != ".":
					w.set_t(x0 + i, y0 + 1 + r, GameWorld.MAP_CHARS.find(rows[r][i]))
		var keep := []
		for e in w.props:
			if absf(e[1] - (x0 + cols / 2)) > 14 or absf(e[2] - (y0 + 4)) > 10:
				keep.append(e)
		w.props = keep
		w.index_props()
		w.compute_buildings()
		p.pos = Vector2(x0 + cols * 0.5, y0 + 8.4)
		p.rpos = p.pos
		p.face = Vector2(0, -1)
		p.wear = {"torso": "shirt", "legs": "pants", "feet": "shoes"}
	if kind.begins_with("hos"):
		# витрины мебели больницы по отделам: hos1 — холл, 2 — палата, 3 — операционная, 4 — процедурная и склад,
		# 5 — кабинет главного врача, 6 — зал собраний, 7 — комната персонала, 8 — лаборатория и морг
		_open_street(g, p)
		var w := g.world
		var scenes := {
			1: ["вдuXXгXXP.ббее",
				"..............",
				"....3..3......",
				"...ааааа......",
				".............."],
			2: ["жжз.йзжи.йкжз.",
				"....й.ж..й.ж..",
				"..............",
				".............."],
			3: ["пп.рхс.туф..",
				"............",
				"....мк......",
				"...нлло.....",
				"............"],
			4: ["ццчш.щщщъыьы",
				"............",
				"............"],
			5: ["ээюяP.XX.5U.",
				"............",
				"....3.......",
				"...VV.......",
				"...h........",
				"............"],
			6: ["P.Г.Б..Г..u.",
				"............",
				"....В.......",
				"...3333.....",
				"..3АААА3....",
				"...3333.....",
				"............"],
			7: ["ДLLoF.Е.XгX.Жu",
				"..............",
				"....hh........",
				"....nn........",
				"....hh........",
				".............."],
			8: ["ЗЗЗ.щ.ИИИ.ее",
				"............",
				"............"]}
		var num := int(kind.substr(3)) if kind.length() > 3 else 1
		var rows: Array = scenes.get(num, scenes[1])
		var floor_t := GameWorld.WOOD if num == 5 or num == 6 else GameWorld.TILEFLOOR
		var cols := 14                     # у всех витрин больницы одна ширина — одна и та же стена
		var x0 := int(p.pos.x) - cols / 2
		var y0 := int(p.pos.y) - 4
		for i in range(-1, cols + 1):
			w.set_t(x0 + i, y0, GameWorld.WALL)
			for dy in range(1, 10):
				w.set_t(x0 + i, y0 + dy, floor_t)
		for r in rows.size():
			for i in rows[r].length():
				if rows[r][i] != ".":
					w.set_t(x0 + i, y0 + 1 + r, GameWorld.MAP_CHARS.find(rows[r][i]))
		var keep := []
		for e in w.props:
			if absf(e[1] - (x0 + cols / 2)) > 14 or absf(e[2] - (y0 + 4)) > 10:
				keep.append(e)
		w.props = keep
		w.index_props()
		w.compute_buildings()
		p.pos = Vector2(x0 + cols * 0.5, y0 + rows.size() + 1.9)
		p.rpos = p.pos
		p.face = Vector2(0, -1)
		p.wear = {"torso": "shirt", "legs": "pants", "feet": "shoes"}
	if kind.begins_with("city") or kind.begins_with("media"):
		# витрины мебели мэрии по отделам: city1 — холл и охрана, 2 — зал приёма граждан, 3 — архив и земельный отдел,
		# 4 — кабинет мэра, 5 — зал совета, 6 — пресс-зал и зал регистрации, 7 — казна и службы.
		# Мебель СМИ: media1 — редакция, 2 — фотолаборатория и типография, 3 — радиостудия, 4 — телестудия, 5 — аппаратная
		_open_street(g, p)
		var w := g.world
		var scenes := {
			1: ["CITYSEAL DIRBOARD . FOUNTAIN ASHBIN . PLANT SOFA SOFA MAGTABLE . FLAGSTAND CITYFLAG PAYPHONE",
				". . . . . . . . OFFICECHAIR . . . . .",
				". ROPEPOST ROPEPOST ROPEPOST . . . INFODESK INFODESK INFODESK . . . .",
				". . . . . . . . . . . . . .",
				". ROPEPOST METALDET XRAYBELT XRAYBELT . . . . . . SECDESK . .",
				". . . . . . . . . . . OFFICECHAIR . ."],
			2: ["TICKETER FORMDESK FORMDESK . WAITCHAIRS WAITCHAIRS WAITCHAIRS . PHOTOBOOTH . NOTICEBOARD WATERCOOLER . COPIER",
				". . . . . . . . . . . . . .",
				". . . . . . . . . OFFICECHAIR OFFICECHAIR . . .",
				"CLERKWIN CLERKWIN CLERKWIN CASHIER CASHIER . . . . CLERKWIN CASHIER . TYPEDESK .",
				"OFFICECHAIR . OFFICECHAIR OFFICECHAIR . . . . . . . . OFFICECHAIR .",
				". . . . . . . . . . . . . ."],
			3: ["ARCHSHELF ARCHSHELF ARCHSHELF CARDCAT CARDCAT . PLANCAB PLANCAB . MICROFILM . DRAFTTABLE . CITYMODEL",
				". . . . . . . . . . . . . .",
				". . . . . . . . . . . . . ."],
			4: ["TROPHYCASE PORTRAIT FIREPLACE PORTRAIT GRANDCLOCK PORTRAIT BOOKCASE BOOKCASE . FLAGSTAND CITYSEAL CITYFLAG . GLOBE",
				". . . . . . . . . . EXECCHAIR . . .",
				". . . . . . . . . MAYORDESK MAYORDESK . . .",
				". . SOFA SOFA . . . . . . . . . .",
				". . MAGTABLE . . . . . . . . . . .",
				". . . . . . . . . . . . . ."],
			5: ["FLAGSTAND . . . CITYSEAL . . . CITYFLAG . VOTEBOOTH VOTEBOOTH BALLOTBOX .",
				". . OFFICECHAIR OFFICECHAIR EXECCHAIR OFFICECHAIR OFFICECHAIR . . . . . . .",
				". . DAIS DAIS DAIS DAIS DAIS . . . . . . .",
				". . . . . . . . . . . . . .",
				". . . . LECTERN . . . . . . . . .",
				". PEW PEW PEW . PEW PEW PEW . . . . . .",
				". PEW PEW PEW . PEW PEW PEW . . . . . ."],
			6: ["PRESSWALL PRESSWALL PRESSWALL PRESSWALL . . . PLANT WEDARCH REGTABLE PLANT . . .",
				". . PODIUM . . . . . . . . . . .",
				". . . . . . . . . . . . . .",
				"PEW PEW PEW PEW . . . . PEW PEW PEW . . .",
				". . . . . . . . PEW PEW PEW . . .",
				"TVCAMERA . . TVCAMERA . . . . . . . . . .",
				". . . . . . . . . . . . . ."],
			7: ["VAULT . MONEYTABLE . MAINFRAME MAINFRAME . MAILSORT MAILSORT MAILCART . JANITOR . .",
				". . OFFICECHAIR . . . . . . . . . . .",
				". . . . . . . . . . . . . ."]}
		var media := {
			1: ["MEDIASIGN WORLDCLOCKS PAGEBOARD . NEWSRACK TELETYPE . FAXSTAND COPIER . NEWSBOX PAPERBUNDLES CAMCASES MEDIAGEAR",
				". . . . . OFFICECHAIR OFFICECHAIR . . . . . . .",
				". REPORTERDESK REPORTERDESK . . REPORTERDESK REPORTERDESK . . LAYOUTTABLE LAYOUTTABLE . . .",
				". OFFICECHAIR OFFICECHAIR . . . . . . . OFFICECHAIR . . .",
				". . . . . . . . . . . . . ."],
			2: ["ENLARGER DEVSINK DRYLINE DRYLINE . PHOTOBACK PHOTOBACK . PRINTPRESS PRINTPRESS . CUTTER PAPERROLLS PAPERBUNDLES",
				". . . . . . . . . . . . . .",
				". . . . STUDIOLIGHT . . STUDIOLIGHT . . . . . .",
				". . . . . . . . . . . . . ."],
			3: ["ONAIR FOAMPANEL FOAMPANEL RECORDSHELF RECORDSHELF . REELDECK TURNTABLES . SPEAKERS FOAMPANEL FOAMPANEL ONAIR .",
				". . . . . . . . . . . . . .",
				". . . . . STUDIOWALL STUDIOWALL STUDIOWALL . . OFFICECHAIR . . .",
				". . RADIOCONSOLE . . . . . . OFFICECHAIR GUESTTABLE OFFICECHAIR . .",
				". . OFFICECHAIR . . . . . . . . . . .",
				". . . . . . . . . . . . . ."],
			4: ["BLUESCREEN BLUESCREEN WEATHERMAP . BACKDROP BACKDROP BACKDROP BACKDROP . MAKEUP COSTUMERACK . ONAIR .",
				". . . . . OFFICECHAIR OFFICECHAIR . . . . . . .",
				". . . . . ANCHORDESK ANCHORDESK . BOOMMIC . . . . .",
				". . . . . . . . . . . . . .",
				". STUDIOLIGHT . . PROMPTER . . STUDIOLIGHT . . . . . .",
				". TVCAMERA . STUDIOLIGHT . TVCAMERA TVCAMERA . . . . . . .",
				". . . . . . . . . . . . . ."],
			5: ["TVWALL TVWALL TVWALL . VTRRACK TAPESHELF TAPESHELF . TRANSMITTER . EDITBAY . . .",
				". . . . . . . . . . OFFICECHAIR . . .",
				". SWITCHER AUDIOMIX . . . . . . . . . . .",
				". OFFICECHAIR OFFICECHAIR . . . . . . . . . . .",
				". . . . . . . . . . . . . ."]}
		var is_media := kind.begins_with("media")
		var num := int(kind.substr(5 if is_media else 4)) if kind.length() > (5 if is_media else 4) else 1
		if is_media:
			scenes = media
		var rows: Array = scenes.get(num, scenes[1])
		var floor_t := GameWorld.WOOD if (num == 4 or num == 5) and not is_media else GameWorld.TILEFLOOR
		var cols := 14
		var x0 := int(p.pos.x) - cols / 2
		var y0 := int(p.pos.y) - 4
		for i in range(-1, cols + 1):
			w.set_t(x0 + i, y0, GameWorld.WALL)
			for dy in range(1, 10):
				w.set_t(x0 + i, y0 + dy, floor_t)
		var names: Dictionary = (GameWorld as Script).get_script_constant_map()
		for r in rows.size():
			var cells: PackedStringArray = (rows[r] as String).split(" ")
			for i in cells.size():
				if cells[i] != ".":
					w.set_t(x0 + i, y0 + 1 + r, int(names[cells[i]]))
		var keep := []
		for e in w.props:
			if absf(e[1] - (x0 + cols / 2)) > 14 or absf(e[2] - (y0 + 4)) > 10:
				keep.append(e)
		w.props = keep
		w.index_props()
		w.compute_buildings()
		p.pos = Vector2(x0 + cols * 0.5, y0 + rows.size() + 1.9)
		p.rpos = p.pos
		p.face = Vector2(0, -1)
		p.wear = {"torso": "suit_jacket", "legs": "pants", "feet": "shoes"}
	if kind.begins_with("rest"):
		# позы «сидит» и «лежит»: rest1 — сидят, rest2 — лежат (сразу в позе), rest5 — лежат на двухъярусных койках;
		# rest3 — садятся и встают, rest4 — ложатся и встают, rest6 — то же на двухъярусных койках (для ролика: --shots=45-250 --fixed-dt=0.0333 и запуск с --fixed-fps 30)
		_open_street(g, p)
		var w := g.world
		var num := int(kind.substr(4)) if kind.length() > 4 else 1
		var scenes := {
			1: ["XX.h.jj.3.б.X.",
				"..............",
				"....hh..3.....",
				"....nn..2.....",
				"....hh........",
				".............."],
			2: ["жж.EE.цц.ж.ж..",
				".........ж.ж..",
				"..............",
				"..ее....лл....",
				".............."],
			3: ["...XX.h.j.3...",
				"..............",
				".............."],
			4: [".ж..EE..ее....",
				".ж............",
				"..............",
				".............."],
			5: [".bb...bb...bb.",
				"..............",
				".............."],
			6: ["...bb....bb...",
				"..............",
				".............."]}
		# rest7 — мебель мэрии: кресла ожидания, кресло мэра у стола, скамьи для публики перед столом совета
		var mc := GameWorld.MAP_CHARS
		var wc: String = mc[GameWorld.WAITCHAIRS]
		var pw: String = mc[GameWorld.PEW]
		var ds: String = mc[GameWorld.DAIS]
		scenes[7] = [wc + wc + wc + "...........",
			"..............",
			"....." + mc[GameWorld.EXECCHAIR] + "...." + mc[GameWorld.OFFICECHAIR] + "...",
			"...." + mc[GameWorld.MAYORDESK] + mc[GameWorld.MAYORDESK] + "..." + ds + ds + ds + "..",
			"..............",
			"........." + pw + pw + pw + "..",
			".............."]
		# кто где: [x клетки, ряд, номер места, пол, одежда, секунда «сесть», секунда «встать» (0 — не встаёт)]
		var casts := {
			1: [[0, 0, 0, "m", 0, 0, 0], [0, 0, 1, "f", 1, 0, 0], [3, 0, 0, "m", 2, 0, 0], [3, 0, 1, "f", 3, 0, 0], [5, 0, 1, "m", 4, 0, 0],
				[8, 0, 0, "f", 5, 0, 0], [10, 0, 0, "m", 6, 0, 0], [12, 0, 0, "f", 7, 0, 0], [4, 2, 0, "m", 3, 0, 0], [5, 2, 1, "f", 0, 0, 0],
				[4, 4, 1, "f", 2, 0, 0], [5, 4, 0, "m", 1, 0, 0], [8, 2, 0, "m", 5, 0, 0]],
			2: [[0, 0, 0, "m", 6, 0, 0], [3, 0, 0, "m", 4, 0, 0], [6, 0, 0, "f", 7, 0, 0], [9, 0, 0, "f", 1, 0, 0], [11, 0, 0, "m", 2, 0, 0],
				[2, 3, 0, "m", 0, 0, 0], [8, 3, 0, "f", 3, 0, 0]],
			3: [[3, 0, 0, "m", 0, 1.9, 6.2], [3, 0, 1, "f", 1, 2.5, 6.6], [6, 0, 0, "m", 2, 2.2, 6.9], [8, 0, 1, "f", 3, 2.8, 6.4], [10, 0, 0, "m", 5, 2.4, 6.7]],
			4: [[1, 0, 0, "m", 6, 1.9, 7.4], [4, 0, 0, "f", 7, 2.3, 7.9], [8, 0, 0, "m", 4, 2.7, 7.6]],
			5: [[1, 0, 0, "m", 4, 0, 0], [1, 0, 1, "m", 2, 0, 0], [6, 0, 0, "f", 3, 0, 0], [6, 0, 1, "m", 6, 0, 0], [11, 0, 1, "f", 3, 0, 0]],
			6: [[3, 0, 0, "m", 4, 1.9, 9.6], [3, 0, 1, "m", 2, 2.3, 10.4], [9, 0, 1, "f", 3, 2.0, 10.0], [9, 0, 0, "m", 6, 3.4, 9.2]],
			7: [[0, 0, 0, "m", 0, 0, 0], [0, 0, 1, "f", 1, 0, 0], [2, 0, 0, "m", 2, 0, 0], [5, 2, 0, "m", 5, 0, 0], [10, 2, 0, "f", 7, 0, 0],
				[9, 5, 0, "f", 3, 0, 0], [10, 5, 1, "m", 4, 0, 0], [11, 5, 0, "m", 6, 0, 0]]}
		var wears := [{"torso": "shirt", "legs": "pants", "feet": "shoes"}, {"torso": "dress_red", "feet": "shoes"},
			{"torso": "hoodie", "legs": "jeans", "feet": "sneakers"}, {"torso": "tshirt_navy", "legs": "jeans", "feet": "hiking_boots"},
			{"torso": "work_vest", "legs": "work_pants", "feet": "boots"}, {"torso": "suit_jacket", "legs": "pants", "feet": "shoes"},
			{"torso": "tshirt_navy", "legs": "shorts", "feet": "sneakers"}, {"torso": "dress_black", "feet": "high_boots"}]
		var rows: Array = scenes.get(num, scenes[1])
		var cols := 14
		var x0 := int(p.pos.x) - cols / 2
		var y0 := int(p.pos.y) - 4
		for i in range(-1, cols + 1):
			w.set_t(x0 + i, y0, GameWorld.WALL)
			for dy in range(1, 10):
				w.set_t(x0 + i, y0 + dy, GameWorld.TILEFLOOR)
		for r in rows.size():
			for i in rows[r].length():
				if rows[r][i] != ".":
					w.set_t(x0 + i, y0 + 1 + r, GameWorld.MAP_CHARS.find(rows[r][i]))
		var keep := []
		for e in w.props:
			if absf(e[1] - (x0 + cols / 2)) > 14 or absf(e[2] - (y0 + 4)) > 10:
				keep.append(e)
		w.props = keep
		w.index_props()
		w.compute_buildings()
		p.pos = Vector2(x0 + cols * 0.5, y0 + 8.4)     # сам игрок — в стороне, за кадром
		p.rpos = p.pos
		p.face = Vector2(0, -1)
		p.wear = {"torso": "shirt", "legs": "pants", "feet": "shoes"}
		rest_plan = []
		var cast: Array = casts.get(num, casts[1])
		for k in cast.size():
			var a: Array = cast[k]
			var q := GameState.Player.new(k + 1)
			q.pos = Vector2(x0 + a[0] + 0.5, y0 + 1 + a[1] + 1.5)
			q.rpos = q.pos
			q.face = Vector2(0, 1)
			q.look = GameState.default_look(k + 1, a[3])
			q.wear = wears[a[4]]
			q.name = ""
			g.players.append(q)
			rest_plan.append([float(a[5]), q.id, x0 + a[0], y0 + 1 + a[1], a[2]])
			if float(a[6]) > 0.0:
				rest_plan.append([float(a[6]), q.id, x0 + a[0], y0 + 1 + a[1], -1])
		rest_plan.sort_custom(func(u, v): return u[0] < v[0])
	if kind == "menu" or kind == "stats":
		# пример статистики для снимка: 1 уровень, 1 из 4 очков, сегодня 2 ч 33 мин и 7 мин АФК
		p.level = 1
		p.exp = 1
		p.reg = "2026-11-04"
		p.day = floori(g.time / 1440.0)
		p.day_play = 2 * 3600 + 33 * 60
		p.day_afk = 7 * 60
		p.hour_play = 14 * 60
	if kind == "chat" or kind == "chatlog":
		var q1: GameState.Player = g.players[1]
		var q3: GameState.Player = g.players[3]
		var said := [[q1, "Привет! Не подскажешь, где мэрия?"], [p, "Прямо по Мейн-стрит, там площадь"],
			[q1, "Спасибо, а автовокзал далеко?"], [q3, "Нет, к югу от центра, рядом с больницей. Пойдём, покажу"]]
		g.chat[p.id] = []
		for e in said:
			g.chat[p.id].append([e[0].id, e[1], "%s говорит: %s" % [GameState.tag(e[0]), e[1]]])
	if kind == "rp" or kind == "rpopen":
		# ролевые команды (0.56) — строки собирает тот же код, что на сервере (chat_parse)
		var q1: GameState.Player = g.players[1]
		var q3: GameState.Player = g.players[3]
		var said := [[q1, "Есть закурить?", ""], [p, "/me достал из кармана пачку сигарет", ""],
			[q3, "/do В руке зажигалка Zippo.", ""], [q3, "/todo Держи, прикуривай*протягивая зажигалку", ""],
			[p, "/try прикурить на ветру", "try0"], [p, "/try прикурить, прикрыв огонь ладонью", "try1"]]
		g.chat[p.id] = []
		for e in said:
			var r := g.chat_parse(e[0], e[1])
			while e[2] != "" and r["k"] != e[2]:     # для снимка — нужный итог броска
				r = g.chat_parse(e[0], e[1])
			g.chat[p.id].append([e[0].id, r["bub"], r["line"], r["k"]])
	if kind == "chatlog":
		p.hour_play = 25 * 60      # настоящий PayDay — плашка, как в игре
		g.payday()
	if kind == "inv":
		for id in ["canned", "water", "pistol", "ammo", "apple", "chips", "medkit"]:
			Items.add_to(p.inv, id, 12 if id == "ammo" else 2)
	return g

static func _into_house(g: GameState, p: GameState.Player) -> void:
	var w := g.world
	var best := -1
	var bd := 1e9
	for y in range(1, w.h - 1):
		for x in range(1, w.w - 1):
			if w.t(x, y) != GameWorld.TILEFLOOR:
				continue
			var furn := false
			for k in 4:
				if GameWorld.is_furniture(w.t(x + GameWorld.DX4[k], y + GameWorld.DY4[k])):
					furn = true
			if not furn:
				continue
			var d := Vector2(x, y).distance_to(p.pos)
			if d < bd:
				bd = d
				best = w.idx(x, y)
	if best >= 0:
		p.pos = Vector2(best % w.w + 0.5, best / w.w + 0.5)
		p.rpos = p.pos

## Открытое место на улице, чтобы ничего не заслоняло
static func _open_street(g: GameState, p: GameState.Player) -> void:
	var w := g.world
	var best := Vector2.ZERO
	var bd := 1e9
	for y in range(6, w.h - 6):
		for x in range(6, w.w - 6):
			var free := true
			for yy in range(y - 3, y + 4):
				for xx in range(x - 3, x + 4):
					if w.solid(xx, yy) or w._is_building_tile(w.t(xx, yy)):
						free = false
						break
				if not free:
					break
			if free:
				var d := Vector2(x, y).distance_to(p.pos)
				if d < bd:
					bd = d
					best = Vector2(x + 0.5, y + 0.5)
	if bd < 1e9:
		p.pos = best
		p.rpos = best
