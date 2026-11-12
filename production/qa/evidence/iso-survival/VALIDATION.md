# Iso Survival prototype — gameplay validation

| | |
|---|---|
| Date | 2026-11-12 (final rendered run 04:40–04:43 UTC) |
| Engine | Godot v4.7.2.stable.official.ed1daf0bf (official build, SHA-512 verified against the release's `SHA512-SUMS.txt`) |
| Renderer | `gl_compatibility` / OpenGL 4.5 Core, Mesa 25.2.8, **llvmpipe** software rasteriser (LLVM 20.1.2) |
| Display | Xvfb `1280x720x24`, `--fixed-fps 60` |
| Result | **27 checks, 0 failures**, exit code 0 (wall time 2m22s) |
| Driver | `scripts/autopilot.gd` — presses real input actions, asserts state, captures the frames below |

Command (from the repo root):

```bash
xvfb-run -a -s "-screen 0 1280x720x24" godot --path prototypes/iso-survival \
  --display-driver x11 --rendering-method gl_compatibility --rendering-driver opengl3 \
  --audio-driver Dummy --resolution 1280x720 --fixed-fps 60 -- --autopilot --shots=<abs dir>
```

Headless (logic only, no images, ~1 s): `godot --headless --path prototypes/iso-survival --fixed-fps 60 -- --autopilot`

## Check output (verbatim)

```text
CHECK PASS  start: zombie not hostile  idle
CHECK PASS  start: inventory empty  {  }
CHECK PASS  8-dir: W+D moves screen up-right  move_dir=(0.0, 0.0, -1.0) expect=(0.0, 0.0, -1.0)
CHECK PASS  walk to bandage  (2.225826, 0.0, 6.299179)
CHECK PASS  bandage targeted  Pick up Bandage
CHECK PASS  pickup: bandage in inventory  { "bandage": 1 }
CHECK PASS  walk to (-1.0, 0.0, 1.5)  (-0.903122, 0.0, 1.745235)
CHECK PASS  walk to (-1.0, 0.0, -1.0)  (-0.903122, 0.0, -0.729766)
CHECK PASS  walk to (-3.6, 0.0, -4.4)  (-3.501742, 0.0, -4.153385)
CHECK PASS  house: player inside  
CHECK PASS  house: roof hidden  
CHECK PASS  cabinet targeted  Cabinet
CHECK PASS  search: in progress  progress=0.32
CHECK PASS  search: completed  
CHECK PASS  search: 3 items added  { "bandage": 2, "canned_beans": 1, "scrap_metal": 1 }
CHECK PASS  walk to (-1.0, 0.0, -1.0)  (-1.115254, 0.0, -1.241896)
CHECK PASS  walk to (-1.0, 0.0, 1.6)  (-1.115254, 0.0, 1.383104)
CHECK PASS  walk to (5.0, 0.0, 3.0)  (4.772704, 0.0, 2.921063)
CHECK PASS  house: roof back after exit  
CHECK PASS  zombie: starts chasing  CHASING at 8.9 m
CHECK PASS  zombie: closes distance  8.93 -> 7.28 m
CHECK PASS  zombie: attack damages player  hp 100 -> 90, state ATTACKING
CHECK PASS  heal: one bandage used, HP up  bandages 2 -> 1, hp 90 -> 100
CHECK PASS  escape: zombie gives up  idle at 12.9 m
CHECK PASS  death: player dies at 0 HP  hp=0 alive=false
CHECK PASS  death: zombie stops attacking  idle
CHECK PASS  death: no movement while dead  (0.0, 0.0, 0.0)
AUTOPILOT RESULT: 27 checks, 0 failures
```

## Screenshots (1280×720, captured during the run above, each inspected by eye)

| File | Shows |
|---|---|
| `01_start.png` | Spawn: survivor on path, house with roof, two ground pickups, HUD idle |
| `02_interior.png` | Inside: roof hidden, camera-facing walls cut away, furniture, "[E] Search Cabinet" |
| `03_searching.png` | Search in progress — prompt plus progress bar |
| `04_looted.png` | Cabinet opened, toast "Found: Canned Beans, Bandage, Scrap Metal", inventory (4) |
| `05_chase.png` | Zombie CHASING at 7 m, red "!" marker, facing the player |
| `06_attacked.png` | Zombie ATTACKING at 1 m, HP 90 |
| `07_dead.png` | Death overlay "YOU DIED / press R to restart", HP 0 |

Not covered by this run: human play-feel, the R restart path, a chase through the door, other random seeds.

## Integrity

Every source file below was last modified before the first screenshot of the run was written,
so these hashes identify the exact code the screenshots and results came from.

```text
bbf13cb4c496a036b2cb5133999e7d2a3953359faa2830d731d476b76db6f128  project.godot
64fe18a0958e1fef9ff9ec8f3c85e59e993ca24463f9a3f23c77669fc1762313  main.tscn
1a3214e047b568f54f1689b962d6c70a3ab14a45d19cb665e18e1ff4f11a9688  data/tuning.json
86e78fc99a170f35594e37195e334e641db2ae808914175baf536b8e96161439  scripts/autopilot.gd
efb440f69cd784cce4c592184bc590607f8b7ecf9c0b03f68f580051a6368232  scripts/hud.gd
5db4055fa194a1e40590ff8b9877c6b761b38269326283387b76e5e1910e2889  scripts/inventory.gd
e1163e6840208c7045d66a59711df875d52306c026213c9aa52682b9f8871421  scripts/iso_camera.gd
60b00668a69c292996035fc7de61e09245df44033ca4a608eb7e2dfce185384c  scripts/level_builder.gd
4c9fc44e5bd082270f6d7fa1ead72034a2df9366db60bb81a4959490fa7f9e2c  scripts/loot_container.gd
ad147e450ff60f72843b6bfe228b2a3473f33337db89232a5fd836400a123715  scripts/main.gd
a4a85e0fa8af59ebc9b73849f177651b0fd6c21b81663b9f30ad5256fad94653  scripts/pickup.gd
86aa63ebc1f7fdc2cab1c34de236d52ad994c5cb79306e953b6c1dba6f5c694c  scripts/player.gd
51ea60a1a5b0c11b71b3a72ef4b783b49feebde8446c72ca4863e4e733b44537  scripts/util.gd
e00ca17557b67db5c1266440e7207a2f607e95bf30faa3bcc55a88c4db0a782e  scripts/zombie.gd

aaac90fa00acb98268702a5851199bf0de7ad560ce4308130b6fdb402ed69b77  01_start.png
00767cf119b3a89c8e674b20382734625101b635979d4e928031009a9ff12595  02_interior.png
5915734809544b726c4edc059455d3881b1eb9be23e08f1c1f802bf67ceea699  03_searching.png
7594c9eec5e4f5f9108d8eed2f57fd0aea2977e2db4068662b70d22e90117b9d  04_looted.png
9238914b43d9f6926502f4e38c8afba74340abc05e490cfe7ceaf36788058c85  05_chase.png
a5223b625074a0c782c92ac1fef5f8800fd3bf26621268bd3c1ad9d289b50fa7  06_attacked.png
af684f0e79fbea3e94c47ab45f92a6db12a74fbd72c21b4abdfceef163ea364f  07_dead.png
```
