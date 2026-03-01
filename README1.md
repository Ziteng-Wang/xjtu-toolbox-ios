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
1. 在 Xcode 中新建 iOS App 工程。
2. 将 `XJTUToolboxIOS` 目录下 `.swift` 文件加入工程 target。
3. 在 target 的 `Build Settings` 中确认可使用 `CommonCrypto`。
4. iOS 17+ 运行（建议真机调试网络与 Cookie 行为）。

## 说明
- 本目录为逻辑迁移代码，未包含 `.xcodeproj` 工程文件。
- 通知与部分评教页面解析存在站点模板差异，已做多策略兼容；若目标站点改版，需要更新解析规则。
