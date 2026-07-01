extends Control

## Entry point for the Yarbell hello-world scene.
## Prints a line to the log so we can confirm GDScript runs on-device
## via `adb logcat`.
func _ready() -> void:
	print("Yarbell booted")
