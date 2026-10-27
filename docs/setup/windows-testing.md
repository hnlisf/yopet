# Windows 本地桌面测试版

## 2026-10-25 最新 Release 测试包

- 包：`artifacts/yopet-windows-local-20261025-095331-239.zip`。
- SHA256：`E96F2946BDA97344AF08E763F5D421115AA63F83A28B5F3FDAF57DF336FC33B2`。
- 静态分析无问题，116 项测试通过，Windows Release 编译与完整目录打包成功。
- 修正 Release 捕获路径读取调试专用属性的风险；临时计数仅在 Debug 启用。
- 用户确认此前 Debug 连续 60 分钟无冻结；此新包的长时间实机测试尚未进行。
- 下一步按 [Release 验收清单](windows-release-acceptance.md) 测试。
- 仍连接本机 `http://localhost:54331`，非签名安装包或生产发布包。

日期：2026-10-05

### 2026-10-06 新版测试包

最新布景刷新修复包：`artifacts/yopet-windows-local-20261006-083809-562.zip`。
SHA256：`14AB5EA9D3FA5C874D6EFD4821C152D0FA60843B14B7FD7A246B02B331888CE9`。
布景移除、添加、背景恢复及移动/缩放成功后主动刷新，不再只依赖实时事件。
本轮回归包含不发送实时事件的水草、石头、沉木移除，以及删除失败保留物品。
该包跳过重复检查步骤，分析与测试在打包前后独立运行；清单如实记录 `checksRun: false`。

- `artifacts/yopet-windows-local-20261006-082234-906.zip`。
- SHA256：`75B198A12F76644B0B970755E0557B6ED794A4B1F200C507A447D8D1BF942D81`。
- 包含方案 2 自适应工作台、紧凑选鱼布局及掉头过渡优化。
- 构建前静态分析无问题、83 项测试通过；zip 必需运行文件和 SHA256 已核对。
- 此记录表示构建与归档验证完成，不替代解压包实机测试或掉头自然度人工验收。
- 下方 2026-10-05 包为历史记录，不含本轮最新修改。

## 本轮交付

- Windows x64 Release 编译成功；程序已启动，现有账号鱼缸可以加载。
- 可执行程序：`build/windows/x64/runner/Release/yopet.exe`。
- 便携包：`artifacts/yopet-windows-local-20261005-094503.zip`（97,150,919 字节）。
- SHA256：`8EFA45814905F7FC735B18F147CE27CA363C08D905CFA9463273EA6FEE51F017`。
- 本机后端：`http://localhost:54331`。这是本地测试包，不是生产发布包。

## 使用

解压整个压缩包后，进入 `Release` 文件夹双击 `yopet.exe`。
不要仅复制 exe；`data` 文件夹及同目录 DLL 都必须保留。
保持本地 Supabase/Docker 服务运行。程序与网页共用后端，投喂、领养、送别等操作
会影响同一账号的数据。浏览器与桌面端的登录会话可能分别保存，需要用户自行登录。
其他电脑不能通过这个包的 localhost 地址连接本机的数据库。

## 手动检查（待用户确认）

1. 窗口最大化、还原和缩小后无裁切、溢出，主要按钮可见。
2. 观察五条鱼连续游动、避让和鱼鳍动画，检查明显卡顿与纹理异常。
3. 打开鱼档案、装饰面板、水温面板；点击、滚动和拖动符合预期。
4. 整缸投喂反馈与已有网页端一致。
5. 关闭并重开程序，账号会话与鱼缸数据正常；最小化再返回时反应正常。
6. 送别属于不可撤回的数据操作，仅由用户主动确认测试，不由自动化执行。

## 重新构建

```powershell
.\run-dev.ps1 -Platform windows -BuildOnly
```

## 可重复生成新版测试包

```powershell
.\package-windows.ps1
# Flutter 不在 PATH 时：
.\package-windows.ps1 -FlutterPath 'D:\path\flutter.bat'
```

先关闭 Release 版窗口；脚本不会自行停止进程。默认运行静态分析和回归测试，
随后用已安装的依赖构建 Windows Release，检查 exe、Flutter DLL、资源和 AOT 文件，
将整个 Release 文件夹打成新的时间戳压缩包。相邻 `.zip.json` 记录 SHA256、文件大小、
构建时间、Git 基线和工作区是否有已跟踪修改，不保存客户端 key 或其他凭据。
工作区版本不是单凭 Git 基线即可还原，`trackedChanges` 必须一并查看。

`-SkipChecks` 只用于已独立完成验收的重复构建；元数据会标明跳过检查。
这是本机测试包，不代替签名、安装器、生产后端和真实设备验收。

构建读取与开发运行相同的本地配置，只打印地址和客户端 key 已配置的状态，
不打印凭据。正式分发还需生产认证地址、真实设备性能测试、签名与安装分发安排。
