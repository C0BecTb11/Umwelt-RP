class_name CharModel
extends Node3D
## Человек: модель Quaternius (CC0, assets/chars) — скелет с анимациями и части одежды на нём.
## Части (голова, верх, низ, обувь) — отдельные меши на одном скелете: одежда меняется заменой части.

const DIR := "res://assets/chars/"
const TONES := [1.0, 0.86, 0.64, 0.44]       # множитель цвета кожи по look.sk
const ATTACKS := {"fists": ["Punch_Right", "Punch_Left"], "melee": ["Sword_Slash"], "gun": ["Gun_Shoot"], "kick": ["Kick_Right"]}

static var _scenes := {}
static var _tone_mats := {}
static var _weapon_cache := {}
static var _mat: StandardMaterial3D

var root: Node3D
var skel: Skeleton3D
var ap: AnimationPlayer
var gender := "m"
var tone := 0
var look_key := ""
var parts := {}               # слот → [ключ части, MeshInstance3D]
var hair := ""                # причёска из внешности (видна, когда на голове ничего нет)
var weapon_mi: MeshInstance3D
var cur_weapon := ""
var fall := -1.0              # 0..1 — без сознания (0 стоит, 1 лежит); -1 — брать из lying
var atk_kind := 0             # 1 — добивание ногой
var speed := 0.0              # скорость на экране, м/с (из world_view) — для темпа ходьбы и бега
var cur := ""
var attacking := false
var last_attack := 0.0
var punch_i := 0
var fresh := true
# Удар на ходу (с 0.51, BF-067): ноги идут своей анимацией (ходьба/бег), удар — только верх тела (от живота
# вверх) поверх неё. Удар стоя — вся анимация целиком, как раньше; пошёл посреди удара — верх доигрывает поверх ходьбы
const UPPER_FROM := "Abdomen"       # эта кость и все ниже по скелету (спина, руки, голова) — «верх»
const LAYER_IN := 0.08              # с, плавный вход удара поверх ходьбы
const LAYER_OUT := 0.12             # с, плавный выход в конце
const ATK_SPEED := 1.25             # удары играются чуть быстрее записи (как было)
static var _upper_tracks := {}      # "пол|анимация" → [[номер дорожки поворота, номер кости], …]
var layer_anim := ""                # удар поверх ходьбы: имя анимации, "" — нет
var layer_t := 0.0
var _last_ms := -1

static func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]

func setup(look: Dictionary) -> void:
	gender = str(look.get("g", "m"))
	if gender != "f":
		gender = "m"
	tone = clampi(int(look.get("sk", 0)), 0, TONES.size() - 1)
	look_key = str(look)
	root = _scene(DIR + gender + "_base.scn").instantiate()
	add_child(root)
	skel = root.find_children("*", "Skeleton3D", true, false)[0]
	ap = root.find_child("AnimationPlayer", true, false)
	for a in ["Idle", "Walk", "Run", "Idle_Gun_Pointing"]:
		if ap.has_animation(a):
			ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var head := str(look.get("h", ""))
	hair = head if head in Items.HEADS[gender] else Items.HEADS[gender][0]
	set_wear({})
	_play("Idle", 0.0)
	ap.mixer_applied.connect(_apply_layer)

func _set_part(slot: String, pname: String, tint: Array = []) -> void:
	var key := pname + (("|%s|%s" % [tint[0], (tint[1] as Color).to_html()]) if tint.size() == 2 else "")
	if parts.has(slot) and parts[slot][0] == key:
		return
	if parts.has(slot):
		parts[slot][1].queue_free()
		parts.erase(slot)
	if pname == "":
		return
	var path := DIR + gender + "/" + pname + ".scn"
	if not ResourceLoader.exists(path):
		return
	var mi: MeshInstance3D = _scene(path).instantiate()
	skel.add_child(mi)
	mi.skeleton = NodePath("..")
	_apply_tone(mi)
	if tint.size() == 2:
		_apply_tint(mi, tint[0], tint[1])
	parts[slot] = [key, mi]

## Цветной вариант вещи: перекрашиваем главный материал части
func _apply_tint(mi: MeshInstance3D, mat_name: String, col: Color) -> void:
	for s in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(s)
		if m is StandardMaterial3D and String(m.resource_name) == mat_name:
			var key := "t|%s|%s|%s" % [mat_name, col.to_html(), (m as StandardMaterial3D).albedo_color.to_html()]
			if not _tone_mats.has(key):
				var nm: StandardMaterial3D = m.duplicate()
				nm.albedo_color = col
				_tone_mats[key] = nm
			mi.set_surface_override_material(s, _tone_mats[key])

