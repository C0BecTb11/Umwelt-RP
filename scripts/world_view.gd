class_name WorldView
extends Node3D
## 3D-представление игры: строит город, ставит камеру и свет, анимирует людей и эффекты.

const W = preload("res://scripts/world.gd")

var world: GameWorld
var wm: WorldMesh
var mat_world: ShaderMaterial
var mat_fx: StandardMaterial3D
var mat_glow: StandardMaterial3D
var mesher := Mesher.new()

var chunk_nodes: Array = []
var chunk_dirty := PackedByteArray()
var roof_nodes: Array = []
var door_nodes := {}          # клетка → MeshInstance3D
var door_angle := {}
var door_mesh: ArrayMesh
var players := {}             # id → CharModel
var pfall := {}                # id игрока → 0..1 насколько упал (без сознания)
var walk := {}                # id → [фаза, x, y, скорость]

var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var lamp_lights: Array = []
var flash_light: OmniLight3D
var target_node: MeshInstance3D
var shot_nodes: Array = []

var inside_building := -1

var particles: Array = []     # [pos, vel, life, max, color, size]
var pm: MultiMeshInstance3D
var blood: Array = []         # [x, y(высота), z, rot, size]
var bm: MultiMeshInstance3D
var blood_dirty := false
var flashes: Array = []       # [x, z, life]

var cam_yaw := 35.0
var cam_d := 15.5            # расстояние камеры (для демо-снимков крупным планом)
var cam_x := NAN
var cam_z := 0.0
var shake := 0.0
var hurt_flash := 0.0
var vibrate := 0
var target := -1

func setup(w: GameWorld) -> void:
	world = w
	wm = WorldMesh.new(w)
	mat_world = ShaderMaterial.new()
	mat_world.shader = load("res://shaders/world.gdshader")
	mat_fx = StandardMaterial3D.new()
	mat_fx.vertex_color_use_as_albedo = true
	mat_fx.vertex_color_is_srgb = true
	mat_glow = StandardMaterial3D.new()
	mat_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_glow.albedo_color = Color(1.0, 0.92, 0.55)
	# окружение
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_density = 0.012
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 34.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.0
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 32.0
	cam.near = 1.0
	cam.far = 140.0
	add_child(cam)
	cam.make_current()
	for i in 6:
		var o := OmniLight3D.new()
		o.omni_range = 7.5
		o.light_color = Color(1.0, 0.72, 0.42)
		o.visible = false
		add_child(o)
		lamp_lights.append(o)
	flash_light = OmniLight3D.new()
	flash_light.omni_range = 7.0
	flash_light.light_color = Color(1.0, 0.8, 0.45)
	flash_light.light_energy = 2.5
	flash_light.visible = false
	add_child(flash_light)
	# чанки
	for i in wm.chunks_x * wm.chunks_y:
		var n := MeshInstance3D.new()
		n.material_override = mat_world
		add_child(n)
		chunk_nodes.append(n)
	chunk_dirty.resize(chunk_nodes.size())
	chunk_dirty.fill(1)
	# крыши
	for bi in w.buildings.size():
		wm.build_roof(mesher, bi)
		var r := MeshInstance3D.new()
		r.mesh = mesher.commit()
		r.material_override = mat_world
		add_child(r)
		roof_nodes.append(r)
	# двери
	WorldMesh.build_door(mesher)
	door_mesh = mesher.commit()
	for i in w.tiles.size():
		var tt := w.t_at(i)
		if tt == W.DOOR or tt == W.DOOR_OPEN:
			_make_door(i)
	# частицы и кровь
	pm = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = 500
	mm.visible_instance_count = 0
	pm.multimesh = mm
	pm.material_override = mat_fx
	pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pm)
	bm = MultiMeshInstance3D.new()
	var mb := MultiMesh.new()
	mb.transform_format = MultiMesh.TRANSFORM_3D
	mb.use_colors = true
	var bq := BoxMesh.new()
	bq.size = Vector3(1, 0.004, 0.75)
	mb.mesh = bq
	mb.instance_count = 240
	mb.visible_instance_count = 0
	bm.multimesh = mb
	bm.material_override = mat_fx
	bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bm)
	# подсветка цели
	target_node = MeshInstance3D.new()
	mesher.clear()
	var th := 0.05
	var fc := Color(1, 1, 1)
	mesher.aabb(0.05, 0, 0.05, 0.95, 0.03, 0.05 + th, fc)
	mesher.aabb(0.05, 0, 0.95 - th, 0.95, 0.03, 0.95, fc)
	mesher.aabb(0.05, 0, 0.05, 0.05 + th, 0.03, 0.95, fc)
	mesher.aabb(0.95 - th, 0, 0.05, 0.95, 0.03, 0.95, fc)
	target_node.mesh = mesher.commit()
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	target_node.material_override = tm
	target_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(target_node)
	for i in 4:
		var s := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.03, 0.03, 1.0)
		s.mesh = sm
		s.material_override = mat_glow
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.visible = false
		add_child(s)
		shot_nodes.append(s)

