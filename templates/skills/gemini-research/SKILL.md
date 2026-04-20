---
name: gemini-research
description: 使用 Gemini 作为第二研究视角完成技术调研、方案评审和假设挑战。适用于 Codex 已完成第一轮本地探索，但还需要从另一个模型视角补充替代方案、识别遗漏风险、挑战现有判断、提升调研结论质量时。通过 `codeagent-wrapper` 的 Gemini 后端配合本 skill 下的 `prompts/explorer.md` 运行。
---

# Gemini Research

先完成 Codex 侧的最小必要探索，再调用 Gemini 做补充分析。不要把 Gemini 当作权威裁决器；把它当作第二视角和反例生成器。

## 先整理输入

在调用 Gemini 之前，先把上下文压缩成一份短任务，至少包含：

- 调研目标或待决策问题
- 已确认事实
- 当前方案或初步判断
- 关键文件路径或官方文档链接
- 还未解决的问题
- 希望 Gemini 特别挑战的假设

只传必要摘要，不要粘贴大段源码；优先给文件路径、接口名、模块边界、错误现象和你的中间结论。

## 解析运行前提

执行前按下面顺序确定可用命令和 prompt 路径：

1. 优先使用 `~/.codex/ccg/codeagent-wrapper`
2. 若不存在，再使用 `PATH` 中的 `codeagent-wrapper`
3. prompt 文件使用当前 skill 目录下的 `prompts/explorer.md`

在本仓库开发态，prompt 路径通常是 `templates/skills/gemini-research/prompts/explorer.md`。
安装到 `~/.codex/skills` 后，prompt 路径通常变为 `~/.codex/skills/gemini-research/prompts/explorer.md`。

如果 `codeagent-wrapper`、`gemini` CLI 或 Gemini 所需环境变量不可用，明确说明阻塞点，不要伪造结果。

## 首次提问时记录 SESSION_ID

首次调用 Gemini 后，输出中通常会包含一行：

```text
SESSION_ID: <uuid>
```

必须提取并记录这个值，用于同一调研主题下的连续追问。不要在同一主题中每次都新开会话，否则 Gemini 无法继承前文。

优先使用 heredoc，避免 shell quoting 和多行内容丢失；同时用 `tee` 保留输出，随后提取 `SESSION_ID`：

```bash
PROMPT="/absolute/path/to/prompts/explorer.md"
OUTPUT_FILE="$(mktemp)"

if [ -x "$HOME/.codex/ccg/codeagent-wrapper" ]; then
  WRAPPER="$HOME/.codex/ccg/codeagent-wrapper"
else
  WRAPPER=codeagent-wrapper
fi

"$WRAPPER" --backend gemini --prompt-file "$PROMPT" - <<'EOF' | tee "$OUTPUT_FILE"
调研主题：
<一句话说明要解决的核心问题>

Codex 已确认事实：
- <事实 1>
- <事实 2>

Codex 当前判断：
- <当前结论或候选方案>

关键上下文：
- 文件：<path>
- 文件：<path>
- 文档：<url>

希望 Gemini 补充分析：
1. 挑战当前判断，指出可能错判的地方
2. 提出 2-3 个替代方案或不同分析角度
3. 识别遗漏风险、边界条件和验证盲点
4. 明确哪些结论属于事实，哪些只是推断

输出要求：
- 使用结构化 Markdown
- 先给结论，再给分析
- 明确风险、取舍、待验证项
EOF

SESSION_ID="$(sed -n 's/^SESSION_ID: //p' "$OUTPUT_FILE" | tail -n 1)"

if [ -z "$SESSION_ID" ]; then
  echo "未获取到 SESSION_ID，不能安全进行连续追问" >&2
else
  echo "Captured SESSION_ID=$SESSION_ID"
fi
```

若需要更强的对比视角，直接把 “Codex 为什么倾向方案 A” 写进去，并要求 Gemini 专门论证为什么不该选 A。

将 `SESSION_ID` 绑定到当前调研任务保存。可以保存在当前 shell 变量、临时文件或调研笔记里，但必须保证后续追问能拿到同一个值。

## 使用 SESSION_ID 连续追问

当后续问题仍属于同一调研主题时，复用上一步的 `SESSION_ID`，不要新开会话：

```bash
"$WRAPPER" --backend gemini resume "$SESSION_ID" "继续从性能和回滚风险角度补充分析"
```

适合复用同一 `SESSION_ID` 的场景：

- 同一方案的补充追问
- 要求 Gemini 挑战它自己上一轮的结论
- 基于上一轮结果继续比较备选方案
- 让 Gemini 细化某个尚未展开的风险点

应新开会话的场景：

- 调研主题已经切换
- 上一轮上下文已经明显污染当前问题
- 需要完全独立的第二意见

如果需要在续问时补充较长上下文，优先把新问题整理成一段短说明后传给 `resume`；不要把整个旧问题重新重复一遍。

## 整合 Gemini 结果

拿到 Gemini 输出后，做一次二次整理，不要原样转交用户：

- 区分“仓库/文档中已验证的事实”和“Gemini 的推断或建议”
- 对 Gemini 提出的新事实、新 API 用法、新版本差异，回到官方文档或仓库再次验证
- 只吸收那些能改变结论、暴露风险或补齐证据链的内容
- 如果 Gemini 与本地证据冲突，以可验证证据为准，并明确写出冲突点

最终调研结果至少应包含：

- Codex 初步结论
- Gemini 补充的不同视角
- 合并后的推荐方案
- 仍未解决的高影响问题

## 边界

这个 skill 只用于调研、评审和方案分析，不用于直接让 Gemini 修改代码或批量生成实现。
