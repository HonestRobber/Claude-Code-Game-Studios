# PROTOTYPE - NOT FOR PRODUCTION — Iso Survival

**Hypothesis:** a readable isometric survival loop — move, loot a house, evade one
zombie — can be built and verified end to end (import, run, rendered screenshots)
in a headless cloud container with Godot 4.7.2 and the Compatibility renderer.

**Status:** in-progress — first playable, accepted as an experimental milestone 2026-11-12 (27/27 checks; evidence in `production/qa/evidence/iso-survival/`). Original placeholder geometry only.

## Run

```bash
godot --path prototypes/iso-survival            # play (needs a display)
# Scripted gameplay check, no rendering (fast, ~1 s):
godot --headless --path prototypes/iso-survival --fixed-fps 60 -- --autopilot
# Rendered check + 1280x720 screenshots in a headless container (~2.5 min on llvmpipe):
xvfb-run -a -s "-screen 0 1280x720x24" godot --path prototypes/iso-survival \
  --display-driver x11 --rendering-method gl_compatibility --rendering-driver opengl3 \
  --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -- --autopilot --shots=<abs dir>
```

Exit code = number of failed checks. Run `godot --headless --path . --import` once after a fresh clone.

Controls: WASD/arrows move (8 directions, screen-relative) · E interact · H bandage · R restart.

## Contents

- `data/tuning.json` — speeds, ranges, damage, loot table, item names/colours, ground-loot spawns.
- `scripts/main.gd` bootstrap · `level_builder.gd` map, house (cutaway walls + roof), navmesh ·
  `player.gd` · `zombie.gd` (idle/wander/chase/attack, NavigationAgent3D) · `loot_container.gd` ·
  `pickup.gd` · `inventory.gd` · `hud.gd` · `iso_camera.gd` (orthographic, 45°/35.26°) ·
  `autopilot.gd` (drives real input actions, asserts, captures screenshots).

## Findings so far

- NavigationAgent3D stalls on its first waypoint unless `path_height_offset` matches the
  baked navmesh surface height (~0.5 here): the 3D waypoint distance never drops below
  `path_desired_distance`.
- Headless (`--headless`) runs game logic but renders nothing — screenshots need Xvfb + opengl3.
- Loot uses its own RNG stream so screenshot timing cannot change what a container yields.
