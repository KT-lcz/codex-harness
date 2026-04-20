# everything-codex-slim

一个面向 Codex CLI 的轻量级工作流增强仓库，用来补齐 Codex 生态里偏少的多 agent 编排能力。

这个项目的目标很直接：

- `oh-my-codex` 很强，但对很多场景来说偏重
- Codex 生态里现成的多 agent 编排组件不多
- 因此这里提供一套更轻、更本地化、更容易直接落到 `~/.codex` 的 harness

它不是另一个完整平台，而是一套可安装的工作环境约定：配置、agent 模板、编排提示词、skills 模板和辅助包装器。

## 它解决什么问题

如果你现在使用 Codex CLI，通常会遇到几个问题：

- 默认单 agent 模式在复杂任务上容易上下文过载
- 缺少一套开箱即用的多 agent 分工模板
- 缺少把调研、方案、编码、评审、验证串起来的轻量工作流
- 想接入额外能力时，经常要手工维护配置、MCP 和辅助脚本

`everything-codex-slim` 的做法是直接把这些基础设施安装到 `~/.codex`，让你可以在 Codex CLI 里用统一方式调用。
它并没有直接修改默认的codex profile，默认方式使用时，除非显式说明，否则默认不会自动触发多agent编排。

## 注意
```toml
sandbox_mode = "danger-full-access"
approval_policy = "never"
```
开启了以上配置，不要在生产环境中使用。

## 当前具备的功能

基于当前仓库内容，项目已经具备这些能力。

### 1. 多 agent 编排入口

安装后会写入一个 `multi` profile，使用方式是：

```bash
codex -p multi
```

这个 profile 会启用 `templates/agents-prompts/ORCHESTRATOR.md` 中定义的编排逻辑，用总调度视角来组织任务。

它的当前特征包括：

- 面向多阶段任务的编排式执行
- 强调规范驱动和阶段化推进
- 优先把任务分给专门角色，而不是让一个 agent 混做所有事

### 2. 预置 agent 角色库

仓库在 `templates/agents` 中提供了一组现成 agent 模板，安装后会复制到 `~/.codex/agents`。

当前包含：

- `architect`
- `code-mapper`
- `code-simplifier`
- `coder`
- `doc_editor`
- `evaluator`
- `explorer`
- `quick`
- `reviewer`
- `scrum_master`
- `security-auditor`
- `verifier`

这些角色覆盖了从调研、架构、任务拆分，到编码、审查、验证、文档整理的一整条链路。
即使没有通过`codex -p multi`进入,也可以通过自然语言使用上述预置角色。

### 3. 轻量的 OpenSpec / 流程驱动约束

当前多 agent 提示词并不是"无脑并发"，而是偏流程化编排：

- 调研阶段使用 `explorer` / `code-mapper`
- 方案阶段使用 `architect` / `evaluator`
- 拆解阶段使用 `scrum_master`
- 实施阶段使用 `coder`
- 验证阶段使用 `security-auditor` / `verifier` / `reviewer`
- 收尾阶段使用 `doc_editor`

这让它更适合中等复杂度以上的开发任务，而不是只做简单 shell 包装。

### 4. 预置技能模板

仓库在 `templates/skills` 中提供了两个技能模板：

- `gemini-research`
- `tech-research`

它们解决的是"需要第二视角调研"以及"需要标准化技术调研工作流"的场景。

### 5. `codeagent-wrapper` 多后端包装器

仓库自带一个二进制工具 `ccg/codeagent-wrapper`，用于统一调用不同 AI CLI 后端。

根据当前 `--help` 输出，它支持：

- `codex`
- `claude`
- `gemini`
- `opencode`

也支持：

- `--prompt-file`
- `--skills`
- `--parallel`
- `--output`
- `--worktree`

这意味着当前项目不仅能跑 Codex 本身，也为跨 CLI 协作留了接口。

### 6. 可选 MCP 注入

安装脚本支持按需把 MCP 配置合并进 `~/.codex/config.toml`：

- 默认启用 `context7`
- 默认启用 `fetch`
- 可选启用 `exa`
- 可选启用 `github`

其中 `exa` 和 `github` 会在安装时读取：

- `EXA_API_KEY`
- `GITHUB_PERSONAL_ACCESS_TOKEN`

直接回车跳过即可，不会强制要求。

### 7. 配置合并，而不是粗暴覆盖

`install.sh` 会生成或更新 `~/.codex/config.toml`，但不是全量覆盖用户配置，而是保留非托管部分。

当前会被托管的核心内容包括：

- 模型与 provider
- `profiles.multi`
- `context7` / `fetch`
- `agents`
- `features`
- 部分运行时策略

这使它更适合作为"现有 Codex 环境上的增强层"。

## 如何使用

### 1. 安装

前提：

- 已安装 `npm`
- 有可用的 Codex CLI
- 愿意将本仓库内容安装到当前用户的 `~/.codex`

执行：

```bash
git clone <your-repo-url>
cd everything-codex-slim
bash install.sh
```

安装脚本会做这些事：

- 安装 `@fission-ai/openspec`
- 复制 `templates/` 下的 agents、rules、skills、prompts
- 复制 `ccg/codeagent-wrapper`
- 合并并生成 `~/.codex/config.toml`

### 2. 默认使用 Codex

如果你只想用默认模式，直接运行：

```bash
codex
```

这时会使用安装后的默认配置，但不一定进入多 agent 编排入口。

### 3. 使用多 agent 编排

当前多 agent 编排的标准使用方式是：

```bash
codex -p multi
```

进入后，适合直接给中高复杂度任务，例如：

```text
$openspec-explore 需要给当前项目添加gitlab oauth认证
```

在使用openspec skill时自动触发。

