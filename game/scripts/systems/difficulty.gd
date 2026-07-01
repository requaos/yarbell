class_name Difficulty
extends RefCounted
## Static per-level difficulty tuning. Enemies grow bigger, stronger, and more
## numerous as levels rise; the number of tower sites grows too (weighted so the
## player has more towers to work with, but they start inactive).

static func config_for(level: int) -> Dictionary:
	var sites := clampi(6 + (level - 1) * 2, 6, 18)
	var total_enemies := roundi((5.0 + 1.6 * (level - 1)) * (1.0 + 0.05 * (sites - 6)))
	var enemy_hp := roundi(10.0 * (1.0 + 0.22 * (level - 1)))
	var enemy_damage := 3 + (level - 1)
	var enemy_speed := 4.5 + 0.1 * (level - 1)
	var enemy_scale := minf(2.2, 1.0 + 0.06 * (level - 1))
	var spawn_interval := maxf(0.35, 1.1 - 0.05 * level)
	# Weaker enemies read red; stronger ones shift toward a hot white/gold.
	var heat := clampf((level - 1) / 12.0, 0.0, 1.0)
	var enemy_color := Palette.RED.lerp(Color(1.0, 0.85, 0.4), heat)
	return {
		"secondary_sites": sites,
		"total_enemies": total_enemies,
		"enemy_hp": enemy_hp,
		"enemy_damage": enemy_damage,
		"enemy_speed": enemy_speed,
		"enemy_scale": enemy_scale,
		"enemy_color": enemy_color,
		"spawn_interval": spawn_interval,
	}