func _make_door(i: int) -> void:
	var n := MeshInstance3D.new()
	n.mesh = door_mesh
	n.material_override = mat_world
	var x := i % world.w
	var y := i / world.w
	if world.along_y(x, y):
		n.position = Vector3(x + 0.08, 0.1, y + 0.5)
		n.set_meta("base", 0.0)
	else:
		n.position = Vector3(x + 0.5, 0.1, y + 0.08)
		n.set_meta("base", -90.0)
	add_child(n)
	door_nodes[i] = n

func _mark_dirty(i: int) -> void:
	var x := i % world.w
	var y := i / world.w
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + d.x
		var ny: int = y + d.y
		if not world.inside(nx, ny):
			continue
		chunk_dirty[(ny / WorldMesh.CHUNK) * wm.chunks_x + nx / WorldMesh.CHUNK] = 1

# ================== ОБНОВЛЕНИЕ ==================
func update(dt: float, g: GameState, me: GameState.Player, local_pid: int) -> void:
	for i in world.vis_dirty:
		_mark_dirty(i)
	world.vis_dirty.clear()
	for ev in world.events:
		_on_tile_event(ev[0], ev[1], ev[2])
	world.events.clear()
	for f in g.fx:
		_on_fx(f, local_pid, me)
	g.fx.clear()
	# перестройка чанков: сначала ближайшие к игроку; вблизи — сразу, дальше — по 2 за кадр
	var pcx := clampi(floori(me.rpos.x) / WorldMesh.CHUNK, 0, wm.chunks_x - 1)
	var pcy := clampi(floori(me.rpos.y) / WorldMesh.CHUNK, 0, wm.chunks_y - 1)
	var order: Array = []
	for ci in chunk_dirty.size():
		if chunk_dirty[ci] == 1:
			var d := maxi(absi(ci % wm.chunks_x - pcx), absi(ci / wm.chunks_x - pcy))
			order.append([d, ci])
	order.sort_custom(func(a, b): return a[0] < b[0])
	var built := 0
	for o in order:
		if o[0] > 1 and built >= 2:
			break
		var ci2: int = o[1]
		wm.build_chunk(mesher, ci2 % wm.chunks_x, ci2 / wm.chunks_x)
		chunk_nodes[ci2].mesh = mesher.commit()
		chunk_dirty[ci2] = 0
		built += 1
	# двери
	for k in door_angle.keys():
		var tt := world.t_at(k)
		var tgt := 90.0 if tt == W.DOOR_OPEN else 0.0
		if tt != W.DOOR and tt != W.DOOR_OPEN:
			door_angle.erase(k)
			continue
		var v: float = door_angle[k]
		var step := dt * 400.0
		if absf(tgt - v) <= step:
			door_angle.erase(k)
		else:
			door_angle[k] = v + (step if tgt > v else -step)
	for k in door_nodes:
		var n: MeshInstance3D = door_nodes[k]
		var tt2 := world.t_at(k)
		n.visible = tt2 == W.DOOR or tt2 == W.DOOR_OPEN
		var ang: float = door_angle.get(k, 90.0 if tt2 == W.DOOR_OPEN else 0.0)
		n.rotation.y = deg_to_rad(n.get_meta("base") + ang)
	# частицы
	var i := particles.size() - 1
	while i >= 0:
		var p: Array = particles[i]
		p[2] -= dt
		if p[2] <= 0.0:
			particles.remove_at(i)
		else:
			p[0] += p[1] * dt
			p[1].y -= 9.0 * dt
			if p[0].y < 0.12:
				p[0].y = 0.12
				p[1] = Vector3(p[1].x * 0.6, 0, p[1].z * 0.6)
		i -= 1
	var j := flashes.size() - 1
	while j >= 0:
		flashes[j][2] -= dt
		if flashes[j][2] <= 0.0:
			flashes.remove_at(j)
		j -= 1
	var px := floori(me.rpos.x)
	var py := floori(me.rpos.y)
	var cpx := clampi(px, 0, world.w - 1)
	var cpy := clampi(py, 0, world.h - 1)
	var b: int = world.building_of[world.idx(cpx, cpy)]
	inside_building = b if (b >= 0 and world.t(cpx, cpy) != W.WALL) else -1
	# камера
	var tx := me.rpos.x + me.face.x * 0.6
	var tz := me.rpos.y + me.face.y * 0.6
	if is_nan(cam_x) or Vector2(tx - cam_x, tz - cam_z).length() > 6.0:
		cam_x = tx
		cam_z = tz
	var ck := minf(1.0, dt * 5.0)
	cam_x += (tx - cam_x) * ck
	cam_z += (tz - cam_z) * ck
	shake = maxf(0.0, shake - dt * 2.5)
	hurt_flash = maxf(0.0, hurt_flash - dt * 1.4)
	for p: GameState.Player in g.players:
		_walk_update(p.id, p.rpos, dt)
	if walk.size() > 600:
		walk.clear()
	_place_scene(g, me, dt)

