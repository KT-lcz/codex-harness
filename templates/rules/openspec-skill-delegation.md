1. `openspec-explore`
   - 主代理：`explorer` 或 `code-mapper`
   - 需要本地代码理解时，优先使用 `code-mapper`
   - 需要外部技术调研时，优先使用 `explorer`
   - 同时需要本地现状和外部方案时，可并行拉起 `code-mapper` 与 `explorer`
   - 对新项目或 greenfield 场景，必须把技术选型作为探索内容的一部分，不得跳过
   - 对新项目或 greenfield 场景，探索结论至少覆盖：推荐技术栈与备选方案、推荐架构模式与不采用方案、核心约束与非目标、关键取舍、已决定事项、暂定事项、待确认开放问题
   - 该阶段结束时，必须先由你向用户汇总探索结论，并明确区分“建议采用”与“尚未确认”
   - 在用户明确确认 explorer 结论之前，不得创建或修改 `openspec/config.yaml`
   - 只有在用户明确确认 explorer 结论之后，才允许追加 `architect` 将已确认的技术栈、架构模式和核心约束沉淀为 `openspec/config.yaml`
   - `openspec/config.yaml` 必须由 `architect` 生成，`explorer` 和 `code-mapper` 只负责探索与证据收集
   - 除 `openspec/config.yaml` 外，只有在确有必要把探索结果沉淀成正式文档时，才追加 `architect` 做汇总
   - 不得把该 skill 改写成固定流水线；不强制要求研究文档落盘
   - 该阶段可以根据探索情况向用户提问
2. `openspec-new-change`
   - 主代理：`quick`
   - 该 skill 只使用 `quick` 完成 change 初始化所需的轻量操作
   - 此阶段不提前拉起 `architect`、`scrum_master`、`coder`
   - 此阶段结束后，由你向用户返回结果并等待下一步
3. `openspec-propose`
   - 主代理：`architect`
   - 若需要先创建 change，可先短暂使用 `quick`，随后立即切回 `architect`
   - 如需要本地代码理解，可先使用`code-mapper`，随后立即切回 `architect`
   - `proposal.md`、`design.md` 和`spec.md`文件需要由`architect`输出
   - 设计类工件完成后，必须追加 `evaluator` 审查；若驳回，退回 `architect` 修订
   - 当流程进入任务拆解阶段时，由 `scrum_master` 产出 `tasks.md` 和 `coder_slices.md`
   - 若 `coder_slices.md` 无明确理由地退化为“一任务一 Slice”，视为切片质量不合格，先退回 `scrum_master` 重新合并切片，再继续推进
4. `openspec-ff-change`
   - 主代理：`architect`
   - 如需要本地代码理解，可先使用`code-mapper`，随后立即切回 `architect`
   - `proposal.md`、`design.md` 和`spec.md`文件需要由`architect`输出
   - 进入任务拆解阶段后，必须由 `scrum_master` 产出 `tasks.md` 和 `coder_slices.md`
   - 若 `coder_slices.md` 无明确理由地退化为“一任务一 Slice”，视为切片质量不合格，先退回 `scrum_master` 重新合并切片，再继续推进
5. `openspec-continue-change`
   - 主代理按当前 artifact 类型决定：
     - 方案/规范类：`architect`
     - 任务拆解类：`scrum_master`
     - 轻量整理类：`quick` 或 `doc_editor`
   - 如需要本地代码理解，可先使用`code-mapper`
   - 如果当前阶段产出 `design.md`，完成后必须追加一次 `evaluator` 审查
   - 如果当前阶段进入任务拆解，由 `scrum_master` 产出 `tasks.md` 和 `coder_slices.md`
   - 不得因为本地强化而跨越 skill 规定的单步推进边界
6. `openspec-apply-change`
   - 主代理：`coder`
   - 若实现前发现任务切片缺失、边界不清或重叠，先退回 `scrum_master` 修复切片，再继续实施
   - 当存在 `coder_slices.md` 时，按 Slice 顺序串行拉起 `coder`
   - 只把当前 Slice 中列出的任务交给当前 `coder`，不得跨 Slice 提前实现后续任务
   - 同一时刻只允许一个 `coder` 写代码
   - 当前 Slice 完成后，先确认对应任务在 `tasks.md` 中已更新状态，再关闭当前 `coder` 并拉起下一个
   - 如果 `coder_slices.md` 中的任务编号不存在于 `tasks.md`、编号重叠、顺序冲突或边界不清，先退回 `scrum_master` 修复，禁止继续实施
   - 如实施暴露设计问题，可回退到 `architect`；如暴露任务拆解问题，可回退到 `scrum_master`
7. `openspec-verify-change`
   - 固定顺序：`security-auditor -> verifier -> reviewer`
   - `security-auditor` 负责安全风险检查
   - `verifier` 负责测试执行与行为验证
   - `reviewer` 负责实现与 proposal/spec/design/tasks 的一致性审查
   - 任一阶段失败时，交回 `coder` 修复后再从失败阶段继续
   - 你负责汇总三段结果，对外输出 skill 所需的总验证结论
8. `openspec-sync-specs`
   - 主代理：`doc_editor`
   - 如需先判断实现现状、冲突影响或能力边界，可追加 `code-mapper`
   - 只有在 spec 冲突复杂、需要额外方案判断时，才追加 `reviewer` 或 `architect`
9. `openspec-archive-change`
   - 主代理：`doc_editor`
   - 归档前的状态确认与用户确认由你保留，不得绕过
   - spec 同步由 `doc_editor` 执行
   - `CHANGELOG.md` 更新由 `doc_editor` 执行
   - 归档移动由 `doc_editor` 执行
10. `openspec-bulk-archive-change`
    - 主代理：`doc_editor`
    - 保留 skill 原生的多选与确认步骤
    - 当多个 change 之间存在 spec 冲突或实现真假不明时，追加 `code-mapper` 检查本地实现证据
    - 必要时追加 `reviewer`、`architect` 或 `explorer` 协助判断冲突顺序与处理依据
    - 批量归档时，`doc_editor` 仍负责 spec 同步、`CHANGELOG.md` 更新和归档移动
