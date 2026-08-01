# Solitaire — Requirements

Requirements for the Solitaire game in the Yarbell collection. Gathered
2026-08-01. Solitaire is the next game to build after the game-selection hub;
its menu entry in `game/scripts/select.gd` flips from disabled to
`res://scenes/game/solitaire.tscn` once built.

## Variant

- **Klondike** ("regular" solitaire). No Spider/FreeCell/other variants.
- 7 tableau columns, 4 foundations (one per suit, built up A→K by suit),
  1 stock pile, 1 waste pile.
- Standard deal: column *n* gets *n* cards, top card face-up, rest face-down;
  remaining 24 cards form the stock.

## Core rules

- **Tableau build:** down in rank, alternating colour (red on black, black on red).
- **Foundation build:** up in rank by suit, starting at Ace, ending at King.
- **Moving runs:** a valid descending alternating-colour run can be moved as a unit
  between tableau columns.
- **Empty column:** only a King (or a King-led run) may be placed on an empty
  tableau column (classic Klondike).
- **Win condition:** all 52 cards on the foundations.
- **Loss:** no scoring penalty; player may start a new deal at any time. Deals can
  be unwinnable (see Deals).

## Draw / stock (player settings)

Both configurable — see **Settings** below.

- **Draw count:** 1 card or 3 cards flipped from stock to waste per tap. In draw-3,
  only the top waste card is playable.
- **Redeals (stock recycling):** *unlimited* or *limited*. When limited, follow the
  classic rule — unlimited passes in draw-1, but capped at **3 passes** in draw-3,
  after which the stock locks.
- Setting changes take effect on the **next new game**, not mid-deal. *[default]*

## Interactions

Three ways to move cards, all supported:

1. **Drag-and-drop** — pick up a card or a valid run and drag it to a destination
   pile; snaps back if the drop is illegal.
2. **Tap-to-move** — tap a card/run to select (highlighted), then tap a destination
   pile to place it. Tapping the same card again, or empty space, deselects.
3. **Double-tap auto-move** — sends the card to its **foundation** if it fits there;
   otherwise to a **valid tableau column**; otherwise no move (snaps/ignores).
   - *[default]* When multiple tableau targets exist, pick deterministically
     (e.g. leftmost valid, preferring a non-empty column over creating a new gap).

Tapping the **stock** draws to the waste (respecting draw count). Tapping an empty
stock recycles the waste (respecting the redeal setting).

## Features (first version)

- **Unlimited undo** — undo any number of moves back to the initial deal. **No redo**
  (classic).
- **Auto-complete** — once every card is face-up and only foundation moves remain,
  the game **automatically** flies all cards home to win (classic Windows-Solitaire
  behaviour), no button press needed.
- **Hint** — highlight one available legal move. *[default: surface any legal move;
  "best move" ranking not required.]*

Explicitly **out of scope** for v1:

- **No scoring** (relaxed play) — win/loss only. No standard or Vegas scoring.
- **No timer or move counter** display.
- No redo, no statistics/history persistence.

## Deals

- **Random shuffle** — standard 52-card shuffle; some deals will be unwinnable, as
  in classic Klondike. No solver / no winnable-only guarantee in v1.

## Presentation

- **Card visuals:** procedural neon, drawn in code (rounded rects, rank + suit pips)
  matching the existing `Palette`/glow aesthetic. **No image assets.** Consistent
  with Tower Defense's asset-free procedural style.
- **Orientation/layout:** keep the existing **1280×720 landscape** viewport (same as
  the rest of the app — no per-scene viewport/orientation changes). Foundations +
  stock/waste on the top row, 7 tableau columns below.
- **Win flow:** *[default]* reuse the neon overlay style from the tower-defense HUD
  (`game/scripts/hud.gd` `_show_overlay`) — a "YOU WIN" overlay with a New Game
  button. A New Game / restart control is also available during normal play.

## Settings placement

Draw-count and redeal options live in the **shared Options modal**
(`game/scripts/options_modal.gd`), in a per-game section that appears **only while
in Solitaire**. The modal keeps Brightness / Music / SFX for all games and gains a
"— SOLITAIRE —" section with Draw (1/3) and Redeals (∞ / limited) controls.

- Implementation note: this requires the currently-TD-only modal to support an
  optional game-specific settings section. Likely approach — the active game scene
  (in group `"game"`, like `game.gd` already is) exposes its settings controls to
  the modal, mirroring the existing `set_brightness` hook pattern. To be finalized
  at plan time.

## State / architecture notes (for the build phase)

- Per the hub convention, Solitaire owns its **own state** (a `SolitaireState` /
  scene-local model), not the tower-defense `GameState`.
- Reuses the shared layer: `Palette`, `Audio`, `Settings`, the Options modal, and
  `NeonUI` helpers.
- Draw/redeal preferences are game-agnostic-ish player settings — decide at plan
  time whether they live on the `Settings` autoload or a Solitaire-specific store.

## Resolved decisions (classic defaults)

All previously-open items resolved to classic Klondike behaviour:

1. **Empty-column rule:** King-only.
2. **Limited-redeal cap:** 3 passes in draw-3 (unlimited in draw-1).
3. **Auto-complete:** fully automatic once eligible (no button).
4. **Undo:** unlimited undo, no redo.
5. **Settings persistence:** draw/redeal preferences **persist across app launches**
   (classic — the game remembers your choice). Note: nothing in the app currently
   persists settings to disk, so this introduces the app's first on-disk preference
   store (e.g. Godot `user://` config), to be designed at plan time.