func _walk_update(id: int, pos: Vector2, dt: float) -> void:
	if not walk.has(id):
		walk[id] = [randf() * 6.0, pos, 0.0]
	var st: Array = walk[id]
	if st.size() < 4:
		st.append(0.0)
	var d: float = pos.distance_to(st[1])
	if d < 1.0:
		st[0] += d * 6.5
	st[2] = st[2] * 0.85 + (d / dt if dt > 0.0 else 0.0) * 0.15
	st[1] = pos
	# сила шага плавно, без щелчка «идёт/стоит»
	var tgt := clampf((st[2] - 0.12) / 0.5, 0.0, 1.0)
	st[3] = move_toward(st[3], tgt, dt * 7.0)

func _on_tile_event(i: int, from: int, to: int) -> void:
	_mark_dirty(i)
	if (from == W.DOOR and to == W.DOOR_OPEN) or (from == W.DOOR_OPEN and to == W.DOOR):
		if not door_angle.has(i):
			door_angle[i] = 90.0 if from == W.DOOR_OPEN else 0.0
	if (to == W.DOOR or to == W.DOOR_OPEN) and not door_nodes.has(i):
		_make_door(i)

func _burst(at: Vector3, n: int, col: Color, size: float, speed: float, life: float, dir = null, spread: float = 0.9) -> void:
	for k in n:
		var a: float = randf() * TAU if dir == null else float(dir) + (randf() - 0.5) * 2.0 * spread
		var sp := speed * (0.3 + randf())
		particles.append([at, Vector3(cos(a) * sp, 1.0 + randf() * 2.5, sin(a) * sp), life * (0.6 + randf() * 0.6), life * 1.2, col, size * (0.6 + randf())])
	if particles.size() > 500:
		particles = particles.slice(particles.size() - 500)

func _ground_at(x: float, z: float) -> float:
	var tt := world.t(floori(x), floori(z))
	if tt == W.SIDEWALK:
		return 0.12
	if W.is_floor(tt) or W.is_door_like(tt) or W.is_window_like(tt):
		return 0.1
	return 0.0

func _add_blood(x: float, z: float, size: float) -> void:
	var bx := x + (randf() - 0.5) * 0.3
	var bz := z + (randf() - 0.5) * 0.3
	blood.append([bx, _ground_at(bx, bz) + 0.006 + randf() * 0.003, bz, randf() * TAU, size])
	if blood.size() > 220:
		blood.pop_front()
	blood_dirty = true

func _on_fx(f: Array, local_pid: int, me: GameState.Player) -> void:
	var x: float = f[1]
	var z: float = f[2]
	match int(f[0]):
		3:
			_burst(Vector3(x, 1.2, z), 10, Color(0.63, 0.08, 0.08), 0.04, 2.0, 0.6)
			if randf() < 0.6:
				_add_blood(x, z, 0.4)
			if int(f[3]) == local_pid:
				hurt_flash = 1.0
				shake = maxf(shake, 0.5)
				vibrate = 60
		4:
			flashes.append([x, z, 0.1])
			_burst(Vector3(x, 1.2, z), 5, Color(1.0, 0.88, 0.45), 0.025, 4.0, 0.2, atan2(me.face.y, me.face.x), 0.3)
			if int(f[3]) == local_pid:
				shake = maxf(shake, 0.35)
				vibrate = 25

