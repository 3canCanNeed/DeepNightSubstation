# 深夜变电站（Godot 文字冒险）

电气工程题材分支剧情文字冒险游戏。你是被困在深夜停电实验楼里的电气学生——用你的专业知识（和一点点求生欲）逃出去。

## 运行方式

1. 打开 Godot 4（本机已下载：`D:\coc\Godot_v4.7.2-stable_win64.exe`）
2. 「导入」→ 选择本文件夹里的 `project.godot` → 打开工程
3. 按 **F5**（或右上角 ▶）开始游戏

## 玩法

- 鼠标点击选项，或按键盘 **1~9** 快速选择
- 正文打字中点击画面任意处可立即显示全文
- 右上角实时显示**体力**与**背包**；部分选项需要特定物品才会解锁
- 你的选择影响结局——共有 **4 个结局**（含 1 个坏结局）

## 剧情结构（无剧透提示）

- 16 个剧情节点，物品（手电筒/万用表/绝缘手套/钥匙卡）×旗标×体力的完整状态系统
- 剧情文件在 `scripts/story.gd`——纯数据结构，改文字、加选项、加结局都不用碰引擎代码

## 工程结构

```
project.godot                 工程配置（窗口 1000×680，gl_compatibility 渲染）
scenes/main.tscn              主场景（仅挂载脚本的 Control 根节点）
scripts/main.gd               游戏引擎：UI 构建 / 打字机（代际令牌防重入）/ 物品·旗标·体力系统 / 键盘操作
scripts/story.gd              剧情数据（BBCode 富文本，可自由改写扩展）
tests/validate.gd             剧情图静态验证：结构完整性 + 状态空间搜索证明全结局可达
tests/runtime_test.gd(+impl)  运行时自动化测试：真实实例化场景，逐帧模拟点击/键盘走完全部 6 用例
```

## 测试（全部通过后交付）

```
# 语法检查
Godot_console.exe --headless --path . --check-only --script res://scripts/main.gd
# 剧情图验证（16 节点 / 817 状态 / 4 结局全可达）
Godot_console.exe --headless --path . -s res://tests/validate.gd
# 运行时用例（真结局/重开/键盘/天台/电缆沟/坏结局，约 2 分钟）
Godot_console.exe --headless --path . -s res://tests/runtime_test.gd
```

最近一次结果：语法 0 错误；验证 PASS；运行时 **27/27 通过**。

## 已知边界

- 美术为零（纯文字 + 代码绘制的暗色 UI），后续可加立绘/背景图
- 无音效；无存档（单局 5 分钟内通关，重开成本低）

## License

MIT
