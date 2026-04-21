---
name: multi-model-research
description: 使用 Gemini 或 Claude 作为研究视角完成技术调研、方案评审和假设挑战。支持独立调研（直接发起）和第二视角审核（对已有调研做补充/挑战）两种模式。也支持单模型（gemini/claude）或双模型对比（both）运行。通过 `codeagent-wrapper` 配合本 skill 下的 prompts 运行。
---

# Multi-Model Research

本 skill 提供两种使用模式，根据当前阶段选择：

| 模式 | 场景 | 输入重点 |
|---|---|---|
| **独立调研** | 尚未做前期探索，直接委托外部模型完成调研 | 清晰的问题定义、约束条件、期望输出 |
| **第二视角审核** | 本地已有初步结论，需要交叉验证和挑战 | 本地已确认事实、当前判断、希望被挑战的假设 |

不要把外部模型当作权威裁决器；把它当作研究助手和反例生成器。

## 选择后端模式

根据当前需求选择以下三种模式之一：

| 模式 | 指令 | 适用场景 |
|---|---|---|
| **gemini** | `--backend gemini` | 需要快速、发散性的思路补充 |
| **claude** | `--backend claude` | 需要深度分析、长上下文推理 |
| **both** | 先后调用两者 | 需要双重视角交叉验证，或结论分歧较大时 |

默认优先使用 `claude`；当本地已用 Claude 做第一轮分析时，换用 `gemini` 以获得差异化视角。

## 先整理输入

### 模式 A：独立调研

如果你尚未做本地探索，直接发起调研，输入至少包含：

- **调研目标** — 要解决的核心问题或待决策事项
- **已知约束** — 技术栈、性能要求、团队能力、时间限制等
- **关键上下文** — 相关文件路径、文档链接、已有代码位置
- **期望输出** — 需要方案对比、风险评估、还是技术选型建议
- **已知信息**（如有）— 你已经了解的任何相关事实

### 模式 B：第二视角审核

如果你已有本地初步结论，需要补充和挑战，输入至少包含：

- **调研目标** — 核心问题
- **本地已确认事实** — 经你验证的确定性信息
- **当前判断** — 你的初步结论或倾向方案
- **关键上下文** — 文件路径、文档链接
- **希望被挑战的假设** — 你怀疑可能出错的地方
- **还未解决的问题** — 当前调研中的盲区

无论哪种模式，只传必要摘要，不要粘贴大段源码；优先给文件路径、接口名、模块边界、错误现象和你的中间结论。

## 解析运行前提

执行前按下面顺序确定可用命令、prompt 路径和模型配置：

1. 优先使用 `~/.codex/ccg/codeagent-wrapper`
2. 若不存在，再使用 `PATH` 中的 `codeagent-wrapper`
3. prompt 文件根据后端选择：
   - `gemini` → `prompts/gemini-explorer.md`
   - `claude` → `prompts/claude-explorer.md`
4. 模型配置读取当前 skill 目录下的 `config.json`：
   - 若 `"gemini".model` 或 `"claude".model` 非空，调用时追加 `--model <model>`
   - 若为空或未配置，不追加 `--model` 参数，由后端使用默认模型

安装到 `~/.codex/skills` 后，prompt 路径和 `config.json` 通常在 `~/.codex/skills/multi-model-research/` 下。

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
CONFIG="/absolute/path/to/config.json"

# 从 config.json 读取模型配置（需要 python3；无 python3 时跳过）
MODEL_ARG=""
if [ -r "$CONFIG" ] && command -v python3 >/dev/null 2>&1; then
  MODEL="$(python3 -c "import json,sys; d=json.load(open('$CONFIG')); print(d.get('$BACKEND',{}).get('model',''))" 2>/dev/null)"
  if [ -n "$MODEL" ]; then
    MODEL_ARG="--model $MODEL"
  fi
fi

if [ -x "$HOME/.codex/ccg/codeagent-wrapper" ]; then
  WRAPPER="$HOME/.codex/ccg/codeagent-wrapper"
else
  WRAPPER=codeagent-wrapper
fi

# 注意：MODEL_ARG 展开时无引号，因为 --model 和模型名是两个独立参数
"$WRAPPER" --backend "$BACKEND" $MODEL_ARG --prompt-file "$PROMPT" - <<'EOF' | tee "$OUTPUT_FILE"
调研主题：
<一句话说明要解决的核心问题>

已知约束：
- <技术栈/性能/时间/团队等约束 1>
- <约束 2>

关键上下文：
- 文件：<path>
- 文件：<path>
- 文档：<url>

本地已确认事实（如有）：
- <事实 1>
- <事实 2>

当前判断（如有）：
- <你的初步结论或倾向方案>

希望模型重点分析：
1. <分析方向 1>
2. <分析方向 2>

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
# 封装读取模型配置的 helper
_model_arg() {
  local backend="$1"
  if [ -r "$CONFIG" ] && command -v python3 > /dev/null 2>&1; then
    local model
    model="$(python3 -c "import json,sys; d=json.load(open('$CONFIG')); print(d.get('$backend',{}).get('model',''))" 2>/dev/null)"
    [ -n "$model" ] && echo "--model $model"
  fi
}

# Gemini 会话
GEMINI_MODEL_ARG="$(_model_arg gemini)"
"$WRAPPER" --backend gemini $GEMINI_MODEL_ARG --prompt-file "$PROMPT_GEMINI" - <<'EOF' | tee gemini_output.md
... 同一调研主题 ...
EOF
SESSION_ID_GEMINI="$(sed -n 's/^SESSION_ID: //p' gemini_output.md | tail -n 1)"

# Claude 会话
CLAUDE_MODEL_ARG="$(_model_arg claude)"
"$WRAPPER" --backend claude $CLAUDE_MODEL_ARG --prompt-file "$PROMPT_CLAUDE" - <<'EOF' | tee claude_output.md
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

### 独立调研模式的结果整合

- 模型给出的方案和建议
- 需要本地验证的假设和事实
- 明确的待决策点和需要补充的信息
- 下一步行动建议

### 第二视角审核模式的结果整合

- 本地初步结论
- 外部模型补充的不同视角
- 合并后的推荐方案
- 被挑战后仍需确认的假设
- 仍未解决的高影响问题

如果是双模型模式，额外包含：

- 两模型共识与分歧对比
- 分歧点的本地验证方向

## 边界

这个 skill 只用于调研、评审和方案分析，不用于直接让外部模型修改代码或批量生成实现。
