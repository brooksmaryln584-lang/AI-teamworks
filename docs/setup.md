# 搭建指南

版本：0.1.0-draft。用途：从空白练习项目跑通协作。验收：两个不同会话完成一次执行、独立复核与交接。命令以 PowerShell 为例；其他平台按上游说明调整。

## 1. 准备工具

按 [工具清单](tools.md) 中各上游说明安装 Git、Codex CLI 和 Claude Code。两者分别完成自己的官方登录流程；不要把凭据发给另一个 AI。编辑器和 provider 管理器不是第一轮的前置条件。

如果已安装 Node.js/npm，Codex 上游提供以下安装方式；它会修改用户工具环境，应由用户决定执行：

```powershell
npm.cmd install -g @openai/codex
```

用以下命令记录实际版本；成功只表示 CLI 可启动，不证明登录或模型请求成功：

```powershell
git --version
codex --version
claude --version
```

若 PowerShell 命中了被阻止的 npm.ps1 或 codex.ps1，可检查 `Get-Command npm,codex -All`，存在对应包装器时使用 `npm.cmd` 或 `codex.cmd`。不要为了单个包装器放宽全局执行策略。

## 2. 建立练习项目

在自己选择的开发目录执行：

```powershell
New-Item -ItemType Directory -Path ai-collab-demo
Set-Location ai-collab-demo
git init
New-Item -ItemType Directory -Path docs, reports, runs, memory
```

从本指南复制根目录 AGENTS.md、CLAUDE.md 与 .gitignore 到练习项目，保留已有项目文件时采用人工合并。新建 README.md，写明项目用途；从 [模板](../templates/task-and-handoff.md) 创建 `docs/task.md`，填入首次任务。不要运行并不存在于本包中的中枢脚本。

建议首次任务：执行会话只创建 `docs/hello.md`，包含目的、使用方式、验收方法三个小节；复核会话只读取该文件并写入自己的报告。

## 3. 先跑通最小协作

在练习项目分别打开 Codex 和 Claude Code。先让两者列出当前加载的规则来源，核对唯一身份、可修改范围和停止条件。使用 [提示词](../prompts/examples.md) 的执行与复核部分。

如果暂不安装 coord，任务卡写入 `offline-fallback`，由用户先分配互斥目录；执行者提交后复核者才开始读取稳定产物。不能确认是否有其他写入者时暂停修改。

## 4. 接入 coord

从 [coord 上游](https://github.com/DmarshalTU/coord) 选择适合系统的安装方式，先检查 `coord --version`。在单独终端、练习项目根目录启动本地服务：

```powershell
coord serve --addr 127.0.0.1:7777 --db ./runs/coord.sqlite
```

端口若已被占用，先确定现有服务归属；使用不同端口时，每个客户端命令都要加一致的 `--url`。不要将协调服务直接暴露到公网。

执行会话在另一终端运行：

```powershell
coord status
coord agents
coord tasks --limit 20
$agentId = 'executor-' + [guid]::NewGuid().ToString('N')
coord heartbeat --as $agentId
coord send 'demo: create docs/hello.md; scope=docs/hello.md' --kind task
```

复制 send 输出的真实任务 ID，保持同一会话使用同一个 agentId：

```powershell
$taskId = Read-Host '输入刚创建的任务 ID'
coord claim $taskId --as $agentId --lease 900
```

只有 claim 成功且范围无冲突才开始写入。长步骤前按需续租：

```powershell
coord extend $taskId --as $agentId --lease 900
coord heartbeat --as $agentId
```

产物稳定后执行者写提交记录。复核者使用另一身份检查文件并记录结果。复核通过后，任务持有者可关闭账本并发送完成通知：

```powershell
coord complete $taskId --ack 'demo independently reviewed; see review report'
```

这是本指南安排的关闭时点，不表示 coord 会自动验证报告。完整状态定义见 [工作流](workflow.md)。参数按本机 CLI help 核对；首次在新环境操作前再次检查。

## 5. 验收与扩展

- 两个客户端都能指出实际加载的共享规则。
- 执行者只改任务卡指定文件，提供实际检查命令和结果。
- 复核者有独立身份，检查同一版本产物，记录通过或失败的理由。
- 复核失败时修正并新建记录；通过后建立交接，不覆盖已交付报告。
- 如使用 coord，确认任务领取、续租和关闭均在正确服务上生效。

跑通后再把共享规则集中到一个私有中枢。项目保留规则引用位置、采用版本及必要项目规则；跨目录导入是否生效需要各客户端分别验收。中枢脚本应另行脱敏、分发和测试，不能只复制教程里的调用命令。
