# 协作展示窗口

版本：1.2.0。用途：在浏览器中查看 coord 任务和会话。验收：能加载真实列表、刷新变化、筛选任务，并在服务中断时提示数据过期。

## 启动

需要 Python 3.10+，面板只使用标准库，无需安装 npm 或 Python 第三方依赖。在本仓库根目录运行：

```powershell
python -m dashboard.server --open
```

打开 [本地协作窗口](http://127.0.0.1:8787/)。默认读取同机 `http://127.0.0.1:7777/` 的 coord。窗口每 5 秒刷新，可取消勾选暂停，点击按钮立即刷新。

Windows 如果不想一直保留终端，可以运行 `./scripts/start-dashboard.ps1 -OpenBrowser`。它在后台启动面板并打印进程记录路径，不安装开机自启任务。停止时先核对记录中的 PID、启动时间与实际命令行，再停止对应进程；不要直接结束所有 Python 进程。同一端口只启动一次。演示后台启动可使用 `-Demo -Port 8788`。

如果还没有运行 coord，在另一个终端先为本项目启动服务：

```powershell
New-Item -ItemType Directory -Force runs
coord serve --addr 127.0.0.1:7777 --db ./runs/coord.sqlite
```

不要重复启动已经存在的 coord。任务客户端与面板必须连接相同端口和数据库。其他端口用 `python -m dashboard.server --coord-url http://127.0.0.1:7778/ --port 8789 --open`。停止面板在其终端按 Ctrl+C；不会停止 coord。

只想先看界面：

```powershell
python -m dashboard.server --demo --port 8788 --open
```

演示模式始终标注 DEMO，使用合成数据，不连接 coord。真实窗口与演示窗口分别使用 8787、8788 端口。

## 能看到什么

- 最近 200 条任务的待领取、进行中、需要关注和已完成数量；不是全部历史统计。
- 任务状态、负责人、模型声明、文件范围、交接路径与租约剩余时间。
- 每个会话的唯一身份、最近心跳和关联任务；“近期活跃”采用 120 秒阈值，仅供观察。
- 搜索、状态筛选、详情展开、手动刷新与暂停自动刷新。
- 连接失败会保留并标记浏览器内上一份快照；首次失败显示未知，不显示零任务完成。

“需要关注”来自失败状态、显式 blocker 或租约不足 60 秒/过期/缺失，不推断模型心理状态。blocked、submitted、verified 并不是 coord 原生调度状态；独立复核需查报告。面板不会读取日志判断模型是否真的在思考。

## 可选任务元数据

普通 coord 任务无需改造即可显示。要显示工具、模型、范围和交接路径，在创建任务时使用 `payload.teamworks`。可复制 [task-payload.json](../templates/task-payload.json)，把样例值换成实际任务信息；不要把凭据、原始提示词或私人内容放入 payload。

PowerShell 7 示例，在本仓库根目录执行：

```powershell
$payload = Get-Content -Raw ./templates/task-payload.json
coord send '实现约定模块' --kind task --payload $payload
```

Windows PowerShell 5.1 对原生命令的 JSON 引号处理可能不同；执行后必须检查 coord 数据是否保留字段，必要时使用 PowerShell 7。已创建任务没有通用的 payload 更新命令，本版不假设能更新：变化通过新交接记录/后继任务表达，别为了改展示信息重复领取原任务。

只有 `teamworks.tool/model/role/scope/project/blocker/handoff` 会投影到面板。其他 payload 和 result 不下发。字段未填写时显示“未声明”，不根据会话名称猜模型。详细契约见 [交接协议](handoff-protocol.md)。

## 范围与安全

服务固定监听 127.0.0.1，拒绝外部 coord URL、重定向、跨来源 API 访问和未知 Host。它不提供任务变更 API，不代替会话 heartbeat、claim 或 complete；静态文件采用固定路径白名单。

读取 `tasks/list` 仍可能触发 coord 自身的过期租约回收。这是 coord 上游的列表行为，不能把它描述成底层数据库绝对无变更。[coord 上游](https://github.com/DmarshalTU/coord)

此面板不是带账号隔离的多人公网服务，勿用反向代理直接暴露。任务名称和白名单元数据仍可能包含敏感内容；内置定向脱敏无法识别所有秘密，屏幕分享前应人工检查。客户端轮询只在面板打开且自动刷新开启时进行，不是后台 AI 自主执行循环。

## 验证

```powershell
python -m unittest dashboard.test_server -v
python -m unittest dashboard.test_coord_integration -v
```

检查列表接口、错误响应、演示隔离、数据字段白名单、异常日期、任务数量上限、同源限制和路径边界。集成验收还需启动真实 coord 并实际创建、领取和完成一项测试任务；不要把合成测试结果当作真实多模型协作记录。
