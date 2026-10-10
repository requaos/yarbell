# Mahjong — Requirements

Requirements for the Mahjong game in the Yarbell collection. Gathered
2026-10-09 (decisions confirmed with the player). Mahjong is the third game,
after Tower Defense and Solitaire; its menu entry in `game/scripts/select.gd`
flips from disabled to `res://scenes/game/mahjong.tscn` once built.

## Variant

- **Mahjong solitaire** (tile matching, Shanghai-style) — *not* 4-player
  mahjong. Match pairs of free identical tiles to clear a layered layout.

## Tile set (144)

- 3 suits — dots, bamboo, characters — ranks 1–9, **4 of each** tile (108).
- Winds E/S/W/N ×4 (16); dragons red/green/white ×4 (12).
- 4 flowers + 4 seasons, **1 of each** (8). Flowers match any flower; seasons
  match any season (group matching); flowers and seasons do not match.

## Free tile & matching

- A tile is **free** when no tile lies on top of it and at least one of its
  immediate left / right neighbours (same layer) is absent.
- Two free tiles match when they are the same suit tile / honour, or belong to
  the same flower-or-season group. Matching removes both.

## Layouts (v1)

Three layouts, selectable in the shared Options modal (applies on next game,
choice persists):

- **Turtle** — the classic 144-tile layered silhouette (base, pinched rows,
  upper tiers, top cap).
- **Pyramid** — 92 tiles, two stacked plateaus; quicker game.
- **Gate** — 72 tiles, a hollow frame with a raised lintel; quickest game.

Deals are random (tiles shuffled into the layout by pairs). Some deals are
unwinnable, as in classic mahjong solitaire and Klondike — rescued by Shuffle.

## Deadlock

- **Auto-detected** after every removal and right after the deal.
- When tiles remain but no matching free pair exists, a prompt offers
  **SHUFFLE** (rearrange the remaining tiles in place) or **NEW GAME**.
- Shuffle keeps tile positions and re-deals the remaining kinds randomly;
  unlimited uses; it snapshots like a move, so undo restores the pre-shuffle
  board. (A shuffle can itself deadlock; the prompt simply re-appears.)

## Features (first version)

Mirrors Solitaire's scope:

- **Unlimited undo** back to the deal; **no redo**.
- **Hint** — highlight one available matching pair briefly.
- **Tap-to-match**: tap a free tile to select (gold highlight); tap a matching
  free partner to remove both. Tapping a non-match flashes invalid and selects
  the new tile instead; tapping the selected tile deselects.
- Win: all tiles removed — "YOU WIN" overlay with a New Game button.

Explicitly **out of scope** for v1: scoring, timer/move counter, statistics,
solvable-only deals, extra layouts beyond the three above, elaborate
animations beyond the removal pop.

## Presentation

- Procedural neon tiles drawn in code (rounded body, suit-coloured border and
  pips/glyphs), matching the app's `Palette` aesthetic — **no image assets**.
  Layer depth is conveyed by an offset edge (higher layers shifted up/right).
- Same 1280×720 landscape viewport as the rest of the app. HUD is a left-edge
  button rail (NEW / UNDO / HINT / MENU) in the board's left margin, per the
  Solitaire toolbar fix.
- Layout picker lives in the shared Options modal in a "— MAHJONG —" section
  (same pattern as Solitaire's draw/redeal settings), persisted in
  `user://settings.cfg` via the `Settings` autoload.

## State / architecture notes

- Pure-logic `MahjongState` (RefCounted, no autoload references) + static
  `MahjongLayouts` cell tables, headless-tested in `test_state.gd` — same
  separation as `SolitaireState`.
- Board (`Node2D`, group "game") owns input, tile views, hint/undo/shuffle,
  overlays, and the Options-modal hooks (`set_brightness`,
  `build_settings_section`).
