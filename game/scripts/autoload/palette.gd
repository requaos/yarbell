extends Node
## Neon / synthwave palette and emissive-material factory.
## Autoloaded as "Palette". Colors are authored in sRGB; the factory pushes
## emission energy above 1.0 so the WorldEnvironment glow blooms them.

const BG_DEEP := Color("0a0a1a")
const CYAN := Color("00fff2")
const MAGENTA := Color("ff2bd6")
const PURPLE := Color("a24bff")
const GOLD := Color("ffd447")
const RED := Color("ff3b6b")
const GRID := Color("1b2a4a")

## Build a self-illuminated material that glows: dark albedo, bright emission.
## `energy` > 1.0 crosses the glow HDR threshold and blooms.
func emissive(color: Color, energy: float = 3.0, unshaded: bool = true, alpha: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.darkened(0.7), alpha)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
