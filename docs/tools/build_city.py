#!/usr/bin/env python3
"""Генератор карты Umwelt RP: город по утверждённой планировке (2026-11-07).

  python3 docs/tools/build_city.py                 → maps/city.json (через map_format.py — принятый вид файла)
  python3 docs/tools/build_city.py --plan plan.png → ещё и рисунок планировки

Всё задано здесь: дороги-линии, вода, районы, участки, формы домов, комнаты, мебель, дворы, фонари, деревья.
Случайность — с постоянным зерном (SEED): тот же скрипт даёт ту же карту. Поменять район, добавить улицу или
увеличить карту — правка этого файла и запуск заново (размер карты — N; больше 500 — сначала GameWorld.MAX_SIDE).
"""
import json, math, random, subprocess, sys, os
from collections import deque
import numpy as np

SEED = 7
N = 500
random.seed(SEED)
OW = {"street": 5.0, "highway": 7.5, "bridge": 4.0}     # = GameWorld.LINE_OUTER_HW
HW = {"street": 3.0, "highway": 6.0, "bridge": 3.0}     # = GameWorld.LINE_ROAD_HW
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# ======================= ДОРОГИ =======================
lines = []
def L(kind, *pts):
    lines.append([kind] + [float(p) for p in pts])

L("highway", 0, 40, 380, 40, 462, 122, 462, 500)          # шоссе: север и восток (объезд)
AV = [200, 245, 290, 335, 380]                            # даунтаун: авеню (с севера на юг)
ST = [176, 218, 260, 302]                                 # даунтаун: улицы (с запада на восток)
L("street", 290, 40, 290, 470)                            # Центральная авеню: от шоссе через центр на юг (одна линия)
for x in (200, 245, 380):
    L("street", x, 176, x, 302)
L("street", 335, 302, 335, 150, 440, 150)                 # авеню 335 переходит в дорогу к фермам
L("street", 40, 218, 462, 218)                            # Мейн-стрит
for y in (176, 260, 302):
    L("street", 200, y, 380, y)
L("street", 175, 110, 450, 110)                           # Промзона: Индастриал-роуд, до шоссе (мимо ферм)
L("street", 100, 40, 100, 218)                            # Оук-Хилл: хребет…
for y in (78, 118, 158):
    L("street", 22, y, 172, y)                            # …и поперечные улицы
L("street", 22, 78, 22, 158)
for y in (360, 450):                                      # Ривер-Сайд
    L("street", 290, y, 462, y)
L("street", 462, 405, 262, 405)                           # средняя улица Ривер-Сайда идёт дальше к мосту
# (до 0.50 мост был на 400 — в 5 м от улицы 405: два перекрёстка рядом, две пачки «зебр», BF-064)
L("street", 375, 360, 375, 488)
L("bridge", 262, 405, 214, 405)                           # мост через реку
L("street", 214, 405, 110, 405)                           # к лесным домикам
L("street", 192, 405, 192, 490)                           # за мостом

def segs(e):
    pts = [(e[i], e[i + 1]) for i in range(1, len(e), 2)]
    return list(zip(pts, pts[1:]))

yy, xx = np.mgrid[0:N, 0:N]
CX, CY = xx + 0.5, yy + 0.5
def seg_dist(px, py, a, b):
    ax, ay = a; bx, by = b
    dx, dy = bx - ax, by - ay
    t = np.clip(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy), 0, 1)
    return np.hypot(px - (ax + t * dx), py - (ay + t * dy))

road_d = np.full((N, N), 1e9)        # расстояние от центра клетки до ближайшей оси (с учётом ширины: минус ow)
asph_d = np.full((N, N), 1e9)        # то же, до края асфальта
for e in lines:
    for a, b in segs(e):
        d = seg_dist(CX, CY, a, b)
        road_d = np.minimum(road_d, d - OW[e[0]])
        asph_d = np.minimum(asph_d, d - HW[e[0]])
on_road = road_d < 0.71              # клетка задевает полосу дороги (с тротуаром)

# ======================= ВОДА, ЛЕС =======================
water = ((xx - 100) / 66.0) ** 2 + ((yy - 322) / 38.0) ** 2 <= 1.0
RIVER = [(160, 334), (212, 366), (240, 400), (258, 440), (272, 500)]
for a, b in zip(RIVER, RIVER[1:]):
    water |= seg_dist(CX, CY, a, b) <= 7.0

occ = np.zeros((N, N), np.int32)      # 0 свободно, 1 дорога/вода/берег/парк, 2+ — дом
occ[road_d < 1.0] = 1
near_w = np.zeros((N, N), bool)
wy, wx = np.nonzero(water)
for dy in range(-3, 4):
    for dx in range(-3, 4):
        near_w[np.clip(wy + dy, 0, N - 1), np.clip(wx + dx, 0, N - 1)] = True
occ[near_w] = 1
PARKS = [(30, 268, 170, 284)]                         # парк у озера
for (x0, y0, x1, y1) in PARKS:
    occ[y0:y1, x0:x1] = 1
SQUARE = (252, 224, 283, 254)                          # площадь мэрии (мощёная)
occ[SQUARE[1]:SQUARE[3] + 1, SQUARE[0]:SQUARE[2] + 1] = 1
STATION_PLAZA = (284, 306, 330, 352)                   # площадь вокзала (место появления) — оформляется отдельно

# ======================= ДОМА: ПЛАНИРОВКА =======================
houses = []   # dict: zone, kind, rects [(x0,y0,x1,y1) включительно], front 'N'/'S'/'E'/'W'

