class_name PaintedCharacter
extends AnimatedSprite3D
## Drop-in sprite for painted 2.5D worlds. Add as a child of the CharacterBody3D (origin at the feet),
## set `frames_path` (or `sprite_frames`) and call `update_from_velocity()` every physics frame.
## Vertical Y-billboard, unshaded, alpha-cut so walls and props hide it correctly. Stretched by 1/cos(elev)
## so the card reads at full height from the tilted orthographic camera.
## Picks one of 8 directions (45 degree sectors on screen) and falls back to the nearest of the 4 main ones.
## Plays walk/run at the speed that matches the ground speed, from the stride in <id>_sheet.json, so feet do not slide.

const DIRS := ["right", "up_right", "up", "up_left", "left", "down_left", "down", "down_right"]

## SpriteFrames with idle_/walk_/run_ + down/up/left/right and optionally the diagonals.
@export var frames_path := ""
## The sheet's json (stride_m, cycles_per_s). Empty = next to frames_path (<id>_frames.tres -> <id>_sheet.json).
@export var sheet_json_path := ""
## Character height in metres.
@export var height := 1.8
## Camera look-down angle in degrees (the world camera's elevation).
@export var camera_elev_deg := 35.0
## Camera right vector on the ground; screen directions are picked against it.
@export var camera_right := Vector3(cos(PI / 4.0), 0, -sin(PI / 4.0))
## Speed (m/s) from which the run cycle plays. 0 = halfway between the sheet's natural walk and run speeds.
@export var run_speed := 0.0

var facing := "down"
var _screen := Vector2(0, -1)   # last move on screen axes (x right, y away from the camera)
var _stride := {}               # kind -> metres per cycle at `height`
var _cycles := {}               # kind -> cycles per second at speed_scale 1

func _ready() -> void:
	if frames_path != "":
		sprite_frames = load(frames_path)
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	shaded = false
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tex := sprite_frames.get_frame_texture(sprite_frames.get_animation_names()[0], 0)
	var h := height / cos(deg_to_rad(camera_elev_deg))
	pixel_size = h / float(tex.get_height())
	position.y = h / 2.0
	_load_stride()
	play("idle_down")

func _load_stride() -> void:
	var path := sheet_json_path
	if path == "" and frames_path.ends_with("_frames.tres"):
		path = frames_path.trim_suffix("_frames.tres") + "_sheet.json"
	if path == "" or not FileAccess.file_exists(path):
		return
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var ref_h: float = meta.get("height_m", 1.8)
	for kind in meta.get("stride_m", {}):
		_stride[kind] = float(meta.stride_m[kind]) * height / ref_h
	for kind in meta.get("cycles_per_s", {}):
		_cycles[kind] = float(meta.cycles_per_s[kind])
	if run_speed <= 0.0 and natural_speed("walk") > 0.0 and natural_speed("run") > 0.0:
		run_speed = (natural_speed("walk") + natural_speed("run")) / 2.0

## Ground speed (m/s) at which the cycle's feet stick to the ground with speed_scale 1.
func natural_speed(kind: String) -> float:
	return _stride.get(kind, 0.0) * _cycles.get(kind, 0.0)

## Pick idle/walk/run, one of 8 screen directions, and the playback speed from a world velocity.
func update_from_velocity(v: Vector3) -> void:
	var flat := Vector2(v.x, v.z)
	var speed := flat.length()
	if speed < 0.1:
		speed_scale = 1.0
		_play_dir("idle", facing)
		return
	var right := Vector2(camera_right.x, camera_right.z).normalized()
	var far := Vector2(right.y, -right.x)    # away from the camera on the ground
	_screen = Vector2(flat.dot(right), flat.dot(far))
	facing = DIRS[posmod(roundi(atan2(_screen.y, _screen.x) / (PI / 4.0)), 8)]
	var kind := "run" if run_speed > 0.0 and speed >= run_speed and sprite_frames.has_animation("run_down") else "walk"
	var natural := natural_speed(kind)
	speed_scale = clampf(speed / natural, 0.25, 4.0) if natural > 0.0 else 1.0
	_play_dir(kind, facing)

## Play kind_dir; without that diagonal, the nearest main direction (the larger screen component wins).
func _play_dir(kind: String, dir: String) -> void:
	var anim := kind + "_" + dir
	if not sprite_frames.has_animation(anim) and "_" in dir:
		var parts := dir.split("_")
		anim = kind + "_" + (parts[1] if absf(_screen.x) > absf(_screen.y) else parts[0])
	if animation != anim:
		play(anim)
