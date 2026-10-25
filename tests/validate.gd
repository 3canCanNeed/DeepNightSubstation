# 自动验证：《深夜变电站》剧情图完整性与结局可达性
# 用法: godot --headless --path <项目> -s res://tests/validate.gd
extends SceneTree

const StoryData := preload("res://scripts/story.gd")


func _init() -> void:
	var S: Dictionary = StoryData.STORY
	var errs: Array = []

	# ---- 1. 结构检查 ----
	for id in S.keys():
		var n: Dictionary = S[id]
		var txt: String = n.get("text", "")
		if txt.strip_edges() == "":
			errs.append("%s: 缺少正文" % id)
		var ch: Array = n.get("choices", [])
		if ch.is_empty():
			errs.append("%s: 没有任何选项" % id)
		for c in ch:
			var go: String = c.get("go", "")
			if go != "__restart" and not S.has(go):
				errs.append("%s → 选项目标不存在: %s" % [id, go])

	# ---- 2. 状态空间 DFS（物品/旗标/体力全部建模）----
	var visited := {}
	var endings_reached := {}
	var stack: Array = [{"n": "start", "it": {}, "fl": {}, "hp": 100, "path": []}]
	var states := 0
	while not stack.is_empty() and states < 30000:
		var st: Dictionary = stack.pop_back()
		var it: Dictionary = st["it"]
		var fl: Dictionary = st["fl"]
		var hp: int = st["hp"]
		var node_id: String = st["n"]
		var key := node_id + "#" + _dk(it) + "#" + _dk(fl) + "#" + str(hp)
		if visited.has(key):
			continue
		visited[key] = true
		states += 1
		var node: Dictionary = S[node_id]
		if node.get("ending", false):
			endings_reached[node_id] = st["path"].duplicate()
			continue
		for c in node.get("choices", []):
			if c.has("need") and not it.has(c["need"]):
				continue
			if c.has("need_flag") and not fl.get(c["need_flag"], false):
				continue
			var go: String = c["go"]
			if go == "__restart":
				continue
			var it2: Dictionary = it.duplicate()
			var fl2: Dictionary = fl.duplicate()
			for k in c.get("set", {}).keys():
				fl2[k] = c["set"][k]
			var give: String = c.get("give", "")
			if give != "":
				for s in give.split(","):
					it2[s.strip_edges()] = true
			var hp2: int = hp + int(c.get("hp", 0))
			var path2: Array = st["path"].duplicate()
			path2.append(node_id + "→" + go)
			if hp2 <= 0:
				endings_reached["ending_bad"] = path2
				continue
			stack.push_back({"n": go, "it": it2, "fl": fl2, "hp": hp2, "path": path2})

	# ---- 3. 可达性检查 ----
	var all_endings: Array = []
	for id in S.keys():
		if S[id].get("ending", false):
			all_endings.append(id)
	var orphan_endings: Array = []
	for e in all_endings:
		if not endings_reached.has(e):
			orphan_endings.append(e)

	# 孤儿节点（从 start 任何条件路径都到不了的非结局节点）
	var reached_nodes := {}
	for k in visited.keys():
		reached_nodes[k.split("#")[0]] = true
	var orphans: Array = []
	for id in S.keys():
		if not reached_nodes.has(id) and not S[id].get("ending", false):
			orphans.append(id)
	for e in orphan_endings:
		orphans.append(e)

	# ---- 输出 ----
	print("节点总数: %d　状态数: %d" % [S.size(), states])
	print("结局可达: %s" % str(endings_reached.keys()))
	for e in endings_reach_keys_sorted(endings_reached):
		print("  %s 路径: %s" % [e, " → ".join(PackedStringArray(endings_reached[e]).slice(0, 8))])
	if not errs.is_empty():
		for e in errs:
			printerr("[结构错误] " + e)
	if not orphans.is_empty():
		for o in orphans:
			printerr("[不可达] " + o)
	if errs.is_empty() and orphans.is_empty() and orphan_endings.is_empty():
		print("VALIDATION_PASS: 结构完整，全部节点与结局可达")
	else:
		print("VALIDATION_FAIL")
	quit(0 if errs.is_empty() and orphans.is_empty() else 1)


func _dk(d: Dictionary) -> String:
	var ks := d.keys()
	ks.sort()
	var parts: Array = []
	for k in ks:
		parts.append(str(k))
	return ",".join(PackedStringArray(parts))


func endings_reach_keys_sorted(d: Dictionary) -> Array:
	var ks := d.keys()
	ks.sort()
	return ks
