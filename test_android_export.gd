@tool
extends EditorScript

func _run():
    var ep = EditorInterface.get_editor_settings()
    print("Android SDK: ", ep.get_setting("export/android/android_sdk_path"))
    print("Java SDK: ", ep.get_setting("export/android/java_sdk_path"))
    print("Debug keystore: ", ep.get_setting("export/android/debug_keystore"))
    
    # Check export presets
    var export_plugin = null
    for i in EditorExportPlatform.get_export_platforms():
        print("Platform: ", i.get_name())
    quit()
