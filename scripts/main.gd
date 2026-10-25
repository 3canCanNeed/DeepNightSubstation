extends Control
# 《深夜变电站》—— 文字冒险主脚本
# UI 全部代码构建；打字机效果 + 物品/体力/旗标系统 + 多结局

const StoryData := preload("res://scripts/story.gd")
const S: Dictionary = StoryData.STORY

const COL_BG := Color("10141c")
const COL_PANEL := Color("1a2230")
const COL_TEXT := Color("d8dee9")
const COL_ACCENT := Color("ffd54f")
const COL_DIM := Color("6b7686")

var hp := 100
var items: Array = []
var flags := {}
var current := "start"

var text_box: RichTextLabel
var status_bar: RichTextLabel
var choices_box: VBoxContainer
var skip_typing := false
var typing := false


func _ready() -> void:
	_build_ui()
	show_node("start")


func _build_ui() -> void:
	# 中文字体：显式使用系统字体栈，避免默认字体缺 CJK 字形
	var sys_font := SystemFont.new()
	sys_font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei", "Noto Sans CJK SC", "sans-serif"])
	var th := Theme.new()
	th.default_font = sys_font
	th.default_font_size = 17
	self.theme = th

	var root := MarginContainer.new()
	root.name = "RootMargin"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 28)
	root.add_theme_constant_override("margin_right", 28)
	root.add_theme_constant_override("margin_top", 18)
	root.add_theme_constant_override("margin_bottom", 18)
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	root.add_child(vbox)

	# 标题 + 状态栏
	var head := HBoxContainer.new()
	head.name = "Head"
	vbox.add_child(head)

	var title := Label.new()
	title.text = "⚡ 深夜变电站"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COL_ACCENT)
	head.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)

	status_bar = RichTextLabel.new()
	status_bar.bbcode_enabled = true
	status_bar.fit_content = true
	status_bar.custom_minimum_size = Vector2(420, 30)
	head.add_child(status_bar)

	# 正文面板
	var panel := PanelContainer.new()
	panel.name = "StoryPanel"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.gui_input.connect(_on_panel_input)
	var psb := StyleBoxFlat.new()
	psb.bg_color = COL_PANEL
	psb.set_corner_radius_all(10)
	psb.set_border_width_all(1)
	psb.border_color = Color("2a3a52")
	psb.content_margin_left = 20
	psb.content_margin_right = 20
	psb.content_margin_top = 16
	psb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", psb)
	vbox.add_child(panel)

	var pm := MarginContainer.new()
	panel.add_child(pm)

	text_box = RichTextLabel.new()
	text_box.name = "StoryText"
	text_box.bbcode_enabled = true
	text_box.fit_content = false
	text_box.scroll_active = true
	text_box.add_theme_font_size_override("normal_font_size", 18)
	text_box.add_theme_color_override("default_color", COL_TEXT)
	pm.add_child(text_box)

	# 选项区
	choices_box = VBoxContainer.new()
	choices_box.name = "Choices"
	choices_box.add_theme_constant_override("separation", 8)
	vbox.add_child(choices_box)


func _on_panel_input(event: InputEvent) -> void:
	if typing and event is InputEventMouseButton and event.pressed:
		skip_typing = true


func _unhandled_key_input(event: InputEvent) -> void:
	if OS.get_environment("TA_DEBUG"):
		print("KEYDBG: 收到按键 keycode=%d pressed=%s typing=%s" % [event.keycode if event is InputEventKey else -1, str(event.pressed), str(typing)])
	if typing and event is InputEventKey and event.pressed:
		skip_typing = true
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var idx := -1
		if event.keycode >= Key.KEY_1 and event.keycode <= Key.KEY_9:
			idx = event.keycode - Key.KEY_1
		if OS.get_environment("TA_DEBUG"):
			print("KEYDBG: idx=%d 按钮数=%d current=%s" % [idx, choices_box.get_child_count(), current])
		if idx >= 0 and idx < choices_box.get_child_count():
			var btn := choices_box.get_child(idx) as Button
			if btn and not btn.disabled:
				btn.emit_signal("pressed")


var _gen := 0  # 代际令牌：新一轮 show_node 使旧的异步流程失效


