# 运行时测试驱动：实例化真实主场景，逐帧推进，模拟按钮点击与键盘选择，
# 实际走完：真结局 / 逃生结局 / 稳妥结局 / 坏结局 / 重开 / 键盘操作 六组用例。
extends Node

var main: Control
var steps: Array = []
var step_idx := 0
var passed := 0
var failed := 0
var wait := 0
var frame := 0
var _last_logged := -1
var _t0 := 0


func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_parent().add_child.call_deferred(main)
	steps = _build_steps()
	print("TEST_READY: 步骤数 %d" % steps.size())
	_t0 = Time.get_ticks_msec()
	_probe()


func _probe() -> void:
	for i in 3:
		await get_tree().process_frame
	print("PROBE_OK: process_frame 正常恢复协程")


func _build_steps() -> Array:
	return [
		# ---- 用例 1：真结局（先拿装备→按规程+验电）----
		{"do": "click", "i": 0},            # start: 回实验室
		{"do": "assert", "id": "lab"},
		{"do": "click", "i": 0},            # lab: 去配电箱（带装备）
		{"do": "assert_items", "has": ["手电筒", "万用表", "绝缘手套"]},
		{"do": "click", "i": 0},            # corridor: 戴手套检查
		{"do": "assert", "id": "box_check"},
		{"do": "click", "i": 0},            # box_check: 出发（knows_short）
		{"do": "click", "i": 0},            # door: 手电筒下去
		{"do": "assert", "id": "substation"},
		{"do": "click", "i": 1},            # substation: 万用表验电+规程（需万用表）
		{"do": "assert", "id": "power_restore"},
		{"do": "assert_flag", "k": "careful", "v": true},
		{"do": "click", "i": 0},
		{"do": "assert", "id": "ending_good"},
		{"do": "assert_hp", "v": 100},
		# ---- 用例 2：重开 ----
		{"do": "click", "i": 0},
		{"do": "assert", "id": "start"},
		{"do": "assert_items", "has": []},
		{"do": "assert_hp", "v": 100},
		# ---- 用例 3：键盘操作 + 体力扣减（按 3 = 摸黑下地下，体力-10）----
		{"do": "key", "k": Key.KEY_3},
		{"do": "assert", "id": "substation_door"},
		{"do": "assert_hp", "v": 90},
		# ---- 用例 4：稳妥结局（天台）----
		{"do": "restart"},
		{"do": "key", "k": Key.KEY_1},      # → lab
		{"do": "assert", "id": "lab"},
		{"do": "click", "i": 1},            # lab: 直接下地下
		{"do": "assert", "id": "substation_door"},
		{"do": "click", "i": 2},            # door: 天台求援
		{"do": "assert", "id": "rooftop"},
		{"do": "click", "i": 0},
		{"do": "assert", "id": "ending_roof"},
		# ---- 用例 5：电缆沟结局 ----
		{"do": "restart"},
		{"do": "assert", "id": "start"},
		{"do": "click", "i": 0},            # → lab
		{"do": "assert", "id": "lab"},
		{"do": "click", "i": 0},            # → corridor
		{"do": "assert", "id": "corridor_box"},
		{"do": "click", "i": 2},            # corridor: 不碰，下地下
		{"do": "assert", "id": "substation_door"},
		{"do": "click", "i": 0},            # door: 手电下去
		{"do": "assert", "id": "substation"},
		{"do": "click", "i": 3},            # substation: 检查冒烟柜
		{"do": "assert", "id": "smoke_check"},
		{"do": "click", "i": 1},            # smoke_check: 立刻爬沟
		{"do": "assert", "id": "duct"},
		{"do": "click", "i": 0},
		{"do": "assert", "id": "ending_duct"},
		# ---- 用例 6：坏结局（体力归零）----
		{"do": "restart"},
		{"do": "click", "i": 1},            # start: 去配电箱
		{"do": "click", "i": 1},            # 徒手合闸 -30 → 70
		{"do": "click", "i": 0},            # 回实验室
		{"do": "click", "i": 0},            # 去配电箱（拿过装备了）
		{"do": "click", "i": 1},            # 再徒手 -30 → 40
		{"do": "click", "i": 1},            # 继续去地下
		{"do": "click", "i": 1},            # 手机照明 -15 → 25
		{"do": "click", "i": 2},            # 直接合断路器 -10 → 15
		{"do": "click", "i": 0},            # 回柜前
		{"do": "click", "i": 2},            # 再直接合 -10 → 5
		{"do": "click", "i": 0},
		{"do": "click", "i": 2},            # 第三次 -10 → 归零
		{"do": "assert", "id": "ending_bad"},
		{"do": "assert_hp", "v": 0},
		{"do": "done"},
	]


