---
name: multi-orchestrator-playbook
description: 仅在用户显式输入 `multi-orchestrator-playbook` 或明确要求“加载编排手册 / ORCHESTRATOR.md”时使用。该 skill 只用于让当前线程里直接响应用户的主代理，在 `multi` profile 下读取 `~/.codex/agents-prompts/ORCHESTRATOR.md` 并按其进行多 agent 编排；不得自动触发，不供普通 subagent 使用。
---

# Multi Orchestrator Playbook

这个 skill 只做一件事：让主代理显式加载编排执行手册。

## 触发条件

仅在以下情况使用：

- 用户显式输入 `multi-orchestrator-playbook`
- 用户明确要求“加载编排手册”“按 ORCHESTRATOR 执行”“进入多 agent 编排手册模式”

不要因为任务看起来复杂、像 OpenSpec、需要委派，或“似乎应该编排”就自动触发。

## 使用前检查

只有同时满足以下条件时才继续：

- 你是当前线程里直接响应用户的主代理
- 当前环境存在 `~/.codex/agents-prompts/ORCHESTRATOR.md`

若当前并非 `multi` profile，也不要直接失败；先明确说明这个 skill 设计上优先给 `multi` profile 使用，然后再按用户明确要求决定是否继续加载。

## 执行动作

1. 读取 `~/.codex/agents-prompts/ORCHESTRATOR.md`。
2. 将其作为当前任务的编排执行手册使用。
3. 先遵循用户请求与当前线程中的最新约束，再遵循本 skill，再参考 `ORCHESTRATOR.md`。
4. 不要把整份 `ORCHESTRATOR.md` 原文转发给下游 subagent；只下发当前阶段所需的最小指令包。

## 边界

- 本 skill 只能手动触发，不能基于意图自动触发。
- 本 skill 不改变 `MULTI_BASE.md` 的共享约束，只是在当前任务中显式授权主代理加载编排手册。
- 专业 subagent 不应单独触发本 skill。