## Тон кожи: заменяем только материалы кожи, одежда остаётся своего цвета
func _apply_tone(mi: MeshInstance3D) -> void:
	if tone == 0:
		return
	for s in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(s)
		if m is StandardMaterial3D and String(m.resource_name).begins_with("Skin"):
			var key := "%d|%s|%s" % [tone, m.resource_name, (m as StandardMaterial3D).albedo_color.to_html()]
			if not _tone_mats.has(key):
				var nm: StandardMaterial3D = m.duplicate()
				var c: Color = nm.albedo_color
				var k: float = TONES[tone]
				nm.albedo_color = Color(c.r * k, c.g * k, c.b * k, c.a)
				_tone_mats[key] = nm
			mi.set_surface_override_material(s, _tone_mats[key])

## Показать надетое: в каждом слоте — часть модели вещи или «без одежды»
func set_wear(wear: Dictionary) -> void:
	if skel == null:
		return
	for sl in Items.SLOTS:
		var pn := Items.part_for(wear, gender, sl)
		if sl == "head" and pn == "":
			pn = hair
		_set_part(sl, pn, Items.tint_for(wear, gender, sl))

static func _materials() -> void:
	if _mat != null:
		return
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.vertex_color_is_srgb = true
	_mat.roughness = 0.85

static func _weapon_mesh(id: String) -> ArrayMesh:
	if _weapon_cache.has(id):
		return _weapon_cache[id]
	var m := Mesher.new()
	var d := Items.def(id)
	var col: Color = d["color"]
	m.translate(Vector3(0, -0.05, 0))
	if d["kind"] == Items.Kind.GUN:
		m.box(Vector3(0, -0.02, 0.04), Vector3(0.045, 0.1, 0.06), Color8(0x26, 0x26, 0x2A))
		m.box(Vector3(0, 0.03, 0.1), Vector3(0.05, 0.06, 0.2), Color8(0x2E, 0x2E, 0x34))
	else:
		var length: float = 0.25 + d["range"] * 0.45
		match id:
			"bat":
				m.translate(Vector3(0, 0, -0.04))
				m.rot_x(90)
				m.tube(0, length, 0.022, 0.045, col, 8)
				m.tube(-0.05, 0, 0.025, 0.022, Color8(0x2A, 0x2A, 0x2A), 6)
			"knife":
				m.box(Vector3(0, 0, 0.04), Vector3(0.03, 0.03, 0.1), Color8(0x1E, 0x1E, 0x1E))
				m.box(Vector3(0, 0, 0.17), Vector3(0.01, 0.04, 0.16), col)
			"hammer":
				m.box(Vector3(0, 0, length / 2 - 0.05), Vector3(0.035, 0.035, length), Color8(0x9A, 0x6A, 0x3A))
				m.box(Vector3(0, 0, length - 0.06), Vector3(0.06, 0.16, 0.06), Color8(0x7A, 0x7E, 0x86))
			"crowbar":
				m.box(Vector3(0, 0, length / 2 - 0.05), Vector3(0.03, 0.03, length), col)
				m.box(Vector3(0, 0.05, length - 0.07), Vector3(0.03, 0.12, 0.03), col)
			_:
				m.box(Vector3(0, 0, length / 2 - 0.05), Vector3(0.04, 0.04, length), col)
	var mesh := m.commit()
	_weapon_cache[id] = mesh
	return mesh

## Оружие в руке: пистолет — часть модели (привязан к кисти), холодное — простая модель на кости кисти
func _set_weapon(id: String) -> void:
	if id == cur_weapon:
		return
	cur_weapon = id
	_set_part("gun", "Pistol" if id == "pistol" else "")
	if weapon_mi != null:
		weapon_mi.get_parent().queue_free()
		weapon_mi = null
	var d := Items.def(id)
	if id == "" or id == "fists" or id == "pistol" or d["kind"] != Items.Kind.MELEE:
		return
	_materials()
	var ba := BoneAttachment3D.new()
	ba.bone_name = "Wrist.R"
	skel.add_child(ba)
	weapon_mi = MeshInstance3D.new()
	weapon_mi.mesh = _weapon_mesh(id)
	weapon_mi.material_override = _mat
	# кость кисти в позе привязки: рука в сторону (−X), ладонь вниз; рукоять в кулаке, оружие смотрит вперёд (+Z)
	var bind := Transform3D()
	var sk: Skin = parts["torso"][1].skin if parts.has("torso") else null
	if sk != null:
		for i in sk.get_bind_count():
			if String(sk.get_bind_name(i)) == "Wrist.R":
				bind = sk.get_bind_pose(i)
	var grip := bind.affine_inverse().origin + Vector3(-0.09, -0.02, 0.0)
	weapon_mi.transform = bind * Transform3D(Basis(), grip)
	ba.add_child(weapon_mi)

