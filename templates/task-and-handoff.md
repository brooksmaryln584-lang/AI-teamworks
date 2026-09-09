# 任务、会话记录与交接模板

版本：0.1.0-draft。用途：无需自动化脚本也能保留协作证据。验收：填写后另一位执行者可以定位范围、产物和恢复位置。以下为手工模板，空字段不得被视为已通过门禁。

## 任务卡：保存为 docs/task.md

```text
task_id:
目标与交付物:
读取范围:
允许修改范围:
禁止事项:
负责人及角色:
验收标准与命令:
风险与授权边界:
最大轮次: 6
预算/运行时长上限:
停止条件:
```

## 会话记录：保存为 runs/<run_id>/receipt.md

```text
tool / agent_id / session_id / run_id:
process_id（可获得时）:
task_id / role / file_scope:
记忆来源:
本次发现:
不确定项:
实时检查及时间:
coordination: claimed 或 offline-fallback
任务 ID、租约到期时间或离线范围确认依据:
proxy_by 和原因（无代理则写无）:
修改前手工 preflight: 字段齐全、身份唯一、范围无冲突、测试方式可用
current_round / max_rounds:
status: working 或 submitted
变更文件和动作:
实际检查命令 / 退出码 / 时间 / 结果:
限制和未运行检查:
```

## 独立复核报告：保存为 reports/<唯一标识>-review.md

```text
task_id / reviewer_id:
executor_id / 执行者报告路径:
被审查提交或文件清单及 SHA-256:
实际检查与结果:
问题及严重程度:
未覆盖范围:
结论: 需要修正 或 verified
```

可以用 `Get-FileHash -Algorithm SHA256 <文件路径>` 获取单文件哈希。多文件产物逐项记录，或使用已审查的 Git 提交。哈希绑定内容，不证明审查者真实身份。

## 交接：保存为 reports/<唯一标识>-handoff.md

```text
本次身份与任务:
本次完成的范围:
文件及版本:
实际验证证据:
当前状态:
未完成项与风险:
下一步及检查点:
剩余轮次和预算:
需要重新核对的环境状态:
```

每次新建文件，已交付报告保持原样。只有脱敏且适合公开的报告才可选择性提交；本包 .gitignore 默认排除 runs 与 reports。
