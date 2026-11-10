class_name CharPoses
extends RefCounted
## Позы «сидит» и «лежит» и переходы к ним. Записанных анимаций для этого в наборе моделей нет, поэтому поза
## считается по скелету: таз ставится на сиденье или постель, ноги дотягиваются до опоры (обратная кинематика —
## колено находится по положению бедра и стопы), руки и спина — по заданным направлениям. Переход — несколько
## опорных поз подряд (встал ровно → наклонился и опустился → сел), между ними поза плавно пересчитывается.
## Всё в координатах модели: +z — лицо, y — вверх, начало — точка, где человек стоял перед тем как сесть.

const SIT_TIME := 1.15         # с, сесть
const LIE_TIME := 2.5          # с, лечь
const THIGH_R := 0.09          # бедро лежит на сиденье: сустав выше сиденья на столько
const LIE_HIP := 0.125         # лёжа на спине: тазобедренный сустав выше постели на столько
const LIE_HEEL := 0.055        # и пятка
const FEET_Z := 0.03           # где стоят стопы, когда человек встал ровно (в стойке одна нога впереди, другая позади)
const SPINE := ["Body", "Hips", "Abdomen", "Torso", "Chest", "Neck", "Head"]

static var _refs := {}

## Опорная стойка одного пола (Idle, первый кадр): от неё отсчитываются все позы
class Ref:
	var n := 0
	var parent := PackedInt32Array()
	var loc: Array = []            # Transform3D кости относительно родителя
	var glob: Array = []           # и в координатах скелета
	var idx := {}                  # имя кости → номер
	var body_yaw := 0.0            # в стойке таз развёрнут вбок на столько, рад
	var hip_mid := Vector3.ZERO    # середина между тазобедренными суставами в осях кости Body
	var thigh := 0.43              # длина бедра
	var shin := 0.51               # от колена до опоры стопы
	var upper_arm := 0.18          # длина плеча
	var fore_arm := 0.235          # и предплечья
	var leg_hinge := [Vector3.RIGHT, Vector3.RIGHT]      # ось колена в стойке (левая, правая)
	var arm_hinge := [Vector3.LEFT, Vector3.LEFT]        # ось локтя
	var foot_in_shin := [Vector3.ZERO, Vector3.ZERO]     # опора стопы в осях голени
	var moves := {}                # кости, у которых поза задаёт и положение (таз, стопы)
	var stand: Spec

## Описание позы — то, что плавно меняется при переходе
class Spec:
	var hip := Vector3.ZERO        # середина между тазобедренными суставами
	var yaw := 0.0                 # разворот тела вокруг вертикали, градусы
	var p_body := 0.0              # наклон таза вперёд (+) или назад (−), градусы
	var p_torso := 0.0             # то же для поясницы,
	var p_chest := 0.0             # груди
	var p_head := 0.0              # и головы
	var untwist := 0.0             # 0 — таз развёрнут, как в стойке; 1 — прямо
	var foot := [Vector3.ZERO, Vector3.ZERO]             # опора стопы (левая, правая)
	var foot_yaw := [0.0, 0.0]     # куда смотрит носок, градусы
	var foot_flat := [1.0, 1.0]    # 1 — стопа плашмя на полу, 0 — продолжает голень
	var knee_yaw := [0.0, 0.0]     # куда смотрит колено относительно тела, градусы
	var arm_u := [Vector3.DOWN, Vector3.DOWN]            # направление плеча в осях груди
	var arm_l := [Vector3.DOWN, Vector3.DOWN]            # и предплечья
	var arm_tw := [0.0, 0.0]       # поворот предплечья вокруг себя, градусы
	var hand := [Vector3.ZERO, Vector3.ZERO]             # куда положить кисть (запястье), в координатах модели
	var hand_w := [0.0, 0.0]       # 1 — рука тянется к hand, 0 — идёт по направлениям arm_u и arm_l
	var elbow := [Vector3(0.45, -0.2, -1.0), Vector3(-0.45, -0.2, -1.0)]    # куда при этом смотрит локоть (в осях груди)

	func copy() -> Spec:
		return CharPoses.mix(self, self, 0.0)

