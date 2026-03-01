# xjtu-toolbox-ios

`xjtu-toolbox-ios` 是基于 `xjtu-toolbox-android` 迁移的 iOS 版本（Swift + SwiftUI）。

## 目标
- 保留安卓端核心业务逻辑：统一认证、SSO、自动登录、课表、成绩、考勤、空教室、图书馆、校园卡、通知。
- UI 采用 iOS 交互习惯：`TabView + NavigationStack + sheet + refreshable`。
- 网络与认证实现与安卓逻辑对齐：CAS 登录、RSA 密码加密、Token/Cookie 续期、WebVPN URL 代理。

## 目录结构

```text
xjtu-toolbox-ios/
└─ XJTUToolboxIOS/
   ├─ App/
   ├─ Core/
   │  ├─ Networking/
   │  ├─ Security/
   │  ├─ Storage/
   │  └─ Utils/
   ├─ Modules/
   │  ├─ Auth/
   │  ├─ Schedule/
   │  ├─ JWApp/
   │  ├─ ScoreReport/
   │  ├─ Attendance/
   │  ├─ EmptyRoom/
   │  ├─ CampusCard/
   │  ├─ Library/
   │  ├─ Notification/
   │  ├─ YWTB/
   │  ├─ GMIS/
   │  └─ Judge/
   └─ UI/
      ├─ Components/
      └─ Screens/
```

## 已迁移能力
- 统一认证基础类 `XJTULogin`（CAS 初始化、RSA 加密、账号选择、登录状态机）。
- 子登录器：`AttendanceLogin`、`JwxtLogin`、`JwappLogin`、`YwtbLogin`、`LibraryLogin`、`CampusCardLogin`、`GmisLogin`、`GsteLogin`。
- 自动登录状态管理 `AppLoginState`。
- 核心 API：
  - 课表/考试/教材 `ScheduleAPI`
  - 成绩/GPA `JWAppAPI`
  - 报表成绩 `ScoreReportAPI`
  - 考勤 `AttendanceAPI`
  - 空教室 `EmptyRoomAPI`
  - 校园卡 `CampusCardAPI`
  - 图书馆 `LibraryAPI`
  - 通知聚合 `NotificationAPI`
  - 一网通办 `YWTBAPI`
  - 研究生模块 `GmisAPI` / `JudgeAPI` / `GsteJudgeAPI`
- SwiftUI 页面：主页、教务、工具、我的，以及各业务模块页面。

## 运行方式
1. 在 Xcode 中打开 `XJTUToolboxIOS.xcodeproj`。
2. 选择 `XJTUToolboxIOS` target 与模拟器/真机。
3. 直接运行（iOS 17+）。

## 说明
- 仓库已包含可运行工程文件 `XJTUToolboxIOS.xcodeproj`。
- 通知与部分评教页面解析存在站点模板差异，若目标站点改版，需要更新解析规则。

