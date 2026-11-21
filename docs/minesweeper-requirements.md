# Minesweeper — Requirements

Requirements for the Minesweeper game in the Yarbell collection. Gathered
2026-11-21 (decisions confirmed with the player). Minesweeper is the fourth
game, after Tower Defense, Solitaire and Mahjong; its menu entry in
`game/scripts/select.gd` launches `res://scenes/game/minesweeper.tscn`.

## Difficulties (v1)

Classic three, selectable in the shared Options modal (applies on next game,
choice persists):

- **Beginner** — 9×9, 10 mines.
- **Intermediate** — 16×16, 40 mines.
- **Expert** — 30×16, 99 mines.

## Core rules

- **First reveal is always safe**: mines are placed after it, excluding the
  3×3 neighbourhood of the first revealed cell (classic modern behaviour), so
  the opening move floods a region rather than risking a corner-number start.
- Revealing a zero cell **flood-fills** the connected zero region, revealing
  the numbered frontier around it.
- **Flags** mark suspected mines; flagged cells cannot be revealed. Flagging
  is allowed before the first reveal.
- **Chording**: tapping a revealed number whose surrounding flag count equals
  the number opens all its unflagged neighbours — which can hit a mine.
- **Win**: every safe (non-mine) cell revealed. On win the remaining mines
  display as flagged (classic).
- **Loss**: revealing a mine. The board reveals all mines, marks wrongly
  flagged safe cells with an X, and highlights the exploded cell.
- **Mine counter**: total mines minus flags placed (may go negative). No
  timer — the collection stays relaxed (matches Solitaire/Mahjong).

## Interactions

- **Tap** a covered cell: reveals it (or flood/chord per rules above).
- **FLAG toggle button** in the HUD rail switches taps to flag/unflag mode
  (discoverable, no timing gesture). The button shows gold while active.
- Tapping a revealed number with no satisfied flags does nothing.

## Features (first version)

- New game at any time from the rail; difficulty changes apply on the next
  new game.
- Win overlay ("YOU WIN" + New Game) and loss overlay ("BOOM" + New Game,
  light dim so the final board stays readable).

Explicitly **out of scope** for v1: timer and best times, undo (classic
minesweeper has none), hint/solver, long-press flagging, custom board sizes,
cell animations.

## Presentation

- Procedural neon grid drawn in code: raised covers vs recessed revealed
  cells, classic 1–8 count colours remapped to the app palette, gold flag
  pennants, red mines, red X for wrong flags. The whole grid renders as one
  canvas item (no per-cell nodes) — the expert board is 480 cells.
- Same 1280×720 landscape viewport. HUD is the left-edge rail (NEW / FLAG /
  MENU) with the mine counter beneath it; the grid is sized per difficulty to
  fit the space right of the rail (Beginner 64px cells, Intermediate ~42px,
  Expert ~37px).

## State / architecture notes

- Pure-logic `MinesweeperState` (RefCounted, no autoload references) with a
  debug hook to place explicit mine sets, headless-tested in `test_state.gd` —
  same separation as `SolitaireState` / `MahjongState`.
- Board (`Node2D`, group "game") draws the grid and handles input; the shared
  Options modal gets a "— MINESWEEPER —" difficulty section (same pattern as
  the Solitaire and Mahjong sections).