static func _mixv(a: Array, b: Array, t: float) -> Array:
	return [a[0].lerp(b[0], t), a[1].lerp(b[1], t)]

static func _mixf(a: Array, b: Array, t: float) -> Array:
	return [lerpf(a[0], b[0], t), lerpf(a[1], b[1], t)]

## Поза между a и b
static func mix(a: Spec, b: Spec, t: float) -> Spec:
	var s := Spec.new()
	s.hip = a.hip.lerp(b.hip, t)
	s.yaw = lerpf(a.yaw, b.yaw, t)
	s.p_body = lerpf(a.p_body, b.p_body, t)
	s.p_torso = lerpf(a.p_torso, b.p_torso, t)
	s.p_chest = lerpf(a.p_chest, b.p_chest, t)
	s.p_head = lerpf(a.p_head, b.p_head, t)
	s.untwist = lerpf(a.untwist, b.untwist, t)
	s.foot = _mixv(a.foot, b.foot, t)
	s.foot_yaw = _mixf(a.foot_yaw, b.foot_yaw, t)
	s.foot_flat = _mixf(a.foot_flat, b.foot_flat, t)
	s.knee_yaw = _mixf(a.knee_yaw, b.knee_yaw, t)
	s.arm_u = _mixv(a.arm_u, b.arm_u, t)
	s.arm_l = _mixv(a.arm_l, b.arm_l, t)
	s.arm_tw = _mixf(a.arm_tw, b.arm_tw, t)
	s.hand_w = _mixf(a.hand_w, b.hand_w, t)
	s.elbow = _mixv(a.elbow, b.elbow, t)
	for sd in 2:
		if a.hand_w[sd] <= 0.0:
			s.hand[sd] = b.hand[sd]
		elif b.hand_w[sd] <= 0.0:
			s.hand[sd] = a.hand[sd]
		else:
			s.hand[sd] = (a.hand[sd] as Vector3).lerp(b.hand[sd], t)
	return s

## Оси кости: y — вдоль кости (dir), x — как можно ближе к оси сустава (hinge)
static func _frame(dir: Vector3, hinge: Vector3) -> Basis:
	var y := dir.normalized()
	var x := hinge - y * hinge.dot(y)
	if x.length() < 0.001:
		x = y.cross(Vector3.FORWARD) if absf(y.z) < 0.9 else y.cross(Vector3.RIGHT)
	x = x.normalized()
	return Basis(x, y, x.cross(y))