def free(rects, gap=2):
    for (x0, y0, x1, y1) in rects:
        if x0 - gap < 1 or y0 - gap < 1 or x1 + gap > N - 2 or y1 + gap > N - 2:
            return False
        if (occ[y0 - gap:y1 + gap + 1, x0 - gap:x1 + gap + 1] >= 2).any():
            return False
        if occ[y0:y1 + 1, x0:x1 + 1].max() > 0:
            return False
    return True

def put(zone, kind, rects, front):
    if not free(rects):
        return False
    hid = len(houses) + 2
    for (x0, y0, x1, y1) in rects:
        occ[y0:y1 + 1, x0:x1 + 1] = hid
    houses.append({"zone": zone, "kind": kind, "rects": rects, "front": front})
    return True

def shape(w, h, form, flip_x=False, flip_y=False):
    """След w×h: прямоугольник, Г, Т, П. Первый прямоугольник — главный (с фасадом при front='N' и без флипа)."""
    if form == "rect":
        r = [(0, 0, w - 1, h - 1)]
    elif form == "L":
        cw, ch = max(4, w // 2 - 1), max(4, h // 2 - 1)
        r = [(0, 0, w - 1, h - ch - 1), (0, h - ch, w - cw - 1, h - 1)]
    elif form == "T":
        sw = max(5, w // 3 + 1)
        r = [(0, 0, w - 1, h // 2 - 1), ((w - sw) // 2, h // 2, (w - sw) // 2 + sw - 1, h - 1)]
    else:  # "U"
        sw = max(5, w // 3)
        r = [(0, 0, w - 1, h // 2 - 1), (0, h // 2, sw - 1, h - 1), (w - sw, h // 2, w - 1, h - 1)]
    out = []
    for (x0, y0, x1, y1) in r:
        if flip_x:
            x0, x1 = w - 1 - x1, w - 1 - x0
        if flip_y:
            y0, y1 = h - 1 - y1, h - 1 - y0
        out.append((x0, y0, x1, y1))
    return out

def rot90(rects, w, h):
    """Повернуть след (w×h) на 90°: x' = y, y' = w-1-x."""
    return [(y0, w - 1 - x1, y1, w - 1 - x0) for (x0, y0, x1, y1) in rects]

def at(rects, ox, oy):
    return [(x0 + ox, y0 + oy, x1 + ox, y1 + oy) for (x0, y0, x1, y1) in rects]

def lots_along(zone, axis, coord, a, b, side, setback, sizes, forms, kind="дом", gap_min=4):
    """Участки вдоль прямой улицы. axis 'x' — улица вдоль x (y=coord); side ±1 — сторона (+ — дальше по оси).
    Главный прямоугольник следа — у улицы, фасадом к ней."""
    p = a + 3
    while p + 8 < b:
        w, h = random.choice(sizes)
        form = random.choice(forms)
        if axis == "x":
            front = "N" if side > 0 else "S"
            rects = shape(w, h, form, flip_x=random.random() < 0.5, flip_y=side < 0)
            oy = int(coord + setback) if side > 0 else int(coord - setback - h + 1)
            ok = put(zone, kind, at(rects, int(p), oy), front)
        else:
            front = "W" if side > 0 else "E"
            # фасад вдоль y: строим «как у улицы вдоль x», поворачиваем
            rr = shape(w, h, form, flip_x=random.random() < 0.5)            # фасад сверху (y=0)
            # поворот: верх (фасад) → лево (W) при side>0 или право (E) при side<0
            rr = [(y0, x0, y1, x1) for (x0, y0, x1, y1) in rr]               # транспонирование: фасад слева
            if side < 0:
                rr = [(h - 1 - x1, y0, h - 1 - x0, y1) for (x0, y0, x1, y1) in rr]
            ox = int(coord + setback) if side > 0 else int(coord - setback - h + 1)
            ok = put(zone, kind, at(rr, ox, int(p)), front)
        if ok:
            p += w + random.randint(gap_min, gap_min + 3)
        else:
            p += 2

SUB_SIZES = [(10, 11), (11, 12), (12, 10), (12, 13), (9, 11), (14, 12), (11, 14), (13, 10)]
SUB_FORMS = ["rect", "rect", "L", "L", "T", "rect"]

for y in (78, 118, 158):                                   # Оук-Хилл
    for side in (-1, 1):
        lots_along("Оук-Хилл", "x", y, 26, 170, side, 8, SUB_SIZES, SUB_FORMS)
lots_along("Оук-Хилл", "x", 218, 40, 170, -1, 8, SUB_SIZES, SUB_FORMS)
for side in (-1, 1):
    lots_along("Оук-Хилл", "y", 100, 40, 76, side, 8, SUB_SIZES, SUB_FORMS)
lots_along("Оук-Хилл", "x", 218, 40, 175, 1, 8, SUB_SIZES, SUB_FORMS)
for y in (360, 405, 450):                                  # Ривер-Сайд
    for side in (-1, 1):
        lots_along("Ривер-Сайд", "x", y, 296, 456, side, 8, SUB_SIZES, SUB_FORMS)
for side in (-1, 1):
    lots_along("Ривер-Сайд", "y", 375, 452, 488, side, 8, SUB_SIZES, SUB_FORMS)
lots_along("Ривер-Сайд", "x", 450, 296, 456, 1, 8, SUB_SIZES, SUB_FORMS)

# Даунтаун: кварталы — 2–4 здания вплотную к тротуару
DT_KINDS = ["магазин", "магазин", "контора", "кафе", "магазин", "контора"]
for i in range(len(AV) - 1):
    for j in range(len(ST) - 1):
        x0, x1 = AV[i] + 7, AV[i + 1] - 7
        y0, y1 = ST[j] + 7, ST[j + 1] - 7
        if AV[i] == 245 and ST[j] == 218:
            continue
        bw, bh = x1 - x0 + 1, y1 - y0 + 1
        split = random.choice(["2x", "4", "4", "3", "3"])
        if split == "2x":
            a = bw // 2 - 1
            parts = [(x0, y0, a, bh), (x0 + a + 3, y0, bw - a - 3, bh)]
        elif split == "3":
            a, b2 = bw // 2 - 1, bh // 2 - 1
            parts = [(x0, y0, a, bh), (x0 + a + 3, y0, bw - a - 3, b2), (x0 + a + 3, y0 + b2 + 3, bw - a - 3, bh - b2 - 3)]
        else:
            a, b2 = bw // 2 - 1, bh // 2 - 1
            parts = [(x0, y0, a, b2), (x0 + a + 3, y0, bw - a - 3, b2), (x0, y0 + b2 + 3, a, bh - b2 - 3),
                     (x0 + a + 3, y0 + b2 + 3, bw - a - 3, bh - b2 - 3)]
        for (px, py, pw, ph) in parts:
            # фасад — к ближайшей улице квартала
            dists = {"N": py - y0, "S": (y0 + bh) - (py + ph), "W": px - x0, "E": (x0 + bw) - (px + pw)}
            front = min(dists, key=lambda k: (dists[k], "NSWE".index(k)))
            form = random.choice(["rect", "rect", "L", "U", "T"]) if pw >= 13 and ph >= 13 else "rect"
            # главный прямоугольник формы — у фасада
            if front in ("N", "S"):
                rects = shape(pw, ph, form, random.random() < 0.5, front == "S")
            else:
                rr = shape(ph, pw, form, random.random() < 0.5)
                rr = [(y0_, x0_, y1_, x1_) for (x0_, y0_, x1_, y1_) in rr]
                if front == "E":
                    rr = [(pw - 1 - x1_, y0_, pw - 1 - x0_, y1_) for (x0_, y0_, x1_, y1_) in rr]
                rects = rr
            put("Даунтаун", random.choice(DT_KINDS), at(rects, px, py), front)
# мэрия посреди площади: место под неё освобождаем, остальная площадь — занята
sq = occ[SQUARE[1]:SQUARE[3] + 1, SQUARE[0]:SQUARE[2] + 1]
sq[:] = 0
put("Даунтаун", "мэрия", at(shape(21, 15, "T"), 257, 225), "N")
sq[sq == 0] = 1

put("Вокзал", "автовокзал", at(shape(24, 12, "rect"), 300, 316), "W")
put("Вокзал", "больница", at(shape(26, 16, "U", flip_y=True), 250, 322), "E")

lots_along("Мейн-стрит", "x", 218, 388, 452, -1, 7, [(14, 12), (18, 12), (12, 10)], ["rect", "L"], kind="кафе", gap_min=6)
lots_along("Мейн-стрит", "x", 218, 388, 452, 1, 7, [(22, 12), (14, 12), (12, 10)], ["rect", "U", "L"], kind="магазин", gap_min=6)
lots_along("Промзона", "x", 110, 180, 398, -1, 7, [(20, 30), (24, 26), (18, 22)], ["rect", "rect", "L"], kind="склад", gap_min=8)
lots_along("Промзона", "x", 110, 180, 398, 1, 7, [(26, 18), (20, 16), (30, 18)], ["rect", "rect", "L"], kind="склад", gap_min=8)

FARMS = []
for fx, fy in ((392, 158), (424, 160), (402, 120), (300, 58), (340, 56)):
    a1 = put("Фермы", "дом", at(shape(11, 12, "L"), fx, fy), "N")
    a2 = put("Фермы", "амбар", at(shape(12, 16, "rect"), fx + 15, fy + 2), "N")
    if a1 or a2:
        FARMS.append((fx, fy))
for side in (-1, 1):
    lots_along("За мостом", "y", 192, 404, 490, side, 8, SUB_SIZES, SUB_FORMS)
for (cx, cy) in ((150, 384), (128, 386), (172, 380)):
    put("Лесные домики", "домик", at(shape(8, 9, random.choice(["rect", "L"])), cx, cy), "S")

SPAWN = (290.5, 342.5)

# ======================= КЛЕТКИ =======================
T = np.full((N, N), ".", dtype="<U1")
T[water] = "~"
props = []

def face(dx, dy):
    """Поворот объекта (градусы), чтобы его лицевая сторона (у моделей — локальная +z) смотрела в (dx, dy) на карте.
    Все повороты — только через неё: до 0.50 фонари смотрели от дороги, ящики и светофоры — не туда (BF-065)"""
    return round(math.degrees(math.atan2(dx, dy))) % 360

def P(pid, x, y, rot=0):
    props.append([pid, round(float(x), 2), round(float(y), 2), int(rot) % 360])

# ---------- дом: стены, двери, окна, комнаты, мебель ----------
DX4 = [(1, 0), (-1, 0), (0, 1), (0, -1)]
FV = {"N": (0, -1), "S": (0, 1), "W": (-1, 0), "E": (1, 0)}

def build_house(h):
    rects = h["rects"]
    F = set()
    part_of = {}
    for k, (x0, y0, x1, y1) in enumerate(rects):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if (x, y) not in F:
                    part_of[(x, y)] = k
                F.add((x, y))
    def inF(c): return c in F
    wall = {c for c in F if any((c[0] + dx, c[1] + dy) not in F for dx in (-1, 0, 1) for dy in (-1, 0, 1))}
    inner = F - wall
    kind = h["kind"]
    big = kind in ("магазин", "склад", "мэрия", "автовокзал", "больница", "амбар", "кафе", "контора")
    # перегородки между частями следа (Г, Т, П): по первому ряду/столбцу части, что примыкает к другой
    part_wall = set()
    doors_in = set()
    for k in range(1, len(rects)):
        line = [c for c in inner if part_of[c] == k and any(
            (c[0] + dx, c[1] + dy) in inner and part_of[(c[0] + dx, c[1] + dy)] < k for dx, dy in DX4)]
        if len(line) >= 3:
            line.sort()
            part_wall |= set(line)
            doors_in.add(line[len(line) // 2])
    # комнаты: деление прямоугольников частей (дом — комнаты от 3 клеток; большие — 1–2 раза)
    rooms_wall = set()
    def split(x0, y0, x1, y1, depth):
        w, hh = x1 - x0 + 1, y1 - y0 + 1
        lim = 18 if big else 8
        if depth > (1 if big else 3) or max(w, hh) < lim:
            return
        vertical = w >= hh
        n = w if vertical else hh
        for _ in range(8):
            cut = random.randint(3, n - 4) if not big else int(n * random.uniform(0.62, 0.75))
            if vertical:
                cells = [(x0 + cut, y) for y in range(y0, y1 + 1)]
                ends = [(x0 + cut, y0 - 1), (x0 + cut, y1 + 1)]
            else:
                cells = [(x, y0 + cut) for x in range(x0, x1 + 1)]
                ends = [(x0 - 1, y0 + cut), (x1 + 1, y0 + cut)]
            # конец новой стены не должен упираться в проём
            if any(e_ in doors_in for e_ in ends) or any(c in doors_in or c in part_wall for c in cells):
                continue
            rooms_wall.update(cells)
            doors_in.add(cells[random.randint(1, len(cells) - 2)])
            if vertical:
                split(x0, y0, x0 + cut - 1, y1, depth + 1)
                split(x0 + cut + 1, y0, x1, y1, depth + 1)
            else:
                split(x0, y0, x1, y0 + cut - 1, depth + 1)
                split(x0, y0 + cut + 1, x1, y1, depth + 1)
            return
    for k, (x0, y0, x1, y1) in enumerate(rects):
        cells = [c for c in inner if part_of[c] == k and c not in part_wall]
        if not cells:
            continue
        bx0, by0 = min(c[0] for c in cells), min(c[1] for c in cells)
        bx1, by1 = max(c[0] for c in cells), max(c[1] for c in cells)
        split(bx0, by0, bx1, by1, 0)
    iwall = (part_wall | rooms_wall) - doors_in
    floor = inner - iwall - doors_in
    # наружная дверь — на стене фасада, ближе к середине главного прямоугольника
    fdx, fdy = FV[h["front"]]
    mx0, my0, mx1, my1 = rects[0]
    midx, midy = (mx0 + mx1) / 2, (my0 + my1) / 2
    cand = []
    for c in wall:
        out = (c[0] + fdx, c[1] + fdy)
        inn = (c[0] - fdx, c[1] - fdy)
        if out in F or inn not in floor:
            continue
        lat = [(c[0] + fdy, c[1] + fdx), (c[0] - fdy, c[1] - fdx)]
        if not all(l in wall for l in lat):
            continue
        cand.append((abs(c[0] - midx) + abs(c[1] - midy), c))
    if not cand:
        return None
    # только на самой внешней стене фасада (у П и Т-образных — не во двор между крыльями)
    if fdx != 0:
        ext = max(c[0] for c in F) if fdx > 0 else min(c[0] for c in F)
        outer = [cd for cd in cand if cd[1][0] == ext]
    else:
        ext = max(c[1] for c in F) if fdy > 0 else min(c[1] for c in F)
        outer = [cd for cd in cand if cd[1][1] == ext]
    cand = outer or cand
    cand.sort()
    front_door = cand[0][1]
    ext_doors = [front_door]
    if big:
        # чёрный ход — на противоположной стене, ближе к середине
        back = []
        for c in wall:
            out = (c[0] - fdx, c[1] - fdy)
            inn = (c[0] + fdx, c[1] + fdy)
            if out in F or inn not in floor:
                continue
            lat = [(c[0] + fdy, c[1] + fdx), (c[0] - fdy, c[1] - fdx)]
            if all(l in wall for l in lat):
                back.append((abs(c[0] - midx) + abs(c[1] - midy), c))
        if back:
            ext_doors.append(sorted(back)[0][1])
    # окна: на прямых участках наружных стен, через одну-две клетки, не у дверей и углов
    windows = set()
    for c in wall:
        if c in ext_doors:
            continue
        for dx, dy in DX4:
            out = (c[0] + dx, c[1] + dy)
            inn = (c[0] - dx, c[1] - dy)
            if out in F or inn not in floor:
                continue
            lat = [(c[0] + dy, c[1] + dx), (c[0] - dy, c[1] - dx)]
            if not all(l in wall for l in lat):
                continue
            if any(l in ext_doors or l in windows for l in lat) and kind not in ("магазин", "кафе"):
                continue
            if any(l in ext_doors for l in lat):
                continue
            step = 2 if kind in ("магазин", "кафе") and (dx, dy) == (fdx, fdy) else (4 if kind in ("склад", "амбар") else 3)
            key = (c[0] if dx == 0 else c[1])
            if key % step == 0:
                windows.add(c)
    # пол: кухни/санузлы — плитка, остальное — доски; у магазинов, больницы, вокзала, мэрии — плитка
    tile_all = kind in ("магазин", "больница", "автовокзал", "мэрия", "кафе", "склад")
    grid = {}
    for c in floor:
        grid[c] = "t" if tile_all else "w"
    for c in iwall:
        grid[c] = "#"
    for c in wall:
        grid[c] = "#"
    for c in windows:
        grid[c] = "O"
    for c in doors_in:
        grid[c] = "d"
    for c in ext_doors:
        grid[c] = "D"
    # комнаты (связные куски пола без проёмов)
    rooms = []
    seen = set()
    for c in floor:
        if c in seen:
            continue
        q = deque([c]); seen.add(c); room = []
        while q:
            u = q.popleft(); room.append(u)
            for dx, dy in DX4:
                v = (u[0] + dx, u[1] + dy)
                if v in floor and v not in seen:
                    seen.add(v); q.append(v)
        rooms.append(room)
    rooms.sort(key=len, reverse=True)
    doorish = set(ext_doors) | doors_in
    def near_door(c):
        return any((c[0] + dx, c[1] + dy) in doorish for dx in (-1, 0, 1) for dy in (-1, 0, 1))
    def along_wall(c):
        return any(grid.get((c[0] + dx, c[1] + dy)) in ("#", "O") for dx, dy in DX4)
    def reachable_ok():
        start = (front_door[0] - fdx, front_door[1] - fdy)
        walk = {c for c, v in grid.items() if v in ("w", "t", "d")}
        if start not in walk:
            return False
        q = deque([start]); s = {start}
        while q:
            u = q.popleft()
            for dx, dy in DX4:
                v = (u[0] + dx, u[1] + dy)
                if v in walk and v not in s:
                    s.add(v); q.append(v)
        return len(s) == len(walk)
    def place(c, ch):
        if grid.get(c) not in ("w", "t") or near_door(c):
            return False
        old = grid[c]
        grid[c] = ch
        if not reachable_ok():
            grid[c] = old
            return False
        return True
    # мебель по видам; в больших комнатах — больше (вдоль стен через 2–3 клетки, ряды внутри)
    def wall_spots(room):
        sp = [c for c in room if along_wall(c)]
        sp.sort(key=lambda c: (c[1], c[0]))
        return sp
    def along(room, items, every):
        k = 0
        for i, c in enumerate(wall_spots(room)):
            if i % every == 0 and place(c, items[k % len(items)]):
                k += 1
    def rows(room, ch, seg=6, spacing=3):
        xs = [c[0] for c in room]; ys = [c[1] for c in room]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        rs = set(room)
        if (x1 - x0) >= (y1 - y0):
            for y in range(y0 + 2, y1 - 1, spacing):
                for x in range(x0 + 2, x1 - 1):
                    if (x - x0 - 2) % (seg + 2) < seg and (x, y) in rs:
                        place((x, y), ch)
        else:
            for x in range(x0 + 2, x1 - 1, spacing):
                for y in range(y0 + 2, y1 - 1):
                    if (y - y0 - 2) % (seg + 2) < seg and (x, y) in rs:
                        place((x, y), ch)
    def counter_at_door():
        inn = (front_door[0] - fdx * 2, front_door[1] - fdy * 2)
        for k2 in (2, 3, 4):
            place((inn[0] + fdy * k2, inn[1] + fdx * k2), "C")
    if kind in ("дом", "домик"):
        for ri, room in enumerate(rooms):
            spots = wall_spots(room)
            random.shuffle(spots)
            if ri == len(rooms) - 1 and len(rooms) > 1 or (len(rooms) == 1):
                for c in room:
                    grid[c] = "t"            # кухня: плитка, холодильник и стойки
                items = ["F", "C", "C"]
            elif ri == 0:
                items = ["S", "S", "W"]      # гостиная
            else:
                items = ["W", "S"]           # спальня
            for it in items:
                for c in spots:
                    if place(c, it):
                        spots.remove(c)
                        break
    elif kind == "магазин":
        rows(rooms[0], "R")
        counter_at_door()
        along(rooms[0], ["S"], 4)
        for room in rooms[1:]:
            along(room, ["R", "S"], 2)
    elif kind == "склад":
        rows(rooms[0], "R", seg=8, spacing=3)
        for room in rooms[1:]:
            along(room, ["S", "L"], 3)
    elif kind == "кафе":
        rows(rooms[0], "C", seg=2, spacing=3)       # столики
        counter_at_door()
        for room in rooms[1:]:
            for c in room:
                grid[c] = "t"
            along(room, ["F", "C", "F"], 2)
    elif kind in ("контора", "мэрия"):
        rows(rooms[0], "C", seg=2, spacing=3)       # столы
        along(rooms[0], ["S", "L", "W"], 3)
        for room in rooms[1:]:
            along(room, ["S", "C", "W"], 3)
    elif kind == "больница":
        counter_at_door()
        for room in rooms:
            along(room, ["M", "L", "W"], 3)
    elif kind == "автовокзал":
        counter_at_door()
        along(rooms[0], ["L", "L", "S"], 3)
    elif kind == "амбар":
        along(rooms[0], ["S", "S", "L"], 3)
    for c, v in grid.items():
        T[c[1], c[0]] = v
    h["door"] = front_door
    h["F"] = F
    return front_door

ok_doors = 0
for h in houses:
    if build_house(h) is not None:
        ok_doors += 1

# ======================= ДВОРЫ =======================
blocked = np.zeros((N, N), bool)      # клетки, где уже что-то стоит (для дворов и объектов)
blocked[T != "."] = True
blocked[on_road] = True
def free_cell(x, y):
    return 0 <= x < N and 0 <= y < N and not blocked[y, x]

def path_tiles(x, y, dx, dy, ch=None, maxlen=24):
    """Дорожка от клетки наружу (dx,dy) до самого края тротуара дороги (клетка касается полосы).
    None — упёрлась в дом, воду, мебель или край карты; по мощёному и траве идёт.
    До 0.50 останавливалась за 0.7 м до полосы и молча пропадала, если упиралась, — дорожки не доходили (BF-063)"""
    cells = []
    cx, cy = x, y
    for _ in range(maxlen):
        if not (0 <= cx < N and 0 <= cy < N):
            return None
        if road_d[cy, cx] < 0.5:
            return cells
        if T[cy, cx] not in (".", "-") or (cx, cy) in cells:
            return None
        cells.append((cx, cy))
        cx += dx; cy += dy
    return None

no_walk = []
for h in houses:
    if "door" not in h:
        continue
    zone, kind = h["zone"], h["kind"]
    fdx, fdy = FV[h["front"]]
    dx0, dy0 = h["door"]
    xs = [r[0] for r in h["rects"]] + [r[2] for r in h["rects"]]
    ys = [r[1] for r in h["rects"]] + [r[3] for r in h["rects"]]
    bx0, bx1, by0, by1 = min(xs), max(xs), min(ys), max(ys)
    walk = path_tiles(dx0 + fdx, dy0 + fdy, fdx, fdy)
    if walk is None:
        no_walk.append((h["zone"], h["kind"], h["door"], h["front"]))
        walk = []
    for (cx, cy) in walk:
        T[cy, cx] = "-"; blocked[cy, cx] = True
    if zone in ("Оук-Хилл", "Ривер-Сайд", "За мостом") and kind == "дом":
        # подъездная дорожка с машиной сбоку от дома (у половины домов)
        if random.random() < 0.55:
            side = random.choice([-1, 1])
            if fdy != 0:
                sx = bx1 + 2 if side > 0 else bx0 - 4
                cells = []
                ok = True
                for ddx in range(3):
                    col = path_tiles(sx + ddx, (by0 if fdy < 0 else by1) - fdy * 0, fdx, fdy)
                    if not col:
                        ok = False; break
                    cells += col
                if ok and len(cells) >= 9:
                    for (cx, cy) in cells:
                        T[cy, cx] = "-"; blocked[cy, cx] = True
                    # машина вдоль дорожки, в её середине
                    ys2 = sorted({c[1] for c in cells})
                    cy = ys2[len(ys2) // 2 - 1] if len(ys2) >= 3 else ys2[0]
                    if T[cy, sx + 1] == "-" and T[cy + 1, sx + 1] == "-":
                        T[cy, sx + 1] = "v"; T[cy + 1, sx + 1] = "x"
            else:
                sy = by1 + 2 if side > 0 else by0 - 4
                cells = []
                ok = True
                for ddy in range(3):
                    col = path_tiles((bx0 if fdx < 0 else bx1), sy + ddy, fdx, fdy)
                    if not col:
                        ok = False; break
                    cells += col
                if ok and len(cells) >= 9:
                    for (cx, cy) in cells:
                        T[cy, cx] = "-"; blocked[cy, cx] = True
                    xs2 = sorted({c[0] for c in cells})
                    cx = xs2[len(xs2) // 2 - 1] if len(xs2) >= 3 else xs2[0]
                    if T[sy + 1, cx] == "-" and T[sy + 1, cx + 1] == "-":
                        T[sy + 1, cx] = "c"; T[sy + 1, cx + 1] = "x"
        # почтовый ящик у дорожки, кусты у фасада, дерево во дворе
        if walk:
            ex, ey = walk[-1]                  # сбоку от дорожки у самого тротуара (клетка задевает его — потому
            mx, my = ex + fdy, ey + fdx        # не free_cell, а своя проверка: трава и центр не на тротуаре)
            if 0 <= mx < N and 0 <= my < N and T[my, mx] == "." and road_d[my, mx] >= 0.45 and not water[my, mx] \
                    and occ[my, mx] < 2 and not any(abs(p[1] - mx - 0.5) < 1 and abs(p[2] - my - 0.5) < 1 for p in props[-6:]):
                P("mailbox", mx + 0.5, my + 0.5, face(fdx, fdy)); blocked[my, mx] = True
        for k in range(random.randint(1, 3)):
            if fdy != 0:
                cx = random.randint(bx0, bx1); cy = (by0 - 1) if fdy < 0 else (by1 + 1)
            else:
                cy = random.randint(by0, by1); cx = (bx0 - 1) if fdx < 0 else (bx1 + 1)
            if free_cell(cx, cy) and abs(cx - dx0) + abs(cy - dy0) > 2:
                P("bush", cx + 0.5, cy + 0.5); blocked[cy, cx] = True
        for k in range(random.randint(1, 2)):
            if fdy != 0:
                cx = random.randint(bx0 - 2, bx1 + 2); cy = (by1 + random.randint(3, 6)) if fdy < 0 else (by0 - random.randint(3, 6))
            else:
                cy = random.randint(by0 - 2, by1 + 2); cx = (bx1 + random.randint(3, 6)) if fdx < 0 else (bx0 - random.randint(3, 6))
            if free_cell(cx, cy) and occ[cy, cx] == 0:
                P("tree", cx + 0.5, cy + 0.5, random.randint(0, 359)); blocked[cy, cx] = True

# Даунтаун: кварталы мощёные (тротуарная плитка), кроме площади — у неё своё
for i in range(len(AV) - 1):
    for j in range(len(ST) - 1):
        x0, x1 = AV[i] + 5, AV[i + 1] - 5
        y0, y1 = ST[j] + 5, ST[j + 1] - 5
        sub = T[y0:y1 + 1, x0:x1 + 1]
        m = (sub == ".") & (road_d[y0:y1 + 1, x0:x1 + 1] >= 0.5)
        sub[m] = "-"
# площадь мэрии и площадь вокзала — плитка
for (x0, y0, x1, y1) in (SQUARE, STATION_PLAZA):
    sub = T[y0:y1 + 1, x0:x1 + 1]
    m = (sub == ".") & (road_d[y0:y1 + 1, x0:x1 + 1] >= 0.5)
    sub[m] = "-"
# Промзона, Мейн-стрит-восток: асфальт перед зданиями
for h in houses:
    if h["kind"] in ("склад",) or h["zone"] == "Мейн-стрит":
        fdx, fdy = FV[h["front"]]
        xs = [r[0] for r in h["rects"]] + [r[2] for r in h["rects"]]
        ys = [r[1] for r in h["rects"]] + [r[3] for r in h["rects"]]
        bx0, bx1, by0, by1 = min(xs), max(xs), min(ys), max(ys)
        for x in range(bx0 - 2, bx1 + 3):
            for y in range(by0 - 2, by1 + 3):
                if 0 <= x < N and 0 <= y < N and T[y, x] == "." and road_d[y, x] > 0.75:
                    if (fdy < 0 and y < by0) or (fdy > 0 and y > by1) or (fdx < 0 and x < bx0) or (fdx > 0 and x > bx1):
                        T[y, x] = "-"
                    elif max(bx0 - x, x - bx1, by0 - y, y - by1) <= 2:
                        T[y, x] = "-"
        # мусорный контейнер и ящики у склада/магазина — сбоку
        cx, cy = (bx1 + 2, (by0 + by1) // 2) if random.random() < 0.5 else (bx0 - 2, (by0 + by1) // 2)
        if 0 <= cx < N and T[cy, cx] in ("-", "=", "."):
            P("dumpster", cx + 0.5, cy + 0.5, 90)
        if h["kind"] == "склад":
            for k in range(3):
                cx2, cy2 = cx + (k - 1) * 0, cy + (k - 1) * 2 + 3
                if 0 <= cy2 < N and T[cy2, cx] in ("-", "=", "."):
                    P("crate", cx + 0.5, cy2 + 0.5, random.randint(0, 359))

# Лес (юго-запад): деревья клетками, кроме участков и дорог
for _ in range(1600):
    x = random.randint(6, 140); y = random.randint(372, 494)
    if T[y, x] == "." and not on_road[y, x] and road_d[y, x] > 2 and occ[y, x] < 2 and not near_w[y, x]:
        if T[max(0, y - 1):y + 2, max(0, x - 1):x + 2].tolist().count("T") == 0 or random.random() < 0.15:
            T[y, x] = "T"
# Деревья по краю карты у шоссе и за озером — реже
for _ in range(500):
    x = random.randint(2, N - 3); y = random.randint(2, N - 3)
    if (x > 468 or y < 30 or (x < 18 and y > 200)) and T[y, x] == "." and road_d[y, x] > 3 and occ[y, x] < 2:
        T[y, x] = "T"

# Фермы: изгородь вокруг поля, ящики у амбара
for (fx, fy) in FARMS:
    x0, y0 = fx - 4, fy + 18
    x1, y1 = fx + 30, fy + 34
    if y1 > N - 3 or (occ[y0:y1, x0:x1] >= 2).any() or on_road[y0:y1, x0:x1].any() or (T[y0:y1, x0:x1] != ".").any():
        continue
    for x in range(x0, x1):
        for y in (y0, y1):
            if not (y == y1 and x in (fx + 12, fx + 13)):
                P("fence_wood", x + 0.5, y + 0.5, 0)
    for y in range(y0 + 1, y1):
        for x in (x0, x1 - 1):
            P("fence_wood", x + 0.5, y + 0.5, 90)

# Парк у озера: деревья, скамейки к озеру, фонари, урны вдоль дорожки
for (x0, y0, x1, y1) in PARKS:
    py = (y0 + y1) // 2
    for x in range(x0 + 2, x1 - 1):
        if T[py, x] == ".":
            T[py, x] = "-"
    for x in range(x0 + 4, x1 - 3, 9):
        P("tree", x + 0.5, y0 + 2.5, random.randint(0, 359))
        P("tree", x + 4.5, y1 - 2.5, random.randint(0, 359))
    for x in range(x0 + 8, x1 - 6, 18):
        P("bench", x + 0.5, py + 1.6, face(0, 1))           # к озеру
        P("lamp", x + 5.5, py - 0.8, face(0, 1))            # голова над дорожкой
        P("bin", x + 2.5, py + 1.6, 0)

# Площадь мэрии: деревья в углах, скамейки, фонари
sx0, sy0, sx1, sy1 = SQUARE
for (tx, ty) in [(sx0 + 2, sy0 + 2), (sx1 - 2, sy0 + 2), (sx0 + 2, sy1 - 2), (sx1 - 2, sy1 - 2)]:
    P("tree", tx + 0.5, ty + 0.5, random.randint(0, 359))
for x in range(sx0 + 5, sx1 - 4, 6):
    P("bench", x + 0.5, sy1 - 1.5, face(0, -1))             # лицом к мэрии
for (lx, ly) in [(sx0 + 1, (sy0 + sy1) // 2), (sx1 - 1, (sy0 + sy1) // 2)]:
    P("lamp", lx + 0.5, ly + 0.5, 0)

# ======================= УЛИЦЫ: фонари, деревья, гидранты, светофоры, «стоп» =======================
def on_asphalt(x, y, pad):
    """Точка на проезжей части какой-нибудь дороги (клетки под линиями — трава, по ним не узнать)"""
    for e in lines:
        for a2, b2 in segs(e):
            if seg_dist(np.array([x]), np.array([y]), a2, b2)[0] < HW[e[0]] + pad:
                return True
    return False

def try_prop(pid, x, y, rot, r=0.5):
    cx, cy = int(math.floor(x)), int(math.floor(y))
    if not (1 <= cx < N - 1 and 1 <= cy < N - 1):
        return False
    if on_asphalt(x, y, r):            # газетный автомат посреди перекрёстка (до 0.50, BF-065)
        return False
    if T[cy, cx] not in (".", "-", "=") or water[cy, cx]:
        return False
    for (pid2, px, py, _) in props[-400:]:
        if abs(px - x) < r + 0.4 and abs(py - y) < r + 0.4:
            return False
    P(pid, x, y, rot)
    return True

downtown = lambda x, y: 195 <= x <= 385 and 171 <= y <= 307
for e in lines:
    kind = e[0]
    for a, b in segs(e):
        ln = math.dist(a, b)
        if ln < 1:
            continue
        tx, ty = (b[0] - a[0]) / ln, (b[1] - a[1]) / ln
        nx, ny = -ty, tx
        step = 40.0 if kind == "highway" else 24.0
        s = step / 2
        k = 0
        while s < ln - 4:
            px, py = a[0] + tx * s, a[1] + ty * s
            side = 1 if k % 2 == 0 or kind == "highway" else -1
            off = (OW[kind] - 0.6) if kind != "bridge" else (HW[kind] + 0.4)
            if kind != "bridge" or True:
                # фонарь стоит на тротуаре/обочине, голова — к дороге
                if not any(seg_dist(np.array([px + nx * off * side]), np.array([py + ny * off * side]), a2, b2)[0] < HW[e2[0]] + 0.3
                           for e2 in lines for a2, b2 in segs(e2) if e2 is not e):
                    P("lamp", px + nx * off * side, py + ny * off * side, face(-nx * side, -ny * side))
            # деревья вдоль улиц посёлков — на газоне за тротуаром
            if kind == "street" and not downtown(px, py):
                for sd in (-1, 1):
                    qx, qy = px + tx * 12 + nx * (OW[kind] + 1.6) * sd, py + ty * 12 + ny * (OW[kind] + 1.6) * sd
                    ix, iy = int(qx), int(qy)
                    if 0 <= ix < N and 0 <= iy < N and T[iy, ix] == "." and occ[iy, ix] < 2 and road_d[iy, ix] > 0.8:
                        try_prop("tree", qx, qy, random.randint(0, 359))
            # гидранты и газетные автоматы в центре
            if kind == "street" and downtown(px, py) and k % 3 == 1:
                try_prop("hydrant", px + nx * (OW[kind] - 0.4), py + ny * (OW[kind] - 0.4), 0)
                try_prop("newsbox", px + tx * 4 - nx * (OW[kind] - 0.4), py + ty * 4 - ny * (OW[kind] - 0.4), face(nx, ny))
                try_prop("bin", px + tx * 7 - nx * (OW[kind] - 0.4), py + ty * 7 - ny * (OW[kind] - 0.4), 0)
            s += step
            k += 1
# светофоры на перекрёстках даунтауна
for x in AV:
    for y in ST:
        for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            # правостороннее движение: светофор на дальнем правом углу, лицом к подъезжающим
            try_prop("light", x + sx * 4.4, y + sy * 4.4, face(*{(1, -1): (0, 1), (1, 1): (-1, 0), (-1, 1): (0, -1), (-1, -1): (1, 0)}[(sx, sy)]))
# телефоны-автоматы и скамейки у площади и вокзала
for (x, y, fx, fy) in ((250.5, 222.5, 0, -1), (280.5, 256.2, 0, 1)):
    try_prop("phone", x, y, face(fx, fy))
try_prop("busstop", 295.0, 333.5, face(-1, 0))

# ======================= ЗАПИСЬ =======================
grid_rows = ["".join(T[y]) for y in range(N)]
data = {"v": 1, "w": N, "h": N, "spawn": [SPAWN[0], SPAWN[1]], "rows": grid_rows, "props": props, "lines": lines}
from collections import Counter
cnt = Counter(h["zone"] for h in houses)
print("домов:", len(houses), "с дверью:", ok_doors, dict(cnt))
print("без дорожки к улице:", len(no_walk), no_walk[:12])
print("объектов:", len(props), Counter(p[0] for p in props).most_common())
raw = "/tmp/city_raw.json"
json.dump(data, open(raw, "w"))
out = os.path.join(ROOT, "maps", "city.json")
res = subprocess.run([sys.executable, os.path.join(ROOT, "docs", "tools", "map_format.py"), raw], capture_output=True, text=True)
if res.returncode != 0:
    print(res.stderr)
    sys.exit(1)
open(out, "w").write(res.stdout)
print("записано:", out)
