extends Node
## Запуск: отдельный проект Godot, в нём m/men/*.gltf и m/women/*.gltf из архивов Quaternius (Individual Characters/glTF);
## сцена с этим скриптом → godot --headless --path <проект> res://extract.tscn. OUT — папка assets/chars репозитория.
## Извлекает из glTF Quaternius (CC0) скелет с нужными анимациями и части одежды для игры
const KEEP := ["Idle", "Walk", "Run", "Punch_Right", "Punch_Left", "Kick_Right", "Death", "HitRecieve", "Sword_Slash", "Gun_Shoot", "Idle_Gun_Pointing", "Interact", "Wave"]
const OUT := "/home/claude/umwelt-rp/assets/chars/"
const PARTS := {
	"m": {
		"Casual_2": ["Casual2_Head", "Casual2_Body", "Casual2_Legs", "Casual2_Feet"],
		"Casual_Hoodie": ["Casual_Head", "Casual_Body", "Casual_Legs"],
		"Suit": ["Suit_Head", "Suit_Body", "Suit_Legs", "Suit_Feet", "Pistol"],
		"Worker": ["Worker_Body", "Worker_Legs", "Worker_Feet"],
		"Punk": ["Punk_Head", "Punk_Body"],
		"Beach": ["Beach_Head", "Beach_Body", "Beach_Legs", "Beach_Feet"],
		"Adventurer": ["Adventurer_Head", "Adventurer_Body"],
	},
	"f": {
		"Casual": ["Casual_Head", "Casual_Body", "Casual_Legs", "Casual_Feet"],
		"Formal": ["Formad_Head", "Formal_Body", "Formal_Legs", "Formal_Feet"],
		"Suit": ["Suit_Head", "Suit_Body", "Suit_Legs"],
		"Worker": ["Worker_Body", "Worker_Legs", "Worker_Feet"],
		"Punk": ["Punk_Head", "Punk_Body", "Punk_Legs"],
		"Adventurer": ["Adventurer_Head", "Adventurer_Body", "Adventurer_Legs"],
	},
}

func _own(n: Node, owner: Node) -> void:
	for c in n.get_children():
		c.owner = owner
		_own(c, owner)

func _ready() -> void:
	for g in PARTS:
		var dir := "res://m/%s/" % ("men" if g == "m" else "women")
		var base_done := false
		for file in PARTS[g]:
			var root: Node3D = load(dir + file + ".gltf").instantiate()
			var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
			for pn in PARTS[g][file]:
				var mi: MeshInstance3D = sk.find_child(pn, false, false)
				var part := MeshInstance3D.new()
				part.name = pn
				part.mesh = mi.mesh
				part.skin = mi.skin
				var ps := PackedScene.new()
				ps.pack(part)
				var e := ResourceSaver.save(ps, OUT + "%s/%s.scn" % [g, pn], ResourceSaver.FLAG_COMPRESS)
				print(g, "/", pn, " ", e)
			if not base_done:
				base_done = true
				for c in sk.get_children():
					sk.remove_child(c)
					c.free()
				var ap: AnimationPlayer = root.find_child("AnimationPlayer", true, false)
				var lib := AnimationLibrary.new()
				for a in KEEP:
					var an: Animation = ap.get_animation(a)
					if an == null:
						print("нет анимации ", a)
						continue
					lib.add_animation(a, an)
				for ln in ap.get_animation_library_list():
					ap.remove_animation_library(ln)
				ap.add_animation_library("", lib)
				root.name = "Char_" + g
				_own(root, root)
				var ps2 := PackedScene.new()
				ps2.pack(root)
				print(g, " base ", ResourceSaver.save(ps2, OUT + "%s_base.scn" % g, ResourceSaver.FLAG_COMPRESS))
	get_tree().quit()
