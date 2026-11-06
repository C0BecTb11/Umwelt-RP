shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform vec3 player_pos = vec3(50.0, 0.0, 50.0);
uniform vec2 cam_back = vec2(0.0, 1.0);
uniform float cut = 1.0;
uniform float night = 0.0;
uniform vec3 sun_dir = vec3(0.3, 0.85, 0.4);   // к солнцу (мировые оси), задаёт world_view.gd — блики на воде
// текстуры мира: слои 512×512 (assets/tex/world_albedo.png, сборка — docs/tools/build_textures.py)
// без source_color: в режиме совместимости (телефон) массив не переводится в линейный цвет сам — переводим ниже,
// одинаково на всех устройствах
uniform sampler2DArray albedo_tex : filter_linear_mipmap, repeat_enable;

// по слоям: сколько метров на один повтор текстуры, средняя яркость (линейная) и сила узора.
// Цвет = цвет вершины × (текстура / MEAN), узор ослаблен до STRENGTH (1 — полностью).
// Кирпич и комнаты за окном — текстура со своим цветом (цвет вершины только подкрашивает), MEAN < 1 — светлее
const float SCALE[8] = float[](2.0, 3.0, 3.0, 2.0, 2.0, 1.0, 1.0, 4.0);
const float MEAN[8] = float[](0.7, 0.205, 0.042, 0.36, 0.068, 1.0, 1.0, 0.1);
const float STRENGTH[8] = float[](1.0, 0.45, 0.6, 0.5, 0.75, 1.0, 1.0, 0.5);

varying vec3 wpos;
varying vec3 wnrm;
varying float kind;
varying float mat;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	kind = COLOR.a;
	mat = UV.x;
}

void fragment() {
	// стены между камерой и игроком прорезаются
	// только для камеры игрока (перспектива); в проходе теней солнца (ортогональная проекция) стены целые —
	// иначе тень зависела от поворота камеры и «срезанная» стена давала тень без крыши
	bool persp = PROJECTION_MATRIX[3][3] < 0.5;
	if (persp && kind < 0.25 && cut > 0.5 && wpos.y > 0.55) {
		vec2 d = wpos.xz - player_pos.xz;
		float along = dot(d, cam_back);
		float side = abs(d.x * cam_back.y - d.y * cam_back.x);
		if (along > 0.2 && along < 7.0 && side < 2.2 + along * 0.25) discard;
	}
	vec3 c = to_linear(COLOR.rgb);
	// материал: 0 — только цвет; 1.. — слой текстуры + 1. Текстура ложится по мировым координатам
	// (по плоскости, к которой ближе нормаль) — развёртка мешу не нужна
	int L = int(mat + 0.5) - 1;
	if (L == 8) {
		// вода (Mesher.M_WATER). Цвет вершин уже несёт глубину (у берега светлее, вдали темнее — WorldMesh).
		// Рябь: две бегущие волны; нормаль наклоняется по ним — свет и тень на воде движутся, плюс блик солнца
		float a1 = wpos.x * 1.7 + TIME * 0.9;
		float a2 = wpos.z * 1.3 - TIME * 0.7;
		float a3 = (wpos.x + wpos.z) * 3.1 + TIME * 1.6;
		float a4 = (wpos.x * 0.6 - wpos.z * 1.1) * 2.3 - TIME * 1.1;
		float r = sin(a1) * sin(a2) + 0.5 * sin(a3) + 0.35 * sin(a4);
		float gx = 1.7 * cos(a1) * sin(a2) + 0.5 * 3.1 * cos(a3) + 0.35 * 0.6 * 2.3 * cos(a4);
		float gz = 1.3 * sin(a1) * cos(a2) + 0.5 * 3.1 * cos(a3) - 0.35 * 1.1 * 2.3 * cos(a4);
		vec3 n = normalize(vec3(-gx * 0.05, 1.0, -gz * 0.05));
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
		c = c * (0.93 + 0.07 * r);
		vec3 vdir = normalize(CAMERA_POSITION_WORLD - wpos);
		float spec = pow(max(dot(reflect(-vdir, n), normalize(sun_dir)), 0.0), 60.0);
		float fres = pow(1.0 - max(dot(vdir, n), 0.0), 3.0);
		EMISSION = vec3(1.0, 0.95, 0.85) * spec * 0.9 * (1.0 - night) + vec3(0.35, 0.45, 0.55) * fres * 0.25 * (1.0 - night);
	} else if (L == 9) {
		// пена у берега (Mesher.M_FOAM): то ярче, то слабее, волной вдоль берега
		float f = 0.5 + 0.5 * sin((wpos.x + wpos.z) * 1.9 - TIME * 1.4);
		c = mix(c * 0.7, c, f);
	} else if (L >= 0) {
		vec3 an = abs(wnrm);
		vec2 p;
		if (an.y >= an.x && an.y >= an.z) {
			p = wpos.xz;
		} else if (an.x >= an.z) {
			p = vec2(wpos.z, -wpos.y);
		} else {
			p = vec2(wpos.x, -wpos.y);
		}
		vec2 uv = p / SCALE[L];
		if (L == 5 || L == 6) {
			// комната за окном: картинка на всё окно одной клетки (стекло — от 1.0 до 1.85 м)
			uv = vec2(fract(p.x), clamp((1.85 - wpos.y) / 0.85, 0.0, 1.0));
		}
		vec3 t = to_linear(texture(albedo_tex, vec3(uv, float(L))).rgb);
		c = c * mix(vec3(1.0), t / MEAN[L], STRENGTH[L]);
		if (L == 5) {
			EMISSION = t * night * 1.2;
		}
	}
	ALBEDO = c;
	ROUGHNESS = 0.95;
	if (kind > 0.4 && kind < 0.6) {
		EMISSION = c * (0.5 + night * 2.0);
	}
}
