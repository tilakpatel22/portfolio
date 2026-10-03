extends Node
## Persistent progress + settings, and small platform helpers.

signal settings_changed

const SAVE_PATH := "user://save.cfg"
const PACKAGE := "io.github.tilakpatel22.shiptrafficcontrolsim"
const STORE_URL := "https://play.google.com/store/apps/details?id=" + PACKAGE
const PRIVACY_URL := "https://tilakpatel22.github.io/portfolio/ship-traffic-controller/store/privacy-policy.html"
const RATE_AFTER_LEVEL := 4

var level := 1
var best_level := 1
var total_docked := 0
var music_on := true
var sfx_on := true
var vibration_on := true
var rate_prompted := false
var intro_seen := 0
var lifebuoys := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	level = maxi(1, cfg.get_value("progress", "level", 1))
	best_level = maxi(level, cfg.get_value("progress", "best_level", 1))
	total_docked = cfg.get_value("progress", "total_docked", 0)
	music_on = cfg.get_value("settings", "music", true)
	sfx_on = cfg.get_value("settings", "sfx", true)
	vibration_on = cfg.get_value("settings", "vibration", true)
	rate_prompted = cfg.get_value("settings", "rate_prompted", false)
	intro_seen = cfg.get_value("progress", "intro_seen", 0)
	lifebuoys = cfg.get_value("progress", "lifebuoys", 0)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "level", level)
	cfg.set_value("progress", "best_level", best_level)
	cfg.set_value("progress", "total_docked", total_docked)
	cfg.set_value("settings", "music", music_on)
	cfg.set_value("settings", "sfx", sfx_on)
	cfg.set_value("settings", "vibration", vibration_on)
	cfg.set_value("settings", "rate_prompted", rate_prompted)
	cfg.set_value("progress", "intro_seen", intro_seen)
	cfg.set_value("progress", "lifebuoys", lifebuoys)
	cfg.save(SAVE_PATH)


func complete_level() -> void:
	level += 1
	best_level = maxi(best_level, level)
	save()


func add_docked() -> void:
	total_docked += 1


func set_setting(key: String, value: bool) -> void:
	set(key, value)
	save()
	settings_changed.emit()


func should_prompt_rate() -> bool:
	return not rate_prompted and level > RATE_AFTER_LEVEL


func open_store() -> void:
	rate_prompted = true
	save()
	OS.shell_open(STORE_URL)


func vibrate(ms: int) -> void:
	if vibration_on and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
