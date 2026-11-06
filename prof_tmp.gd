extends SceneTree
func _initialize() -> void:
	for spread in [false, true]:
		for n in [50, 150, 300, 500]:
			var g := GameState.new_game(1)
			g.players.clear()
			for i in n:
				var p := g.join_player("uid-prof-%05d-xxxxxxxx" % i, "P%d" % i)
				if spread:
					var c := Vector2(randf_range(2, g.world.w - 2), randf_range(2, g.world.h - 2))
					p.pos = g.unstick(c, GameState.PLAYER_R)
				else:
					p.pos = g.spawn + Vector2(randf_range(-9, 9), randf_range(-6, 6))
			var t0 := Time.get_ticks_usec()
			g.index_players(true)
			var vis := 0
			var bytes := 0
			for p in g.players:
				var o := g.state_for(p.id)
				vis += (o["p"] as PackedFloat32Array).size() / 10 - 1
				bytes += var_to_bytes(o).size()
			var t1 := Time.get_ticks_usec()
			for p in g.players:
				g.events_for(p.id, true)
			var t15 := Time.get_ticks_usec()
			for p in g.players:
				g.state_for(p.id)
				g.events_for(p.id, true)
			var t2 := Time.get_ticks_usec()
			var t3 := Time.get_ticks_usec()
			for p in g.players:
				g.player_data(p)
			var t4 := Time.get_ticks_usec()
			g.grid_on = false
			print("%s %d игроков (видно в среднем %d): снимки %.1f мс (%d КБ), полные данные: первый круг %.1f мс, дальше %.1f мс (из них свои данные %.1f)" % ["по всей карте" if spread else "все в одном месте", n, vis / n, (t1 - t0) / 1000.0, bytes / 1024, (t15 - t1) / 1000.0, (t2 - t15) / 1000.0, (t4 - t3) / 1000.0])
	quit()