### 4. 使用 Gemini 调研包装器

当前仓库自带的 `gemini-research` 模板依赖 `codeagent-wrapper`。例如：

```bash
./ccg/codeagent-wrapper \
  --backend gemini \
  --prompt-file ./templates/skills/gemini-research/prompts/explorer.md \
  "评估当前方案是否适合做多 agent 编排"
```

更完整的参数请以实际帮助输出为准：

```bash
./ccg/codeagent-wrapper --help
./ccg/codeagent-wrapper version
```

### 5. 验证安装结果

可以先做最小检查：

```bash
bash -n install.sh
./ccg/codeagent-wrapper --help
```

安装完成后再确认：

```bash
ls -la ~/.codex
sed -n '1,260p' ~/.codex/config.toml
```

重点看这些内容是否存在：

- `~/.codex/agents/`
- `~/.codex/skills/`
- `~/.codex/agents-prompts/ORCHESTRATOR.md`
- `~/.codex/ccg/codeagent-wrapper`
- `~/.codex/config.toml` 中的 `[profiles.multi]`

## OpenSpec 用法

### OpenSpec 是什么

OpenSpec 是一个规范驱动开发（SDD）框架，为 AI 编程助手提供结构化的变更管理能力。它通过在代码仓库中创建 `openspec/` 目录来管理变更提案、规格、设计和任务。

本项目依赖 OpenSpec 的 SDD 流程，安装脚本会自动安装 `@fission-ai/openspec` 包。

### OpenSpec 与 everything-codex-slim 的关系

- **everything-codex-slim** 提供多 agent 编排能力和本地工作流增强
- **OpenSpec** 提供规范驱动的变更管理能力
- 两者结合：OpenSpec 负责结构化变更记录，everything-codex-slim 负责多 agent 协作执行

### 安装与刷新

OpenSpec 在执行 `bash install.sh` 时会自动安装。

```bash
# 在项目中初始化 OpenSpec
cd your-project
openspec init

# 刷新 OpenSpec 生成的 skills
openspec update
```

### Codex 中的使用方式

OpenSpec 在 Codex 环境下只能通过 **skill** 触发。`openspec init --tools codex` 或 `openspec update` 之后，OpenSpec 会把对应 skill 生成到 `~/.codex/skills/openspec-*/SKILL.md`，Codex 会按 skill 名识别这些工作流。

当前常用 skill 包括：

| Skill 名称 | 功能 |
|-----------|------|
| `openspec-propose` | 创建变更提案，生成规划文档（默认 core profile） |
| `openspec-explore` | 探索想法、调研问题、澄清需求 |
| `openspec-apply-change` | 实施变更任务 |
| `openspec-archive-change` | 归档已完成的变更 |

Skill 文件位置：`~/.codex/skills/openspec-*/SKILL.md`

### 常见工作流

**Core profile（默认）**

最简工作流，适合快速启动变更：

```text
在 Codex 对话中使用 OpenSpec skills：
- `openspec-propose`：为用户模块添加双因素认证
- `openspec-apply-change`
- `openspec-archive-change`
```

## RTK 用法

### RTK 是什么

RTK（Rust Token Killer）是一个 Token 优化的 CLI 代理，用于减少 shell 命令输出的 token 消耗。

### 为什么要求 rtk 前缀

本项目要求所有 shell 命令前缀使用 `rtk`，原因：

- 自动过滤冗余输出，降低上下文膨胀
- 提供执行统计，帮助识别高消耗命令
- 统一命令执行入口，便于审计和回放

## 仓库结构

```text
.
├── install.sh          # 安装脚本
├── ccg/
│   └── codeagent-wrapper   # 多后端 AI CLI 包装器
└── templates/
    ├── AGENTS.md
    ├── RTK.md
    ├── agents/             # Agent 角色模板
    ├── agents-prompts/     # 编排提示词
    ├── config.base.toml    # 基础配置模板
    ├── rules/              # 行为规则
    ├── skills/             # 技能模板
    │   ├── gemini-research/
    │   └── tech-research/
    └── snippets/           # 代码片段
```

## 注意事项

- 这不是一个完整插件平台，也不是一个独立 CLI 产品
- 仓库核心是安装脚本加模板，不是业务应用
- `codeagent-wrapper` 目前以二进制形式提交，代码在<https://github.com/stellarlinkco/myclaude/tree/master/codeagent-wrapper>中，可自行编译
- 默认 provider `base_url` 是一个默认地址，使用时需要手动修改并添加`OPENAI_API_KEY`，
- `install.sh` 是交互式安装，不适合直接作为无参 CI 安装脚本
- 多 agent 编排能力当前主要通过 `codex -p multi` 这个 profile 入口暴露
- 所有 shell 命令请使用 `rtk` 前缀以优化 token 消耗
- OpenSpec 变更记录存储在项目根目录的 `openspec/` 目录下

## 为什么不是 oh-my-codex

这个项目并不是要复刻 `oh-my-codex`。

它更像一个面向 Codex CLI 的轻量替代方案，重点在于：

- 保留多 agent 编排的核心能力
- 减少额外平台层和重量级封装
- 直接复用 `~/.codex` 配置与本地模板
- 让你可以更低成本地把多 agent 工作流接到现有 Codex 环境中

如果你要的是更完整、更平台化、更大而全的系统，可以看 `oh-my-codex` 一类项目。

如果你要的是一个足够轻、足够直接、能马上开始用的 Codex 多 agent harness，这个仓库就是为这个目的写的。

## TODO

- 增加 autopilot skill
- 增加分析代码库的skill
- 完善tech-research skill
- 增加技术方案审核的skill
- 增加review代码提交的skill
- 增加记忆和召回的prompt