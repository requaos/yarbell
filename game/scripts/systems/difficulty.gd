class_name Difficulty
extends RefCounted
## Static per-level difficulty tuning. Enemies grow bigger, stronger, and more
## numerous as levels rise; the number of tower sites grows too (weighted so the
## player has more towers to work with, but they start inactive).

## Weighted breed pool for a level: blobs only at first, runners join early,
## brutes then spikes broaden the mix as levels rise (same weighted-list pattern
## as the tower-type pool in level.gd).
static func _breed_pool(level: int) -> Array:
	if level <= 1:
		return [Enemy.Form.BLOB]
	var pool: Array = [
		Enemy.Form.BLOB, Enemy.Form.BLOB, Enemy.Form.BLOB, Enemy.Form.BLOB,
		Enemy.Form.RUNNER, Enemy.Form.RUNNER]
	if level >= 4:
		pool.append(Enemy.Form.BRUTE)
	if level >= 6:
		pool.append_array([Enemy.Form.SPIKE, Enemy.Form.SPIKE, Enemy.Form.BRUTE])
	if level >= 9:
		pool.append_array([Enemy.Form.RUNNER, Enemy.Form.SPIKE])
	return pool

static func config_for(level: int) -> Dictionary:
	var sites := clampi(6 + (level - 1) * 2, 6, 18)
	var total_enemies := roundi((5.0 + 1.9 * (level - 1)) * (1.0 + 0.05 * (sites - 6)))
	var enemy_hp := roundi(10.0 * (1.0 + 0.22 * (level - 1)))
	var enemy_damage := 3 + (level - 1)
	var enemy_speed := 4.5 + 0.1 * (level - 1)
	var enemy_scale := minf(2.2, 1.0 + 0.06 * (level - 1))
	var spawn_interval := maxf(0.3, 1.15 - 0.07 * level)
	# Waves ramp faster with level and wave gaps tighten, so later levels keep
	# up the pressure. Each wave ends in a mini-boss; the final wave a full boss.
	var waves := clampi(2 + level * 2 / 3, 2, 8)
	var intermission := maxf(1.2, 3.0 - 0.18 * (level - 1))
	# Weaker enemies read red; stronger ones shift toward a hot white/gold.
	var heat := clampf((level - 1) / 12.0, 0.0, 1.0)
	var enemy_color := Palette.RED.lerp(Color(1.0, 0.85, 0.4), heat)
	return {
		"secondary_sites": sites,
		"total_enemies": total_enemies,
		"waves": waves,
		"intermission": intermission,
		"enemy_hp": enemy_hp,
		"enemy_damage": enemy_damage,
		"enemy_speed": enemy_speed,
		"enemy_scale": enemy_scale,
		"enemy_color": enemy_color,
		"spawn_interval": spawn_interval,
		"breed_pool": _breed_pool(level),
	}
