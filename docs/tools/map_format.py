#!/usr/bin/env python3
"""Черновик карты (JSON из Supabase map_drafts.data или файл) → текст maps/city.json в принятом виде.

Запуск:  python3 docs/tools/map_format.py draft.json > maps/city.json
Формат тот же, что пишет GameWorld.map_text(): ряды клеток и объекты — по одному на строку,
чтобы каждое изменение карты было видно в истории коммитов. Проверка карты — автотесты (--audit).
"""
import json
import sys

CHARS = ".=-wt#DdO?T!FCWSMLRcvx"   # как GameWorld.MAP_CHARS


def num(v):
    v = round(float(v), 2)
    return int(v) if v == int(v) else v


def main():
    d = json.load(open(sys.argv[1], encoding="utf-8"))
    if "data" in d and "rows" not in d:
        d = d["data"]                 # строка таблицы целиком
    w, h, rows = int(d["w"]), int(d["h"]), d["rows"]
    assert len(rows) == h, "рядов должно быть %d" % h
    for y, r in enumerate(rows):
        assert len(r) == w, "ряд %d: должно быть %d клеток" % (y, w)
        bad = set(r) - set(CHARS) | (set(r) & set("?!"))
        assert not bad, "ряд %d: неизвестные символы %s" % (y, bad)
    out = '{"v": 1, "w": %d, "h": %d, "spawn": %s,\n"rows": [\n' % (w, h, json.dumps([num(x) for x in d["spawn"]]))
    out += ",\n".join(json.dumps(r) for r in rows) + "\n],\n\"props\": [\n"
    out += ",\n".join(json.dumps([p[0], num(p[1]), num(p[2]), int(round(float(p[3])))], ensure_ascii=False) for p in d["props"])
    lines = [l for l in d.get("lines", []) if len(l) >= 5]
    if lines:                         # дороги-линии (с 0.38): вид и точки, по одной дороге на строку
        out += "\n],\n\"lines\": [\n"
        out += ",\n".join(json.dumps([l[0]] + [num(v) for v in l[1:]]) for l in lines)
    out += "\n]}\n"
    sys.stdout.write(out)


if __name__ == "__main__":
    main()
