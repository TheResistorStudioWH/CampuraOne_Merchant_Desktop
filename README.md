# Campura One 商家端

面向 Campura One 比赛演示的 Flutter 桌面商家端第一阶段原型。正式目标为 Windows，macOS runner 用于当前开发、预览和测试。学生 Android 端是另一个独立应用，不与本工程共用 runner 或业务状态。

## 当前功能

- 已审批商家的本地演示登录和会话恢复，持久化文件不保存密码。
- 总览：以主商户账号视角展示“主商户 → 子商户”的目录和权限层级、商品统计、分类分布与最近更新。
- 商品：搜索、分类、具体主店/子商户管理范围筛选、排序、详情和本地新增/编辑/删除；主商户可维护直营商品并代管名下子商户商品。
- 营销工作台：先建立促销事件，再在选中促销下新增、编辑和删除关联广告；支持 1:1 小广告与 3:1 横幅的内置素材预览。
- 基于 Google Material 3 的桌面组件体系：状态容器、Filter Chip、Menu、tonal 按钮、响应式卡片与完整焦点/悬停反馈。
- 工作区式布局：左侧总览/商品/营销导航，外观与账户管理位于左下角；右侧顶栏只显示当前页面，右侧留白。导航侧栏、商品列表和促销列表的分隔线均可拖动并记住宽度，双击恢复自动宽度；导航拖窄后收起文字。
- 内置暖橙、蜂蜜黄、日落橙黄、湖青和鲜绿 5 套主题，可跟随系统或手动选择浅色/深色。
- 1280×800 宽屏使用列表+右侧详情，窄窗口自动切换为独立详情页。
- 首次启动从只读 seed 初始化数据；原子写入失败会回滚，损坏文件会保留时间戳副本并恢复 seed。

促销与广告仍是本机演示数据，不会发布到学生端；广告只能选择内置素材，没有上传、审核或投放功能。当前只实现主商户账号视角，子商户登录后的低权限界面尚未实现。本阶段不连接生产 API，不修改 PHP 或数据库，也不实现申请审批、订单、库存和排队。

## 演示账号

- 账号：`demo_merchant`
- 密码：`CampuraDemo!2026`

登录页的“使用演示账号”会自动填入并登录。

## 开发和验证

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d macos
flutter build macos
```

如果工程放在 macOS File Provider 管理的目录中，签名阶段可能报告 `resource fork, Finder information, or similar detritus not allowed`。这属于目录扩展属性问题；将同一份源码复制到普通本地目录（不携带扩展属性）后构建即可。本次改动已在这种临时副本中完成 macOS Debug 构建验证。

Windows runner 已纳入工程，但 Flutter 要求在 Windows 环境中设置并构建 Windows 目标。将仓库拉取到 Windows 后执行：

```powershell
flutter doctor -v
flutter pub get
flutter run -d windows
flutter build windows
```

工程包含 `.vscode/` 推荐扩展和 macOS/Windows 调试配置，可直接用 Visual Studio Code 打开本目录。

## 快捷键

| 操作 | 快捷键 |
| --- | --- |
| 新增商品 | `Ctrl/Cmd+N` |
| 定位搜索 | `Ctrl/Cmd+F` |
| 保存编辑 | `Ctrl/Cmd+S` |
| 取消编辑/返回 | `Esc` |

## 代码结构

- `lib/src/domain/`：服务器字段形状、价格精度、查询和校验。
- `lib/src/data/`：可替换的 Auth/Catalog/Marketing Repository 与原子 JSON 持久化。
- `lib/src/state/`：Riverpod 应用状态与未保存修改标记。
- `lib/src/ui/`：Material 3 桌面主题、登录、总览、商品列表/详情/编辑和营销工作台。
- `assets/demo/`：只读目录 seed 和四张内置演示图。
- `test/`：领域映射、持久化与 Widget 流程测试。

应用支持目录中会生成 `session_v1.json`、`catalog_v1.json`、`marketing_v1.json` 和 `appearance_v1.json`。未来接入后端时，保留当前领域模型和 `{code,message,data}` 响应合同，替换 Repository 实现即可。
