@tool
extends EditorPlugin
## Google Play Families / COPPA: an app for children must not declare the advertising ID permission.

var _export := FamiliesExport.new()


func _enter_tree() -> void:
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)


class FamiliesExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "FamiliesCompliance"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		return """
	<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove" />
	<uses-permission android:name="android.permission.AD_ID" tools:node="remove" />
"""
