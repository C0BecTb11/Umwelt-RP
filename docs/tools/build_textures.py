#!/usr/bin/env python3
"""Собирает текстуры мира в одну полосу assets/tex/world_albedo.png (слои 512×512 сверху вниз).
Источник — папка Textures набора Quaternius «Downtown City MegaKit» (лицензия CC0).
Запуск: python3 docs/tools/build_textures.py путь/к/Textures
Печатает средние яркости слоёв (линейные) — они записаны в shaders/world.gdshader (MEAN)."""
import sys, os
from PIL import Image

SIZE = 512
# порядок = номер слоя в шейдере (Mesher: mat = слой + 1)
LAYERS = [
	("T_RedBrick_BaseColor.png", "кирпич"),
	("T_Concrete_BaseColor.png", "бетон / штукатурка"),
	("T_Concrete_Asphalt_BaseColor.png", "асфальт"),
	("T_MarbleFloor_BaseColor.png", "мрамор (плитка пола)"),
	("T_RoofSlate_BaseColor.png", "черепица"),
	("T_lit_interior_1.png", "комната за окном (свет)"),
	("T_dark_interior.png", "комната за окном (темно)"),
	("T_Dirt_BaseColor.png", "земля (узор травы)"),
]

def lin(v):
	v /= 255.0
	return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

def main():
	src = sys.argv[1]
	out = Image.new("RGB", (SIZE, SIZE * len(LAYERS)))
	for i, (name, what) in enumerate(LAYERS):
		im = Image.open(os.path.join(src, name)).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
		out.paste(im, (0, i * SIZE))
		small = im.resize((64, 64), Image.BOX)
		b = small.tobytes()
		px = [tuple(b[j:j + 3]) for j in range(0, len(b), 3)]
		mean = [sum(lin(p[k]) for p in px) / len(px) for k in range(3)]
		print("%d %-40s %s  средн. %.3f %.3f %.3f" % (i, name, what, *mean))
	dst = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "tex", "world_albedo.png")
	out.save(os.path.normpath(dst), optimize=True)
	print("записано", os.path.normpath(dst))

main()
