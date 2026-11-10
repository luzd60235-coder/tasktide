# 任务潮汐

Mac 原生单机任务管理 App。无需登录、网络、服务器或第三方依赖。

## 安装

在 Releases 下载 `TaskTide-1.1.0-macOS-arm64.zip`，解压后将“任务潮汐.app”移入“应用程序”。适用于 Apple 芯片 Mac，macOS 14 或以上。本地构建使用临时签名，尚未经过 Apple 公证。

## 使用

- 右上角添加任务：名称、截止时间、紧急程度（从容 / 普通 / 重要 / 紧急）。
- 任务按实际紧急程度、截止时间排序。截止前 24 小时内自动提一级；到期或逾期为紧急。
- 点击卡片依次编辑进度（0–100）、下一步，或提前完成、取消任务。点击“保存并返回”保存修改。
- 进度以百分比和卡片背景填充显示。100% 后仍需点击完成来归档。
- 已完成任务在“已完成”，取消任务在右上角“废弃任务”；两者都能恢复。
- 完成任务时，卡片会裂成玻璃碎片散落淡出，下方卡片平滑上移补位。系统开启“减弱动态效果”时使用淡出。
- 剩余和逾期天数按实际小时除以 24 并向上取整。小于 24 小时显示“剩余 1 天内”。
- 时间信息每 30 秒刷新。App 关闭时不发送系统通知；重新打开即按当前时间计算。

## 数据

`~/Library/Application Support/TaskTide/tasks.json`

每次成功保存会保留前一份 `tasks.json.backup`。应用菜单“帮助”可打开数据目录。

## 构建

需要 Apple Command Line Tools（Swift 编译器）及 Python 3。在项目根目录运行 `sh build.sh`，生成 App 和可分发的 ZIP。

```sh
swiftc -target arm64-apple-macos14.0 -parse-as-library Sources/*.swift -o TaskTide -framework SwiftUI -framework AppKit
swiftc Sources/Core.swift Tests/CoreTests.swift -o /tmp/TaskTideTests
/tmp/TaskTideTests
```

面向 Apple 芯片 Mac，macOS 14 或以上。
