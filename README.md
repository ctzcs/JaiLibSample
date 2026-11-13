# JaiLibSample

验证相邻 `JaiLib` 的示例集合，沿用 `olib_sample` 的 `src/<sample>/` 结构。
已迁移 `ui_gallery`、`game_ui`、`ui_motion`、`book_ui`。

## 在 Zed 中运行

打开本文件夹，在命令面板执行 `task: spawn`，选择示例名称。
每个示例只有一个运行任务，直接调用 `jacket run`；没有 bat 或额外的构建任务。
`jacket.toml` 配置共享导入路径，默认入口仍是 `ui_gallery`。

## 依赖和命令行

- Windows + 支持 SDL_GPU 的显卡/驱动。
- `jacket` 在 PATH 中；本机版本为 0.35.1，位置为 `D:\Lib\jacket-windows-x64`。
- 相邻检出的 `../JaiLib`（包含 `foster` 模块）。目录不同则修改 `jacket.toml` 的 `import_path`。
- 示例与 JaiLib UI / 渲染模块统一使用 `#import "foster"`。不要混用独立的 `#import "jfoster"`，
  否则 `Msdf_Font`、`Texture`、`Rect` 等同名类型来自不同模块，会出现参数类型不匹配。

也可以在项目根执行：

```sh
jacket run -exe build/ui_gallery
jacket run -exe build/game_ui src/game_ui/main.jai
jacket run -exe build/ui_motion src/ui_motion/main.jai
jacket run -exe build/book_ui src/book_ui/main.jai
```

