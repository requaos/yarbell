class_name Difficulty
extends RefCounted
## Static per-level difficulty tuning. Difficulty rises smoothly and the total
## enemy count is balanced against the number of tower sites, so more sites also
## means more enemies.

static func config_for(level: int) -> Dictionary:
	var sites := clampi(3 + (level - 1) / 2, 3, 8)
	var total_enemies := roundi((6.0 + 2.0 * (level - 1)) * (1.0 + 0.2 * (sites - 3)))
	var enemy_hp := roundi(10.0 * (1.0 + 0.15 * (level - 1)))
	var enemy_speed := 4.5 + 0.1 * (level - 1)   # larger maze map -> faster movement to keep pace
	var spawn_interval := maxf(0.4, 1.2 - 0.05 * level)
	return {
		"secondary_sites": sites,
		"total_enemies": total_enemies,
		"enemy_hp": enemy_hp,
		"enemy_speed": enemy_speed,
		"spawn_interval": spawn_interval,
	}