func _process(_delta: float) -> void:
	frame += 1
	if frame == 90:
		print("DBG90: main有效=%s typing=%s 按钮数=%d 当前节点=%s" % [
			main != null and is_instance_valid(main),
			str(main.typing),
			main.choices_box.get_child_count(),
			main.current])
		print("DBG90B: 可见字符=%d 总数=%d delta=%.4f skip=%s" % [
			main.text_box.visible_characters,
			main.text_box.get_total_character_count(),
			get_process_delta_time(),
			str(main.skip_typing)])
	# 超时按真实时间判定：打字机 40 字符/秒，全套用例约需 2 分钟
	if Time.get_ticks_msec() - _t0 > 240000:
		printerr("TIMEOUT: 卡在步骤 %d: %s | 当前节点=%s typing=%s 按钮数=%d hp=%d" % [
			step_idx, str(steps[mini(step_idx, steps.size() - 1)]),
			main.current, str(main.typing), main.choices_box.get_child_count(), main.hp])
		get_tree().quit(1)
		return
	if wait > 0:
		wait -= 1
		return
	if main == null or not is_instance_valid(main):
		return
	if step_idx >= steps.size():
		return
	var s: Dictionary = steps[step_idx]
	if step_idx != _last_logged:
		_last_logged = step_idx
		print("STEP %d: %s" % [step_idx, str(s)])
	match s.get("do"):
		"click":
			if not main.typing and main.choices_box.get_child_count() > 0:
				if s.get("i", 0) >= main.choices_box.get_child_count():
					_fail("步骤%d: 按钮 %d 不存在（共 %d 个）——测试路径与实际分支不符" % [step_idx, s["i"], main.choices_box.get_child_count()])
					get_tree().quit(1)
					return
				var btn := main.choices_box.get_child(s["i"]) as Button
				if btn.disabled:
					_fail("步骤%d: 按钮 %d 处于禁用（不应发生）" % [step_idx, s["i"]])
					get_tree().quit(1)
					return
				btn.pressed.emit()
				wait = 4
				step_idx += 1
		"key":
			if _buttons_ready(0):
				var ev := InputEventKey.new()
				ev.keycode = s["k"]
				ev.pressed = true
				Input.parse_input_event(ev)
				wait = 4
				step_idx += 1
		"assert":
			if main.current == s["id"]:
				_pass("节点正确: " + s["id"])
			else:
				_fail("期望节点 %s，实际 %s" % [s["id"], main.current])
			step_idx += 1
		"assert_items":
			var ok := true
			for it in s.get("has", []):
				if not main.items.has(it):
					ok = false
			if s.get("has", []).size() != main.items.size():
				ok = false
			if ok:
				_pass("物品集合正确: " + str(main.items))
			else:
				_fail("物品不符: 期望 %s 实际 %s" % [str(s["has"]), str(main.items)])
			step_idx += 1
		"assert_flag":
			if main.flags.get(s["k"], false) == s["v"]:
				_pass("旗标 %s = %s" % [s["k"], str(s["v"])])
			else:
				_fail("旗标 %s 期望 %s 实际 %s" % [s["k"], str(s["v"]), str(main.flags.get(s["k"]))])
			step_idx += 1
		"assert_hp":
			if main.hp == s["v"]:
				_pass("体力 = %d" % main.hp)
			else:
				_fail("体力期望 %d 实际 %d" % [s["v"], main.hp])
			step_idx += 1
		"restart":
			main._restart()
			wait = 4
			step_idx += 1
		"done":
			print("RUNTIME_TEST_RESULT: %d 通过 / %d 失败" % [passed, failed])
			get_tree().quit(1 if failed > 0 else 0)
			step_idx += 1


func _buttons_ready(i: int) -> bool:
	return not main.typing and main.choices_box.get_child_count() > i


func _pass(msg: String) -> void:
	passed += 1
	print("  ✓ " + msg)


func _fail(msg: String) -> void:
	failed += 1
	printerr("  ✗ " + msg)