`--` 后的参数传给示例；命令形式见 [Jacket CLI 文档](https://github.com/matteopolak/jacket/blob/main/docs/tools/jacket.md)。
当前 jfoster 原生库绑定可直接加载依赖，已验证在没有预复制 DLL 的新输出目录编译运行。
字体使用 jfoster 内置资源；game_ui 的按钮皮肤和 book_ui 的预编译 shader 随源码保存，无需下载。
内置 Roboto 提供拉丁字形，示例文案使用英文。
若链接报 LNK1104 无法打开示例 exe，请先关闭此前运行的同名示例窗口再运行。

## 示例内容

| 示例 | 内容与操作 |
| --- | --- |
| `ui_gallery` | 纯 UI 控件、文本输入、列表滚动、弹窗、键盘焦点 |
| `game_ui` | 遗迹场景、技能冷却、背包、暂停设置；点击移动，1–6 技能，B 背包，Esc 暂停 |
| `ui_motion` | 卡牌拖放、交换行动槽、手牌排序、补间动画、奖励弹窗；点击或 Enter 入队，GO 执行，Esc 取消 |
| `book_ui` | 六页可交互的 3D 书、弯曲双面翻页、深度遮挡、射线拾取；左右键翻页，Space 暂停，右拖旋转，Shift+右拖侧倾，中拖平移，滚轮缩放，R 复位 |

game_ui 的音量和音乐开关、book_ui 的施法与物品等是内存中的演示状态，没有音频播放或存档。

### ui_gallery 细节

- 文本输入、开关、音量滑条、质量下拉框、联动进度条。
- Apply、禁用控件、重置确认/取消弹窗。
- 24 行可选组件列表、内层裁剪滚动、窄屏外层滚动。
- Tab / Shift+Tab 焦点、Enter 激活、左右键调节滑条；Esc 关闭下拉/编辑/弹窗，之后退出应用。
- UTF-8 文本编辑、Ctrl+V；设置仅保存在本次运行的内存中。
- 默认 1120×800；`narrow` 为 760×800；`scaled` 为 125% UI 缩放；`shot` 截图退出；`smoke` / `auto` 自检退出。

## 代码入口

| 文件 | 职责 |
| --- | --- |
| `.zed/tasks.json` | 每个示例一个 jacket 运行任务 |
| `jacket.toml` | 默认入口和导入路径 |
| `src/ui_gallery/main.jai` | 生命周期、输入、DPI 转换、Render2D 提交、资源释放 |
| `src/ui_gallery/view.jai` | Clay 布局、设置、列表、弹窗 |
| `src/ui_gallery/font.jai` | jfoster 字体到 JaiLib UI 的度量/UV 适配 |
| `src/ui_gallery/smoke.jai` | 确定性输入、自检、GPU 读回与 PNG 输出 |
| `shared/ui_sample.jai` | 新示例共用的窗口、字体、输入、缩放与截图宿主 |
| `src/game_ui/` | 场景、HUD、按钮皮肤 |
| `src/ui_motion/` | 卡牌状态、拖放、补间与界面 |
| `src/book_ui/` | 页面 UI、书页网格、相机、射线拾取、3D 渲染及 shader |

渲染链为 `jfoster → kit/rendering/material → kit/rendering/2d → kit/ui`。
控件使用 JaiLib 公开 API，布局使用 `clay.UI(..., #code {...})`。

## 实际发现的接入问题

1. jfoster 材质惰性初始化：创建 Render2D 前调用 `defaults_batch_material`，绘制 MSDF 文字前调用
   `defaults_msdf_material`，否则 JaiLib 的内置字体材质无法创建。
2. `jfoster.msdf_font_load_bytes` 保留 em 行高和像素 atlas bounds，JaiLib UI 要求像素行高和归一化 UV。
   `font.jai` 复制字形并归一化，借用其余资源，不修改 device 持有的字体。
   适配专用于内置 **top-origin Roboto**，不能直接套用 bottom-origin 字体。
3. jfoster 的 SDL_GPU 管线使用顺时针正面。book_ui 调整纸张索引绕序，让双面 shader 的正面
   与逻辑页面正面一致，否则可见的页面会采样到白色背衬。

这些适配都在 sample 内，相邻 JaiLib / jfoster 源码未修改。上游统一字体约定后应同步调整，避免重复归一化。

## 验证范围

此前已通过宽/窄窗口 × 100%/125% 缩放的四轮自检，每轮 20 项检查：按钮按下/释放、滑条键盘调节、
文本输入、下拉选择、应用、弹窗隔离、取消/确认、列表选择、滚动、运行时窗口缩小、Tab 焦点、禁用控件、
布局错误计数，以及四次真实 GPU 像素读回。终端显示 `SMOKE PASS (20 checks)` 表示本轮通过；失败返回非零退出码。
截图保存初始、弹窗、滚动、窄屏缩放场景。

自动输入注入在 `kit/ui` 宿主边界，属于集成测试，不等同于操作系统鼠标/键盘自动化。
GPU 读回是渲染冒烟检查，不是逐像素视觉回归。

新增示例也支持 `-- smoke`、`-- shot`、`-- scaled` 和 `-- narrow`，例如：

```sh
jacket run -exe build/book_ui src/book_ui/main.jai -- smoke scaled
jacket run -exe build/book_ui src/book_ui/main.jai -- shot turn
jacket run -exe build/game_ui src/game_ui/main.jai -- shot modal
```

game_ui 自检覆盖技能冷却、背包选择、暂停、音量滑条、开关、返回；ui_motion 覆盖拖放、
交换、排序、队列执行、弹窗、窗口缩小与键盘入队；book_ui 覆盖六页控件、正反翻页、
暂停、边界、状态保留、姿态变换与缩放后的拾取、封底遮挡、键盘操作和实际页面纹理读回。
ui_motion 和 book_ui 的 smoke 会在末段将窗口改为 760×800、UI 缩放改为 125%。
新增示例截图保存在 `library/screenshots/<示例>-<初始缩放>-<模式>.png`。

book_ui 的 3D 路径使用 `kit/world`、`kit/rendering/3d` 的矩阵与 uniform 数据打包，以及 jfoster 的
网格和深度渲染接口。随附 D3D12/Vulkan shader；本机验证后端是 D3D12，未验证 Vulkan。
其余示例及音频、网络、热重载等能力仍待迁移验证。