static func _rot(yaw_deg: float, pitch_deg: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Basis(Vector3.RIGHT, deg_to_rad(pitch_deg))

## Опорная стойка: скелет и его анимация Idle (считается один раз на пол)
static func ref_for(gender: String, skel: Skeleton3D, idle: Animation) -> Ref:
	if _refs.has(gender):
		return _refs[gender]
	var r := Ref.new()
	r.n = skel.get_bone_count()
	r.parent.resize(r.n)
	for b in r.n:
		r.parent[b] = skel.get_bone_parent(b)
		r.idx[String(skel.get_bone_name(b))] = b
		r.loc.append(skel.get_bone_rest(b).orthonormalized())
	if idle != null:
		for t in idle.get_track_count():
			var b := skel.find_bone(String(idle.track_get_path(t).get_concatenated_subnames()))
			if b < 0:
				continue
			var tr: Transform3D = r.loc[b]
			if idle.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				tr.basis = Basis(idle.rotation_track_interpolate(t, 0.0))
			elif idle.track_get_type(t) == Animation.TYPE_POSITION_3D:
				tr.origin = idle.position_track_interpolate(t, 0.0)
			r.loc[b] = tr
	for b in r.n:
		r.glob.append(r.loc[b] if r.parent[b] < 0 else r.glob[r.parent[b]] * r.loc[b])
	var gb: Transform3D = r.glob[r.idx["Body"]]
	r.body_yaw = atan2(-gb.basis.x.z, gb.basis.x.x)
	var hl: Vector3 = r.loc[r.idx["UpperLeg.L"]].origin
	var hr: Vector3 = r.loc[r.idx["UpperLeg.R"]].origin
	r.hip_mid = (hl + hr) * 0.5
	r.thigh = r.loc[r.idx["LowerLeg.L"]].origin.length()
	r.upper_arm = r.loc[r.idx["LowerArm.L"]].origin.length()
	r.fore_arm = r.loc[r.idx["Wrist.L"]].origin.length()
	var st := Spec.new()
	st.hip = gb * r.hip_mid
	for s in 2:
		var sfx: String = [".L", ".R"][s]
		var gu: Transform3D = r.glob[r.idx["UpperLeg" + sfx]]
		var gl: Transform3D = r.glob[r.idx["LowerLeg" + sfx]]
		var gf: Transform3D = r.glob[r.idx["Foot" + sfx]]
		r.leg_hinge[s] = gu.basis.y.cross(gl.basis.y).normalized()
		r.foot_in_shin[s] = gl.affine_inverse() * gf.origin
		if s == 0:
			r.shin = (gf.origin - gl.origin).length()
		st.foot[s] = gf.origin
		st.foot_yaw[s] = rad_to_deg(atan2(gf.basis.y.x, gf.basis.y.z))
		st.knee_yaw[s] = rad_to_deg(atan2(-r.leg_hinge[s].z, r.leg_hinge[s].x))
		var au: Vector3 = r.glob[r.idx["UpperArm" + sfx]].basis.y
		var al: Vector3 = r.glob[r.idx["LowerArm" + sfx]].basis.y
		r.arm_hinge[s] = au.cross(al).normalized()
		st.arm_u[s] = au
		st.arm_l[s] = al
	r.stand = st
	for nm in ["Body", "Foot.L", "Foot.R"]:
		r.moves[r.idx[nm]] = true
	_refs[gender] = r
	return r

## Поза по описанию: кость → Transform3D относительно родителя (только кости, которые поза двигает)
static func solve(r: Ref, s: Spec) -> Dictionary:
	var out := {}
	var g: Array = r.glob.duplicate()
	var untw := Basis(Vector3.UP, -r.body_yaw * s.untwist)
	var rb := _rot(s.yaw, s.p_body)
	var rots := {"Body": rb * untw, "Hips": rb * untw, "Abdomen": _rot(s.yaw, lerpf(s.p_body, s.p_torso, 0.5)) * untw,
		"Torso": _rot(s.yaw, s.p_torso), "Chest": _rot(s.yaw, s.p_chest),
		"Neck": _rot(s.yaw, lerpf(s.p_chest, s.p_head, 0.5)), "Head": _rot(s.yaw, s.p_head)}
	var rchest: Basis = rots["Chest"]
	var set_b := {}                # кость → новые оси в координатах скелета
	for nm in SPINE:
		set_b[r.idx[nm]] = (rots[nm] as Basis) * (r.glob[r.idx[nm]] as Transform3D).basis
	var body_i: int = r.idx["Body"]
	var body_o: Vector3 = s.hip - (set_b[body_i] as Basis) * r.hip_mid
	var legs := {}                 # номер кости бедра → [сторона]
	var shins := {}
	var feet := {}
	var uarms := {}
	var larms := {}
	for sd in 2:
		var sfx: String = [".L", ".R"][sd]
		legs[r.idx["UpperLeg" + sfx]] = sd
		shins[r.idx["LowerLeg" + sfx]] = sd
		feet[r.idx["Foot" + sfx]] = sd
		uarms[r.idx["UpperArm" + sfx]] = sd
		larms[r.idx["LowerArm" + sfx]] = sd
	var knee := [Vector3.ZERO, Vector3.ZERO]
	var hinge := [Vector3.RIGHT, Vector3.RIGHT]
	var ahinge := [Vector3.LEFT, Vector3.LEFT]
	var shin_ref := [Basis(), Basis()]
	var arm_dir := [Vector3.DOWN, Vector3.DOWN]
	for b in r.n:
		var pg: Transform3D = g[r.parent[b]] if r.parent[b] >= 0 else Transform3D.IDENTITY
		var ng: Transform3D = pg * (r.loc[b] as Transform3D)       # по умолчанию кость идёт за родителем
		var driven := true
		if set_b.has(b):
			ng.basis = set_b[b]
			if b == body_i:
				ng.origin = body_o
		elif legs.has(b):
			var sd: int = legs[b]
			var h := ng.origin
			var to: Vector3 = s.foot[sd] - h
			var d := clampf(to.length(), 0.05, r.thigh + r.shin - 0.004)
			var dir := to.normalized()
			var pole: Vector3 = rb * Basis(Vector3.UP, deg_to_rad(s.knee_yaw[sd])) * Vector3.BACK
			var perp := pole - dir * pole.dot(dir)
			if perp.length() < 0.001:
				perp = rb * Vector3.UP
			perp = perp.normalized()
			var a := (r.thigh * r.thigh - r.shin * r.shin + d * d) / (2.0 * d)
			knee[sd] = h + dir * a + perp * sqrt(maxf(r.thigh * r.thigh - a * a, 0.0))
			hinge[sd] = perp.cross(dir).normalized()
			var gu: Basis = (r.glob[b] as Transform3D).basis
			ng.basis = _frame(knee[sd] - h, hinge[sd]) * _frame(gu.y, r.leg_hinge[sd]).inverse() * gu
		elif shins.has(b):
			var sd2: int = shins[b]
			var gl: Basis = (r.glob[b] as Transform3D).basis
			var hpos: Vector3 = (g[r.parent[b]] as Transform3D).origin
			var down: Vector3 = s.foot[sd2] - ng.origin
			if (s.foot[sd2] - hpos).length() > r.thigh + r.shin - 0.004:
				down = s.foot[sd2] - hpos           # нога не дотягивается — тянется прямо к опоре
			ng.basis = _frame(down, hinge[sd2]) * _frame(gl.y, r.leg_hinge[sd2]).inverse() * gl
			shin_ref[sd2] = ng.basis * gl.inverse()
		elif feet.has(b):
			var sd3: int = feet[b]
			var sh: Transform3D = g[r.idx["LowerLeg" + [".L", ".R"][sd3]]]
			ng.origin = sh * (r.foot_in_shin[sd3] as Vector3)
			var rigid: Basis = (shin_ref[sd3] as Basis) * (r.glob[b] as Transform3D).basis
			var fy := deg_to_rad(s.foot_yaw[sd3])
			var toe := Vector3(sin(fy), 0, cos(fy))
			var flat := Basis(toe.cross(Vector3.DOWN), toe, Vector3.DOWN)
			ng.basis = Basis(rigid.get_rotation_quaternion().slerp(flat.get_rotation_quaternion(), clampf(s.foot_flat[sd3], 0.0, 1.0)))
		elif uarms.has(b):
			var sd4: int = uarms[b]
			var u: Vector3 = (rchest * (s.arm_u[sd4] as Vector3)).normalized()
			var l: Vector3 = (rchest * (s.arm_l[sd4] as Vector3)).normalized()
			if s.hand_w[sd4] > 0.0:
				# рука тянется к точке: локоть — назад и в сторону
				var to2: Vector3 = (s.hand[sd4] as Vector3) - ng.origin
				var d2 := clampf(to2.length(), 0.05, r.upper_arm + r.fore_arm - 0.003)
				var dr := to2.normalized()
				var pl: Vector3 = rchest * (s.elbow[sd4] as Vector3)
				var pp := (pl - dr * pl.dot(dr)).normalized()
				var a2 := (r.upper_arm * r.upper_arm - r.fore_arm * r.fore_arm + d2 * d2) / (2.0 * d2)
				var el: Vector3 = ng.origin + dr * a2 + pp * sqrt(maxf(r.upper_arm * r.upper_arm - a2 * a2, 0.0))
				var hw2: float = clampf(s.hand_w[sd4], 0.0, 1.0)
				u = u.lerp((el - ng.origin).normalized(), hw2).normalized()
				l = l.lerp((ng.origin + dr * d2 - el).normalized(), hw2).normalized()
			arm_dir[sd4] = l
			var hx := u.cross(l)
			ahinge[sd4] = hx.normalized() if hx.length() > 0.08 else rchest * (r.arm_hinge[sd4] as Vector3)
			var ga: Basis = (r.glob[b] as Transform3D).basis
			ng.basis = _frame(u, ahinge[sd4]) * _frame(ga.y, r.arm_hinge[sd4]).inverse() * ga
		elif larms.has(b):
			var sd5: int = larms[b]
			var l2: Vector3 = arm_dir[sd5]
			var gl2: Basis = (r.glob[b] as Transform3D).basis
			ng.basis = Basis(l2, deg_to_rad(s.arm_tw[sd5])) * _frame(l2, ahinge[sd5]) * _frame(gl2.y, r.arm_hinge[sd5]).inverse() * gl2
		else:
			driven = false
		g[b] = ng
		if driven:
			out[b] = pg.affine_inverse() * ng
	return out

# ================== опорные позы ==================
## Встал ровно перед тем как сесть: ноги вместе, таз прямо
static func _square(r: Ref, feet_z: float) -> Spec:
	var s := r.stand.copy()
	var hw := absf((r.loc[r.idx["UpperLeg.L"]] as Transform3D).origin.x)
	s.untwist = 1.0
	s.hip = Vector3(0, r.stand.hip.y - 0.015, feet_z + 0.02)
	for sd in 2:
		var sx := hw * (1.0 if sd == 0 else -1.0)
		s.foot[sd] = Vector3(sx * 0.95, r.stand.foot[sd].y, feet_z)
		s.foot_yaw[sd] = 7.0 if sd == 0 else -7.0
		s.knee_yaw[sd] = 5.0 if sd == 0 else -5.0
	return s

## На сколько сиденье позади точки, где человек стоял: чтобы стопы, когда он сядет, остались на месте
static func sit_back(r: Ref, h: float) -> float:
	var hy := h + THIGH_R
	var ky := minf(hy, r.stand.foot[0].y + r.shin)
	return sqrt(maxf(r.thigh * r.thigh - (hy - ky) * (hy - ky), 0.0)) + 0.02 - FEET_Z

## Сидит на сиденье высотой h (верх сиденья над полом)
static func sit(r: Ref, h: float) -> Spec:
	var back := sit_back(r, h)
	var s := _square(r, FEET_Z)
	s.hip = Vector3(0, h + THIGH_R, -back)
	s.p_body = -9.0
	s.p_torso = -5.0
	s.p_chest = -1.0
	s.p_head = 0.0
	var hang := h + THIGH_R - (r.thigh + r.shin) > -0.06     # высокое сиденье: ноги почти не достают до пола
	for sd in 2:
		var k := 1.0 if sd == 0 else -1.0
		if hang:
			s.foot[sd].y = h + THIGH_R - (r.thigh + r.shin) * 0.98
			s.foot_flat[sd] = 0.35
		s.arm_u[sd] = Vector3(0.10 * k, -0.99, -0.04)
		s.arm_l[sd] = Vector3(-0.14 * k, -0.46, 0.88)
		s.arm_tw[sd] = 70.0 * k
		s.knee_yaw[sd] = 9.0 * k
		s.foot[sd].x *= 1.12
		# кисть лежит на бедре
		var kn: Vector3 = Vector3(s.foot[sd].x, minf(s.hip.y, s.foot[sd].y + r.shin), s.foot[sd].z + 0.02)
		var hj := Vector3(s.foot[sd].x / 1.12, s.hip.y, s.hip.z)
		s.hand[sd] = hj.lerp(kn, 0.58) + Vector3(-0.015 * k, THIGH_R + 0.03, 0)
		s.hand_w[sd] = 1.0
	return s

## Наклонился и опускается на сиденье (середина перехода)
static func _lower(r: Ref, h: float) -> Spec:
	var end := sit(r, h)
	var s := mix(_square(r, FEET_Z), end, 0.5)
	s.hip = Vector3(0, lerpf(r.stand.hip.y, end.hip.y, 0.55), lerpf(FEET_Z, end.hip.z, 0.62))
	var deep_k := clampf((r.stand.hip.y - end.hip.y) / 0.36, 0.25, 1.0)      # на высокое сиденье наклоняться почти не надо
	s.p_body = 30.0 * deep_k
	s.p_torso = 34.0 * deep_k
	s.p_chest = 30.0 * deep_k
	s.p_head = 8.0 * deep_k
	for sd in 2:
		var k := 1.0 if sd == 0 else -1.0
		s.foot[sd] = end.foot[sd]
		s.hand_w[sd] = 0.0
		s.arm_u[sd] = Vector3(0.12 * k, -0.9, 0.1)
		s.arm_l[sd] = Vector3(0.02 * k, -0.85, 0.5)
	return s

## Лежит на спине на постели высотой h. Постель позади: её середина в deep за спиной; side = 1 — головой
## влево от себя (−x), −1 — вправо; up — на сколько градусов приподнято изголовье (больничная койка)
static func lie(r: Ref, h: float, deep: float, side: int, up: float = 0.0) -> Spec:
	var s := _square(r, FEET_Z)
	var k := float(side)
	var leg := (r.thigh + r.shin) * 0.992
	var along := Vector3(k, 0, 0)                  # от головы к ногам
	s.yaw = 90.0 * k
	s.p_body = -90.0
	s.p_torso = -90.0 + up
	s.p_chest = -88.0 + up
	s.p_head = -74.0 + up * 0.8
	s.hip = Vector3(0, h + LIE_HIP, -deep)
	var hw := absf((r.loc[r.idx["UpperLeg.L"]] as Transform3D).origin.x)
	for sd in 2:
		var sx := 1.0 if sd == 0 else -1.0
		# левая нога лежащего — со стороны −z·k (он развёрнут на 90°)
		var lat := Vector3(0, 0, -sx * k) * (hw + 0.035)
		s.foot[sd] = s.hip + lat + along * leg + Vector3(0, LIE_HEEL - LIE_HIP, 0)
		s.foot_flat[sd] = 0.0
		s.knee_yaw[sd] = 14.0 * sx
		s.arm_u[sd] = Vector3(0.26 * sx, -0.92, -0.26)
		s.arm_l[sd] = Vector3(-0.5 * sx, -0.78, 0.3)
		s.arm_tw[sd] = 60.0 * sx
		# кисть лежит на животе (в осях тела: вверх по спине — к голове, вперёд — вверх от постели)
		s.hand[sd] = s.hip + _rot(s.yaw, lerpf(s.p_body, s.p_torso, 0.5)) * Vector3(0.07 * sx, 0.12, 0.15)
		s.hand_w[sd] = 1.0
		s.elbow[sd] = Vector3(1.0 * sx, -0.25, -0.3)
	return s

## Сел на край постели, разворачивается и заносит ноги (середина перехода «лечь»)
static func _swing(r: Ref, h: float, deep: float, side: int, up: float = 0.0) -> Spec:
	var end := lie(r, h, deep, side, up)
	var edge := sit(r, h)
	var s := mix(edge, end, 0.5)
	var k := float(side)
	s.yaw = 52.0 * k
	s.p_body = -38.0
	s.p_torso = -30.0
	s.p_chest = -22.0
	s.p_head = -6.0
	s.hip = Vector3(-0.05 * k, h + THIGH_R + 0.01, lerpf(edge.hip.z, end.hip.z, 0.6))
	for sd in 2:
		var sx := 1.0 if sd == 0 else -1.0
		var ef: Vector3 = end.foot[sd]
		s.foot[sd] = Vector3(ef.x * 0.62, h + 0.2, lerpf(0.12, ef.z, 0.55))
		s.foot_flat[sd] = 0.0
		s.knee_yaw[sd] = 6.0 * sx
		# рука со стороны головы опирается о постель позади, другая помогает
		var prop := (sx * k) > 0.0
		s.hand_w[sd] = 0.0
		s.arm_u[sd] = Vector3(0.3 * sx, -0.85, -0.42) if prop else Vector3(0.12 * sx, -0.9, 0.3)
		s.arm_l[sd] = Vector3(0.1 * sx, -0.9, -0.3) if prop else Vector3(-0.2 * sx, -0.6, 0.7)
	return s

## Опорные позы перехода: [[доля времени, Spec], …]. kind: 1 — сесть, 2 — лечь
static func keys(r: Ref, kind: int, h: float, deep: float = 0.7, side: int = 1, up: float = 0.0) -> Array:
	var sq := _square(r, FEET_Z)
	if kind == 2:
		var edge := sit(r, h)
		edge.hip.z = maxf(edge.hip.z, -deep + 0.2)
		return [[0.0, r.stand], [0.13, sq], [0.26, _lower(r, h)], [0.42, edge], [0.7, _swing(r, h, deep, side, up)], [1.0, lie(r, h, deep, side, up)]]
	return [[0.0, r.stand], [0.27, sq], [0.62, _lower(r, h)], [1.0, sit(r, h)]]

static func _at(ks: Array, u: float) -> Spec:
	u = clampf(u, 0.0, 1.0)
	for i in range(1, ks.size()):
		if u <= ks[i][0] or i == ks.size() - 1:
			var a: float = ks[i - 1][0]
			var b: float = ks[i][0]
			return mix(ks[i - 1][1], ks[i][1], clampf((u - a) / maxf(b - a, 0.0001), 0.0, 1.0))
	return ks[0][1]

## Поза в долю u перехода (0 — стоит, 1 — сидит или лежит): плавно, без рывков на опорных позах
static func at(ks: Array, u: float) -> Spec:
	var e := u * u * (3.0 - 2.0 * u)               # разгон и торможение
	var w := minf(0.07, minf(e, 1.0 - e))
	var s := mix(_at(ks, e - w), _at(ks, e + w), 0.5)
	s = mix(s, _at(ks, e), 0.5)
	# шаг: пока стопа переставляется, она приподнята
	var st: Spec = ks[0][1]
	var sq: Spec = ks[1][1]
	var k1: float = ks[1][0]
	if e < k1:
		for sd in 2:
			var ph := clampf(e / k1 * 1.25 - (0.0 if sd == 0 else 0.25), 0.0, 1.0)
			var far: float = (sq.foot[sd] - st.foot[sd]).length()
			var p: Vector3 = st.foot[sd].lerp(sq.foot[sd], ph * ph * (3.0 - 2.0 * ph))
			s.foot[sd] = p + Vector3(0, sin(ph * PI) * minf(far * 0.3, 0.07), 0)
			s.foot_yaw[sd] = lerpf(st.foot_yaw[sd], sq.foot_yaw[sd], ph)
	return s

static func duration(kind: int) -> float:
	return LIE_TIME if kind == 2 else SIT_TIME
