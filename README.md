# xjtu-toolbox-ios

西安交通大学校园工具箱 iOS 版（SwiftUI）。

## 已对齐 Android 的核心功能
- 统一认证登录（CAS + 各子系统登录状态管理）
- 课表 / 考试 / 教材
- 成绩 / GPA / 报表成绩
- 考勤查询
- 空教室
- 图书馆座位
- 校园卡
- 通知公告
- 一网通办页面
- 本科评教 + 研究生评教
- 培养进度入口
- 校园付款码
- 内置浏览器 + WebVPN 地址互转
- 个人页 NSA 信息展示（基础字段 + 头像加载）

## Xcode 运行
1. 使用 Xcode 打开 `XJTUToolboxIOS.xcodeproj`。
2. 选择 `XJTUToolboxIOS` target 与模拟器/真机。
3. `Run` 直接启动。

## 工程说明
- 最低系统：iOS 17.0
- `Info.plist` 已加入网络访问配置（包含校园 HTTP 服务访问）
- 项目入口：`App/XJTUToolboxIOSApp.swift`
