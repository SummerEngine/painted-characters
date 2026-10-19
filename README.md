# Painted characters

Plug-in sprite characters for Summer Engine's painted 2.5D worlds (the `painted-25d-world` skill).

Four characters, each with idle, walk and run in 8 directions, 8 frames per animation:
`hero_m`, `hero_f`, `hero_m_sword` (idle and walk), `old_man`.

Copy `characters/` to the root of your project (`res://characters/<id>/`). Each folder has the sheet PNG, a JSON with cell size, rows, frame rates and stride, and a Godot `SpriteFrames` resource.