func _play(a: String, blend: float = 0.2, from_start: bool = false) -> void:
	if ap == null or not ap.has_animation(a):
		return
	if cur != a or from_start:
		ap.play(a, blend)
		if from_start:
			ap.seek(0.0, true)
		cur = a

## Дорожки поворота костей верха тела в анимации (кэш на пол и анимацию)
func _upper(a: String) -> Array:
	var key := gender + "|" + a
	if _upper_tracks.has(key):
		return _upper_tracks[key]
	var out := []
	var anim := ap.get_animation(a)
	var top := skel.find_bone(UPPER_FROM)
	if anim != null and top >= 0:
		for t in anim.get_track_count():
			if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				continue
			var b := skel.find_bone(String(anim.track_get_path(t).get_concatenated_subnames()))
			var k := b
			while k >= 0 and k != top:
				k = skel.get_bone_parent(k)
			if b >= 0 and k == top:
				out.append([t, b])
	_upper_tracks[key] = out
	return out

## Вес удара поверх ходьбы в момент t (плавно входит и выходит)
func layer_weight(t: float, length: float) -> float:
	return clampf(minf(t / LAYER_IN, (length - t) / LAYER_OUT), 0.0, 1.0)

## После того как анимация ног и тела легла на скелет — повернуть кости верха по удару
func _apply_layer() -> void:
	if layer_anim == "":
		return
	var anim := ap.get_animation(layer_anim)
	var w := layer_weight(layer_t, anim.length)
	for tb in _upper(layer_anim):
		var q := anim.rotation_track_interpolate(tb[0], layer_t)
		skel.set_bone_pose_rotation(tb[1], skel.get_bone_pose_rotation(tb[1]).slerp(q, w))

## Поза на кадр: выбор анимации по движению, удару, оружию и потере сознания
func pose(_phase: float, moving: float, attack: float, weapon_id: String, lying: bool, sneak: bool) -> void:
	if ap == null:
		return
	var now := Time.get_ticks_msec()
	var dt := 0.0 if _last_ms < 0 else minf((now - _last_ms) / 1000.0, 0.1)
	_last_ms = now
	pose_dt(dt, moving, attack, weapon_id, lying, sneak)

## То же с явным шагом времени (проверки зовут напрямую)
func pose_dt(dt: float, moving: float, attack: float, weapon_id: String, lying: bool, sneak: bool) -> void:
	_set_weapon(weapon_id)
	var walking := moving > 0.05 and speed > 0.15
	if layer_anim != "":
		layer_t += dt * ATK_SPEED
		if layer_t >= ap.get_animation(layer_anim).length:
			layer_anim = ""
	var ly := fall if fall >= 0.0 else (1.0 if lying else 0.0)
	# без сознания: падает и лежит
	if ly > 0.01:
		attacking = false
		layer_anim = ""
		if cur != "Death":
			_play("Death", 0.12, true)
			if fresh and ly >= 0.999:
				ap.seek(ap.current_animation_length, true)     # уже лежал, когда мы его увидели
		ap.speed_scale = 1.0
		fresh = false
		return
	fresh = false
	# удар: новый замах — анимация с начала, доигрывает до конца
	if attack > last_attack + 0.25:
		var d := Items.def(weapon_id)
		var kind := "fists"
		if atk_kind == 1:
			kind = "kick"
		elif weapon_id == "pistol" or d["kind"] == Items.Kind.GUN:
			kind = "gun"
		elif weapon_id != "fists" and weapon_id != "":
			kind = "melee"
		var list: Array = ATTACKS[kind]
		punch_i += 1
		var a: String = list[punch_i % list.size()]
		if walking and kind != "kick":
			layer_anim = a              # на ходу: ноги продолжают идти, удар — верхом тела
			layer_t = 0.0
			attacking = false
		else:
			layer_anim = ""
			_play(a, 0.06, true)
			attacking = true
	last_attack = attack
	if attacking and ap.is_playing() and ap.current_animation == cur:
		if walking and atk_kind != 1 and cur != "Kick_Right":
			layer_anim = cur            # пошёл посреди удара стоя: удар доигрывает верхом, ноги — шагают
			layer_t = ap.current_animation_position
			attacking = false
		else:
			ap.speed_scale = ATK_SPEED
			return
	attacking = false
	if walking:
		if speed > 3.0 and not sneak:
			_play("Run", 0.18)
			ap.speed_scale = clampf(speed / 4.2, 0.6, 1.4)
		else:
			_play("Walk", 0.2)
			ap.speed_scale = clampf(speed / (1.6 if gender == "m" else 1.5), 0.45, 1.6)
	else:
		_play("Idle_Gun_Pointing" if weapon_id == "pistol" else "Idle", 0.25)
		ap.speed_scale = 1.0