# ================== РАССТАНОВКА ==================
func _place_scene(g: GameState, me: GameState.Player, dt: float) -> void:
	var dark := g.darkness()
	var hh := g.hour_f()
	# ---------- камера ----------
	var pitch := deg_to_rad(54.0)
	var yaw := deg_to_rad(cam_yaw)
	var D := cam_d
	var sh := shake * shake * 0.25
	var t := Vector3(cam_x + (randf() - 0.5) * sh, 0.6, cam_z + (randf() - 0.5) * sh)
	var eye := t + Vector3(sin(yaw) * cos(pitch) * D, sin(pitch) * D, cos(yaw) * cos(pitch) * D)
	cam.position = eye
	cam.look_at(t, Vector3.UP)
	# ---------- солнце, небо ----------
	var sd := Vector3(0.35, -0.85, -0.4)
	if hh >= 5.0 and hh <= 21.5:
		var az := PI * (hh - 5.0) / 16.5
		var el := maxf(0.0, sin(az))
		sd = Vector3(-cos(az) * 0.85, -(0.3 + 0.7 * el), -0.45)
	sd = sd.normalized()
	sun.look_at_from_position(t - sd * 40.0, t, Vector3.UP if absf(sd.y) < 0.99 else Vector3.FORWARD)
	var day_c := Color(1.0, 0.95, 0.86)
	var dusk_c := Color(1.0, 0.6, 0.36)
	var night_c := Color(0.42, 0.52, 0.85)
	var day_a := Color(0.56, 0.59, 0.66)
	var dusk_a := Color(0.34, 0.28, 0.33)
	var night_a := Color(0.2, 0.23, 0.33)
	var warm := 0.0
	if hh >= 5.0 and hh <= 21.5:
		var el2 := maxf(0.0, sin(PI * (hh - 5.0) / 16.5))
		warm = clampf(pow(1.0 - el2, 3.0), 0.0, 1.0) * 0.4
	var sc: Color
	var ac: Color
	if dark < 0.5:
		# закатный оттенок только у солнца, общий свет темнеет лишь с сумерками
		sc = day_c.lerp(dusk_c * 0.75, maxf(dark * 2.0, warm))
		ac = day_a.lerp(dusk_a, dark * 2.0)
	else:
		var k2 := (dark - 0.5) * 2.0
		sc = (dusk_c * 0.75).lerp(night_c * 0.45, k2)
		ac = dusk_a.lerp(night_a, k2)
	sun.light_color = Color(sc.r, sc.g, sc.b)
	sun.light_energy = 1.25 * (1.0 - dark * 0.5)
	env.ambient_light_color = Color(ac.r, ac.g, ac.b)
	env.ambient_light_energy = 1.0
	var fog := Color(0.6, 0.64, 0.66).lerp(Color(0.05, 0.065, 0.1), dark)
	env.background_color = fog
	env.fog_light_color = fog
	env.fog_density = 0.004 + dark * 0.008
	# ---------- шейдер мира ----------
	mat_world.set_shader_parameter("player_pos", Vector3(me.rpos.x, 1.0, me.rpos.y))
	mat_world.set_shader_parameter("cam_back", Vector2(sin(yaw), cos(yaw)))
	mat_world.set_shader_parameter("cut", 0.0 if me.dead else 1.0)
	mat_world.set_shader_parameter("night", dark)
	# ---------- фонари ----------
	var lk := smoothstep(0.15, 0.5, dark)
	var near_l: Array = []
	if lk > 0.01:
		for l in wm.lamps:
			if absf(l[2] - t.x) < 20.0 and absf(l[3] - t.z) < 20.0:
				near_l.append(l)
		near_l.sort_custom(func(a, b): return Vector2(a[2] - t.x, a[3] - t.z).length() < Vector2(b[2] - t.x, b[3] - t.z).length())
	# низкая графика: без теней от солнца и не больше 2 фонарей
	sun.shadow_enabled = not Profile.low_gfx
	var max_l := 2 if Profile.low_gfx else lamp_lights.size()
	for i in lamp_lights.size():
		var o: OmniLight3D = lamp_lights[i]
		if i < near_l.size() and i < max_l:
			o.visible = true
			o.position = Vector3(near_l[i][2], 2.7, near_l[i][3])
			o.light_energy = 0.9 * lk
		else:
			o.visible = false
	flash_light.visible = flashes.size() > 0
	if flash_light.visible:
		flash_light.position = Vector3(flashes[0][0], 1.3, flashes[0][1])
	# ---------- крыши ----------
	for bi in roof_nodes.size():
		# крыша над игроком не видна, но тень от неё остаётся — в доме тень, как под настоящей крышей
		roof_nodes[bi].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if bi == inside_building else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# ---------- игроки ----------
	var alive := {}
	for p: GameState.Player in g.players:
		if not p.connected:
			continue
		alive[p.id] = true
		if players.has(p.id) and players[p.id].look_key != str(p.look):
			players[p.id].queue_free()          # сменилась внешность (пол, причёска) — модель заново
			players.erase(p.id)
		if not players.has(p.id):
			var m := CharModel.new()
			m.setup(p.look)
			add_child(m)
			players[p.id] = m
		var cm: CharModel = players[p.id]
		var st: Array = walk.get(p.id, [0.0, p.rpos, 0.0, 0.0])
		cm.position = Vector3(p.rpos.x, _ground_at(p.rpos.x, p.rpos.y), p.rpos.y)
		cm.rotation.y = atan2(p.rface.x, p.rface.y)
		cm.atk_kind = p.atk_kind
		cm.set_wear(p.wear)
		# без сознания — падает и лежит, очнулся — встаёт
		var down_t := 1.0 if p.dead else 0.0
		var fb: float = pfall.get(p.id, down_t)
		fb = move_toward(fb, down_t, dt / (0.55 if down_t > fb else 0.8))
		pfall[p.id] = fb
		cm.fall = fb
		cm.speed = st[2]
		cm.pose(st[0], (st[3] if st.size() > 3 else 0.0) * (1.0 - fb), p.attack_anim, p.weapon_id(), fb >= 0.999, p.sneaking)
	for id in players.keys():
		if not alive.has(id):
			players[id].queue_free()
			players.erase(id)
			pfall.erase(id)
	# ---------- кровь ----------
	if blood_dirty:
		blood_dirty = false
		var mb: MultiMesh = bm.multimesh
		mb.visible_instance_count = blood.size()
		for bi in blood.size():
			var b: Array = blood[bi]
			var tr := Transform3D(Basis(Vector3.UP, b[3]).scaled(Vector3(b[4], 1, b[4])), Vector3(b[0], b[1], b[2]))
			mb.set_instance_transform(bi, tr)
			mb.set_instance_color(bi, Color(0.29, 0.03, 0.03))
	# ---------- частицы ----------
	var mp: MultiMesh = pm.multimesh
	mp.visible_instance_count = particles.size()
	for pi in particles.size():
		var p: Array = particles[pi]
		var k3: float = clampf(p[2] / p[3], 0.3, 1.0) * p[5]
		mp.set_instance_transform(pi, Transform3D(Basis.IDENTITY.scaled(Vector3(k3, k3, k3)), p[0]))
		mp.set_instance_color(pi, p[4])
	# ---------- выстрелы ----------
	for si in shot_nodes.size():
		var sn: MeshInstance3D = shot_nodes[si]
		if si < g.shots.size():
			var s2: Array = g.shots[si]
			var a := Vector3(s2[0], 1.2, s2[1])
			var b2 := Vector3(s2[2], 1.2, s2[3])
			sn.visible = true
			sn.position = (a + b2) * 0.5
			sn.look_at(b2, Vector3.UP)
			sn.scale = Vector3(1, 1, a.distance_to(b2))
		else:
			sn.visible = false
	# ---------- цель ----------
	target_node.visible = target >= 0
	if target >= 0:
		var tx2 := target % world.w
		var tz2 := target / world.w
		var sx := 1.0
		var sz := 1.0
		match world.t_at(target):
			W.CAR: sx = 2.0
			W.CAR_V: sz = 2.0
		target_node.position = Vector3(tx2, _ground_at(tx2 + 0.5, tz2 + 0.5) + 0.02, tz2)
		target_node.scale = Vector3(sx, 1, sz)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
		(target_node.material_override as StandardMaterial3D).albedo_color = Color(0.72, 0.6, 0.25).lerp(Color(1.0, 0.94, 0.7), pulse)

func project(p: Vector3) -> Vector2:
	if cam.is_position_behind(p):
		return Vector2(-1000, -1000)
	return cam.unproject_position(p)

## Направление джойстика на экране → направление в мире с учётом поворота камеры
func screen_to_world(m: Vector2) -> Vector2:
	var a := deg_to_rad(cam_yaw)
	var c := cos(a)
	var s := sin(a)
	return Vector2(c * m.x + s * m.y, -s * m.x + c * m.y)
