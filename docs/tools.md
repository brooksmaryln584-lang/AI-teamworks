# 应用仓库与来源

文档版本：0.1.0-draft。链接于 2026-09-09 读取核对；不把上游最新版本自动当作本方案已测试版本。

| 工具 | 用途 | 上游仓库 | 接入级别 |
| --- | --- | --- | --- |
| Codex CLI | 代码执行和审查 | [openai/codex](https://github.com/openai/codex) | 核心 |
| Claude Code | 代码执行和审查 | [anthropics/claude-code](https://github.com/anthropics/claude-code) | 双工具协作核心 |
| coord | 任务领取、租约和状态协调 | [DmarshalTU/coord](https://github.com/DmarshalTU/coord) | 多会话推荐 |
| CC Switch | 管理支持工具的配置切换 | [farion1231/cc-switch](https://github.com/farion1231/cc-switch) | 可选 |
| Ollama | 本地模型运行 | [ollama/ollama](https://github.com/ollama/ollama) | 可选 |
| uv | Python 环境与包管理 | [astral-sh/uv](https://github.com/astral-sh/uv) | Python 项目可选 |
| PowerShell | 脚本执行环境 | [PowerShell/PowerShell](https://github.com/PowerShell/PowerShell) | 本教程命令环境 |
| GitHub CLI | GitHub 命令行操作 | [cli/cli](https://github.com/cli/cli) | 可选 |
| VS Code | 编辑器与会话入口 | [microsoft/vscode](https://github.com/microsoft/vscode) | 可选 |

本清单不表示这些工具均已在本次任务中安装或联合测试。coord 地址由上游说明与本机命令特征交叉匹配，未对本机二进制做来源哈希证明。

## 规则加载依据

- Codex 使用项目 `AGENTS.md`；详见 [OpenAI 官方规则文档](https://learn.chatgpt.com/docs/agent-configuration/agents-md)。
- Claude Code 的 `CLAUDE.md` 支持使用 `@` 导入文件；详见 [官方记忆文档](https://code.claude.com/docs/en/memory)。
- coord 的领取、租约、MCP 及命令参数见 [上游 README](https://github.com/DmarshalTU/coord)。本包优先展示 CLI，MCP 是可选适配。

安装步骤以对应上游 README 和 Releases 为准。只保存经过审阅的示例配置，保留第三方许可证和来源说明，不把认证文件当作模板。
