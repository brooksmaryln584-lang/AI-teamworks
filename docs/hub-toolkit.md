# 从中枢提取的轻量工具包

版本：0.2.0-preview。用途：在文档流程之上加入结构化会话记录和新报告创建。验收：有效记录通过、缺少记忆的记录失败、重复创建报告不会覆盖前一份。

## 包含什么

| 来源组件 | 公开位置 | 处理 |
| --- | --- | --- |
| 中枢协作约定 | AGENTS.md、AI_WORKFLOW.md | 改写为无本机依赖的共享规则 |
| memory-first-coordination | skills/shared/memory-first-coordination/ | 保留核心 Skill、引用文档和三个脚本，替换示例本机路径 |
| 报告创建器 | scripts/new-report.ps1 | 复用 CreateNew 分配文件名行为 |
| 权限分级与配置所有权 | docs/permissions.md | 提炼通用流程 |
| Claude 命令工作方式 | prompts/examples.md | 整理为跨客户端提示词 |
| 私人启动器、安装修复器、Hook 与配置切换 | 不分发 | 本机耦合及安全边界需要另行适配验收 |
| 日志、历史报告、数据库、用户配置 | 不分发 | 运行资料保留在私有环境 |

这是选择性提取，没有将整个私有中枢或 Git 历史打包。

## 创建记录

在本仓库根目录执行下面的 PowerShell 示例。工作区参数使用真实目标项目；不要在同一运行重复创建同一路径，创建器当前会覆盖已有 receipt。

```powershell
$sessionId = [guid]::NewGuid().ToString('N')
$runId = 'run-' + $sessionId
$agentId = 'codex-' + $sessionId
$receiptPath = "./runs/$runId/session-receipt.json"
$scriptRoot = './skills/shared/memory-first-coordination/scripts'
& "$scriptRoot/new_receipt.ps1" -Tool codex -AgentId $agentId -SessionId $sessionId -RunId $runId -Project . -TaskId "local-$runId" -Role solo -OutputPath $receiptPath
```

创建的是空骨架。先编辑 JSON，填写 task.goal、task.scope、memory.sources/findings、live_checks、coordination.state/evidence；存在不确定项时也要记录。再运行：

0.2.0 起 `-Tool` 接受小写客户端标识（如 codex、claude、opencode、zcode、ollama），可附加 `-Model` 与 `-Provider` 记录真实选择。不要在这些字段填写 Key。旧的 Codex/Claude 调用保持兼容，其他客户端也不需要伪装成 codex。

```powershell
& "$scriptRoot/validate_receipt.ps1" -Path $receiptPath -Stage preflight
```

任务结束时填写 execution.changed_files、execution.tests 并把 execution.status 设为 submitted，执行：

```powershell
& "$scriptRoot/validate_receipt.ps1" -Path $receiptPath -Stage submission
```

记录字段见 [receipt 说明](../skills/shared/memory-first-coordination/references/receipts.md)。CLI 退出码是结构检查结果，不是任务真实完成的证明。

## 独立复核

由另一真实会话创建 reviewer 记录，绑定 task_id、执行者 agent_id、执行者 receipt 路径及 SHA-256，填写复核证据。先确保执行者提交记录通过 submission，再运行：

```powershell
./skills/shared/memory-first-coordination/scripts/validate_review_pair.ps1 -ExecutorReceipt ./runs/executor/session-receipt.json -ReviewerReceipt ./runs/reviewer/session-receipt.json
```

上面两个路径为结构示例，执行前替换成实际文件。现有配对脚本核对执行者记录哈希、部分字段和身份差异，不认证真实身份，不对全部产物做内容哈希，不自动运行测试，也不保证每个声明都真实；`subject_receipt_path` 仅检查非空。复核者仍须固定并检查实际产物版本。

## 新建不可覆盖的报告

```powershell
./scripts/new-report.ps1 -Project . -Kind work -Slug first-task -RunId $runId
```

脚本返回新文件路径，填写本次工作。文件创建时避免覆盖；创建后操作系统仍允许手动修改，因此“交付后不可变”仍是团队规则。

## 支持与边界

首版以 Windows PowerShell 环境为主。脚本是从中枢提取的辅助工具，当前不强制核对 coord 租约或 scope 内文件，不限制实际工具权限。不要把字段校验成功当作安全审计通过。首次部署仍需独立环境验收。

## 工具包冒烟检查

运行 evals/run-public-toolkit.ps1。检查有效和无效记录、拒绝同身份复核、拒绝错误哈希，以及重复创建报告不覆盖。测试使用合成记录，不代表真实独立复核；临时文件保存在默认忽略的 runs 目录。
