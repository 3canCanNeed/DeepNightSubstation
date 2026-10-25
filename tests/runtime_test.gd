# 运行时自动化测试入口：godot --headless --path . -s res://tests/runtime_test.gd
extends SceneTree


func _initialize() -> void:
	var impl: Node = load("res://tests/runtime_test_impl.gd").new()
	root.add_child(impl)
