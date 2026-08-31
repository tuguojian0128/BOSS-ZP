# 前端架构说明

## 目标

当前版本优先完成前端可视化和用户流程验证，后端暂时使用本地模拟数据。后续接入真实服务时，页面不应大规模重写，只替换数据仓库和服务实现。

## 分层原则

```text
页面层（Presentation）
  ↓ 只关心状态和用户操作
状态层（Controller / Riverpod）
  ↓ 调用抽象仓库
领域层（Domain）
  ↓ 定义职位、简历、投递和任务模型
数据层（Data）
  ├── Mock Repository       当前演示
  ├── REST Repository       后端 API
  └── BOSS Authorized API   BOSS 正式授权接口
```

## 推荐目录

```text
lib/
├── main.dart
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme.dart
├── core/
│   ├── network/
│   ├── storage/
│   ├── security/
│   ├── errors/
│   └── widgets/
├── features/
│   ├── auth/
│   ├── resume/
│   ├── workbench/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── applications/
│   ├── interviews/
│   └── settings/
└── platform/
    └── boss/
```

## 简历模块流程

简历页面的主流程固定为：

```text
用户导入文件
   ↓
上传中
   ↓
后端自动解析、OCR 和字段识别
   ↓
识别完成
   ↓
用户校对和补充
   ↓
保存结构化简历
```

识别内容包括基本信息、工作经历、教育背景、项目经历、证书和技能。页面不再提供“AI 优化”作为主要动作，避免把识别和改写混在一起；后续如果增加 AI 建议，也应作为独立的可选功能。

目前为了快速看到完整页面，演示 UI 和状态控制集中在 `lib/main.dart`。下一步接入后端时，将把页面、Controller、模型和仓库按上面的目录拆开。

## 数据仓库接口

页面不直接请求 BOSS，也不直接依赖 HTTP。页面只依赖仓库接口：

```dart
abstract interface class WorkbenchRepository {
  Future<List<Job>> searchJobs(JobSearchQuery query);

  Future<JobDetail> getJobDetail(String jobId);

  Future<ApplicationPreview> previewApplication(
    String jobId,
    String resumeVersionId,
  );

  Future<ApplicationResult> submitApplication(
    ApplicationRequest request,
  );
}
```

实现方式可以切换：

```text
MockWorkbenchRepository       本地演示数据
RestWorkbenchRepository       调用自有后端
BossAuthorizedRepository      调用后端的 BOSS 授权适配器
```

这样可以在后端尚未完成时先开发和验收页面，后端完成后无需修改页面交互。

## 页面状态

工作台至少需要以下状态：

```text
初始状态
筛选中
筛选成功
筛选为空
筛选失败
投递待确认
投递排队中
投递中
投递成功
投递失败
需要用户处理验证码
登录状态失效
```

这些状态应由 Controller 或 Riverpod Notifier 管理，页面只负责展示状态和触发操作。

## 后端接口契约优先

前端开发可以先使用 Mock 数据，但必须先固定接口输入输出。例如：

```text
POST /api/v1/jobs/search
POST /api/v1/applications/preview
POST /api/v1/applications/batch
GET  /api/v1/applications
GET  /api/v1/applications/:id
```

接口契约至少要包含：

- 分页；
- 职位来源平台；
- 外部职位 ID；
- 匹配度和匹配原因；
- 简历版本 ID；
- 投递任务 ID；
- 任务状态；
- 错误码；
- 是否需要用户操作；
- 是否允许重试。

## 前端先行的正确方式

先做前端是合理的，但不建议“前端写完后再猜后端”。推荐顺序是：

1. 先确认页面和用户流程；
2. 为页面定义 Mock 数据；
3. 同步定义 API 契约和错误状态；
4. 用 Mock 仓库完成页面；
5. 后端按照契约实现；
6. 用真实仓库替换 Mock 仓库；
7. 联调、测试和灰度发布。

这样既可以快速看到产品，又不会因为后端数据结构不匹配而返工。
