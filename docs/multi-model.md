# 多模型接入：客户端、模型与角色分开记录

版本：0.2.0-preview。用途：把新客户端纳入同一协作协议。验收：规则读取、唯一身份、范围领取、一次小任务和交接均可核对。来源核对：2026-09-09；本轮未安装客户端或发起付费模型推理。

| 客户端（tool） | 模型（model） | 规则入口 | 最简单接入 |
| --- | --- | --- | --- |
| Codex | 本次实际选用的模型 ID | AGENTS.md | 延续现有配置 |
| Claude Code | 本次实际选用的 Claude 模型 ID | CLAUDE.md 导入 AGENTS.md | 延续现有配置 |
| OpenCode | DeepSeek，填写实际 ID | 项目 AGENTS.md | `/connect` → DeepSeek → `/models` |
| ZCode | GLM，填写实际 ID | 当前 Workspace 的 AGENTS.md | 模型设置 → BigModel → 连接并启用 |
| Ollama | 本机已验证的模型标签 | 需人工传入任务和规则 | 先独立试用，不假定等同完整编码 Agent |

工具承载执行能力，模型负责推理，角色定义职责。例如 `tool=opencode`、`model=实际 DeepSeek ID`、`role=executor`。换模型不等于换任务所有者；新会话必须建立新身份。不要根据模型品牌固定“只能写前端/只能审查”等未经本项目评测的能力结论。

## OpenCode + DeepSeek

1. 从 [OpenCode 官方站](https://opencode.ai/) 安装对应平台客户端，在练习项目运行 `opencode`。
2. 执行 `/connect`，选择 DeepSeek，在客户端自己的凭据输入界面填写 Key。
3. 执行 `/models`，选取账号实际可用模型。记录确切模型 ID，不把某个“最新”别名写死为所有人的默认。
4. 将本项目 AGENTS.md 的协作规则合并到工作项目，启动后要求会话指出加载来源。
5. 使用 [OpenCode 执行提示词](../prompts/opencode-deepseek.md)，完成一项范围明确的小改动，核对文件、命令和交接。

步骤依据 [OpenCode DeepSeek 接入文档](https://opencode.ai/docs/providers/#deepseek)。项目 AGENTS.md 与可选 `instructions` 配置依据 [OpenCode Rules](https://opencode.ai/docs/rules/)。凭据不得复制进版本库；本指南不需要共享 auth.json。已有 AGENTS.md 时不要运行初始化后直接覆盖它。

## ZCode + GLM

1. 从 [ZCode 官方站](https://zcode.z.ai/) 下载并打开项目工作区。
2. 在模型设置中选择 BigModel，完成账号连接，启用有权使用的 GLM 模型；按实际订阅选择编程套餐或 API Key。
3. 优先使用账号连接流程。使用 API Key 时区分 Coding Plan 和普通 API 的端点，不能混用；具体填写以 [官方模型配置](https://zcode.z.ai/cn/docs/configuration) 为准。
4. 把核心协作约定放进当前 Workspace 的 AGENTS.md，启动后验证规则被读取。
5. 使用 [ZCode 执行提示词](../prompts/zcode-glm.md)，记录具体 GLM 模型、角色和修改范围。

ZCode 对 AGENTS.md 的加载与其他客户端不同：当前官方说明不支持逐层合并或 `@import` 展开；CLAUDE.md 迁移也不是持续同步机制。重要规则应直接位于 Workspace 的 AGENTS.md，额外资料在任务提示词中要求显式读取。[ZCode Agent 官方说明](https://zcode.z.ai/cn/docs/agents)

未找到经核实的 ZCode 完整客户端开源仓库，故只列官方入口，不编造仓库地址。

## 协作接入验收

先手工填 [接入验收表](../templates/onboarding-check.md)。认证成功只证明账号连接；必须实际核对规则读取、工具能力与文件访问。需要模型请求时在任务中限定域名、操作、预算和副作用。

进入 coord 的信息格式见 [面板与元数据](dashboard.md)。会话能调用终端时按现有 `coord heartbeat / claim / extend` 流程操作；不能调用时由用户分配范围并记录 offline-fallback，不伪造登记。运行环境在 WSL、容器或远程主机时，“localhost”可能不是 Windows 主机，首版面板仅支持与 coord 同机。

建议先由一个执行者完成小任务、另一会话复核，再增加并行执行者。接口文件、依赖锁文件和数据库迁移指定唯一负责人，增加模型数量不应增加同文件争用。