func show_node(id: String) -> void:
	if not S.has(id):
		push_error("剧情节点不存在: " + id)
		return
	_gen += 1
	var g := _gen
	if OS.get_environment("TA_DEBUG"):
		print("NODE: gen=%d → %s" % [g, id])
	current = id
	_update_status()
	for c in choices_box.get_children():
		c.queue_free()
	var node: Dictionary = S[id]
	_type_text(node["text"], g)
	await _wait_typing()
	if g != _gen:
		return  # 已有更新的节点接管（例如打字中重开）
	_spawn_choices(node)


func _type_text(t: String, g: int) -> void:
	typing = true
	skip_typing = false
	text_box.visible_characters = 0
	text_box.text = t
	var total := text_box.get_total_character_count()
	var cps := 40.0  # 字符/秒
	var acc := 0.0
	var last_vis := -2
	var stall := 0
	while text_box.visible_characters < total:
		if g != _gen:
			return  # 旧流程退出，不动 typing（新流程接管）
		if skip_typing:
			text_box.visible_characters = -1
			break
		await get_tree().process_frame
		if text_box.visible_characters == last_vis:
			stall += 1
			if stall == 400 and OS.get_environment("TA_DEBUG"):
				printerr("TYPESTALL: gen=%d/_gen=%d vis=%d total=%d skip=%s" % [g, _gen, text_box.visible_characters, total, str(skip_typing)])
		else:
			stall = 0
		last_vis = text_box.visible_characters
		acc += cps * get_process_delta_time()
		if acc >= 1.0:
			text_box.visible_characters += int(acc)
			acc = fmod(acc, 1.0)
	text_box.visible_characters = -1
	if g == _gen:
		typing = false


func _wait_typing() -> void:
	while typing:
		await get_tree().process_frame


func _spawn_choices(node: Dictionary) -> void:
	var choices: Array = node.get("choices", [])
	var is_ending: bool = node.get("ending", false)
	for i in choices.size():
		var c: Dictionary = choices[i]
		var btn := Button.new()
		var label: String = "%d. %s" % [i + 1, c["t"]]
		var ok := true
		var hint: String = c.get("hint", "条件不足")
		if c.has("need") and not items.has(c["need"]):
			ok = false
			label += "  [需 %s]" % c["need"]
		if c.has("need_flag") and not flags.get(c["need_flag"], false):
			ok = false
			label += "  [%s]" % hint
		var hp_cost: int = c.get("hp", 0)
		if hp_cost < 0:
			label += "  (体力 %d)" % hp_cost
		btn.text = label
		btn.disabled = not ok
		btn.add_theme_font_size_override("font_size", 17)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("222c3f") if ok else Color("161c28")
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(1)
		sb.border_color = Color("3a4a66") if ok else Color("232b3a")
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 9
		sb.content_margin_bottom = 9
		btn.add_theme_stylebox_override("normal", sb)
		var sbh := sb.duplicate()
		sbh.bg_color = Color("2d3a52") if ok else sb.bg_color
		btn.add_theme_stylebox_override("hover", sbh)
		var sbd := sb.duplicate()
		sbd.bg_color = Color("1b2434")
		btn.add_theme_stylebox_override("disabled", sbd)
		btn.add_theme_color_override("font_color", COL_TEXT)
		btn.add_theme_color_override("font_disabled_color", COL_DIM)
		btn.pressed.connect(_choose.bind(c, is_ending))
		choices_box.add_child(btn)


func _choose(c: Dictionary, _is_ending: bool) -> void:
	# 结算效果
	for k in c.get("set", {}).keys():
		flags[k] = c["set"][k]
	var give: String = c.get("give", "")
	if give != "":
		for it in give.split(","):
			var s := it.strip_edges()
			if s != "" and not items.has(s):
				items.append(s)
	hp += c.get("hp", 0)
	if hp <= 0:
		hp = 0
		_update_status()
		show_node("ending_bad")
		return
	var go: String = c["go"]
	if go == "__restart":
		_restart()
		return
	show_node(go)


func _update_status() -> void:
	var hp_color := "#81c784" if hp >= 60 else ("#ffd54f" if hp >= 30 else "#ff8a80")
	var item_str := "、".join(items) if items.size() > 0 else "空空如也"
	status_bar.text = "体力 [color=%s][b]%d[/b][/color]　│　背包：%s" % [hp_color, hp, item_str]


func _restart() -> void:
	hp = 100
	items = []
	flags = {}
	show_node("start")
