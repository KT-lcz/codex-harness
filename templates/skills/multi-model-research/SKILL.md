---
name: multi-model-research
description: 使用 Gemini 或 Claude 作为第二研究视角完成技术调研、方案评审和假设挑战。支持单模型模式（gemini/claude）或双模型对比模式（both）。适用于已完成第一轮本地探索，需要补充替代方案、识别遗漏风险、挑战现有判断时。通过 `codeagent-wrapper` 配合本 skill 下的 prompts 运行。
---

# Multi-Model Research

先完成本地侧的最小必要探索，再调用外部模型做补充分析。不要把外部模型当作权威裁决器；把它当作第二视角和反例生成器。

## 选择后端模式

根据当前需求选择以下三种模式之一：

| 模式 | 指令 | 适用场景 |
|---|---|---|
| **gemini** | `--backend gemini` | 需要快速、发散性的思路补充 |
| **claude** | `--backend claude` | 需要深度分析、长上下文推理 |
| **both** | 先后调用两者 | 需要双重视角交叉验证，或结论分歧较大时 |

默认优先使用 `claude`；当本地已用 Claude 做第一轮分析时，换用 `gemini` 以获得差异化视角。

## 先整理输入

在调用外部模型之前，先把上下文压缩成一份短任务，至少包含：

- 调研目标或待决策问题
- 已确认事实
- 当前方案或初步判断
- 关键文件路径或官方文档链接
- 还未解决的问题
- 希望外部模型特别挑战的假设

只传必要摘要，不要粘贴大段源码；优先给文件路径、接口名、模块边界、错误现象和你的中间结论。

## 解析运行前提

执行前按下面顺序确定可用命令和 prompt 路径：

1. 优先使用 `~/.codex/ccg/codeagent-wrapper`
2. 若不存在，再使用 `PATH` 中的 `codeagent-wrapper`
3. prompt 文件根据后端选择：
   - `gemini` → `prompts/gemini-explorer.md`
   - `claude` → `prompts/claude-explorer.md`

安装到 `~/.codex/skills` 后，prompt 路径通常变为 `~/.codex/skills/multi-model-research/prompts/` 下。

如果 `codeagent-wrapper` 或对应后端所需环境变量不可用，明确说明阻塞点，不要伪造结果。

## 首次提问时记录 SESSION_ID

首次调用后，输出中通常会包含一行：

```text
SESSION_ID: <uuid>
```

必须提取并记录这个值，用于同一调研主题下的连续追问。不要在同一主题中每次都新开会话。

优先使用 heredoc，避免 shell quoting 和多行内容丢失；同时用 `tee` 保留输出，随后提取 `SESSION_ID`：

```bash
BACKEND="claude"  # 或 gemini
PROMPT="/absolute/path/to/prompts/${BACKEND}-explorer.md"
OUTPUT_FILE="$(mktemp)"

if [ -x "$HOME/.codex/ccg/codeagent-wrapper" ]; then
  WRAPPER="$HOME/.codex/ccg/codeagent-wrapper"
else
  WRAPPER=codeagent-wrapper
fi

"$WRAPPER" --backend "$BACKEND" --prompt-file "$PROMPT" - <<'EOF' | tee "$OUTPUT_FILE"
调研主题：
<一句话说明要解决的核心问题>

本地已确认事实：
- <事实 1>
- <事实 2>

当前判断：
- <当前结论或候选方案>

关键上下文：
- 文件：<path>
- 文件：<path>
- 文档：<url>

希望补充分析：
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

若需要更强的对比视角，直接把 "本地为什么倾向方案 A" 写进去，并要求模型专门论证为什么不该选 A。

将 `SESSION_ID` 绑定到当前调研任务保存。可以保存在当前 shell 变量、临时文件或调研笔记里，但必须保证后续追问能拿到同一个值。

## 使用 SESSION_ID 连续追问

当后续问题仍属于同一调研主题时，复用上一步的 `SESSION_ID`，不要新开会话：

```bash
"$WRAPPER" --backend "$BACKEND" resume "$SESSION_ID" "继续从性能和回滚风险角度补充分析"
```

> **注意**：`SESSION_ID` 是后端隔离的。Claude 的 SESSION_ID 不能用于 Gemini 的 resume，反之亦然。

适合复用同一 `SESSION_ID` 的场景：

- 同一方案的补充追问
- 要求模型挑战它自己上一轮的结论
- 基于上一轮结果继续比较备选方案
- 让模型细化某个尚未展开的风险点

应新开会话的场景：

- 调研主题已经切换
- 上一轮上下文已经明显污染当前问题
- 需要完全独立的第二意见

如果需要在续问时补充较长上下文，优先把新问题整理成一段短说明后传给 `resume`；不要把整个旧问题重新重复一遍。

## 双模型对比模式（both）

当需要同时利用两个模型的视角时，分别发起两个独立会话，然后本地整合：

```bash
# 并行或串行调用均可
"$WRAPPER" --backend gemini --prompt-file "$PROMPT_GEMINI" - <<'EOF' | tee gemini_output.md
... 同一调研主题 ...
EOF
SESSION_ID_GEMINI="$(sed -n 's/^SESSION_ID: //p' gemini_output.md | tail -n 1)"

"$WRAPPER" --backend claude --prompt-file "$PROMPT_CLAUDE" - <<'EOF' | tee claude_output.md
... 同一调研主题 ...
EOF
SESSION_ID_CLAUDE="$(sed -n 's/^SESSION_ID: //p' claude_output.md | tail -n 1)"
```

双模型对比的额外价值：

- **共识区域**：两个模型都认同的结论，可信度更高
- **分歧区域**：意见不同的地方往往是需要人工深入判断的关键点
- **互补区域**：一个模型提到但另一个遗漏的风险点

整合时优先关注分歧区域，把它作为后续追问的焦点（分别用各自的 SESSION_ID 追问，让它们针对分歧点展开论证）。

## 整合外部模型结果

拿到输出后，做一次二次整理，不要原样转交用户：

- 区分"仓库/文档中已验证的事实"和"模型的推断或建议"
- 对模型提出的新事实、新 API 用法、新版本差异，回到官方文档或仓库再次验证
- 只吸收那些能改变结论、暴露风险或补齐证据链的内容
- 如果模型与本地证据冲突，以可验证证据为准，并明确写出冲突点

最终调研结果至少应包含：

- 本地初步结论
- 外部模型补充的不同视角
- 合并后的推荐方案
- 仍未解决的高影响问题

如果是双模型模式，额外包含：

- 两模型共识与分歧对比
- 分歧点的本地验证方向

## 边界

这个 skill 只用于调研、评审和方案分析，不用于直接让外部模型修改代码或批量生成实现。
