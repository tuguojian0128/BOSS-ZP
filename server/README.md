# 简历 API 服务

这是与 Flutter 简历模块契约对齐的第一版 Dart 后端。当前简历解析和投递执行器仍是演示实现，但服务已经接入 SQLite、JWT 登录和按用户隔离。

## 启动

在项目根目录执行：

```powershell
.tools/flutter/bin/cache/dart-sdk/bin/dart.exe run server/main.dart
```

服务默认监听 `http://127.0.0.1:8090`。

生产启动前请设置：

```powershell
$env:JWT_SECRET='替换为强随机密钥'
$env:APP_ENV='production'
```

登录接口和安全约束详见项目根目录的 [AUTH.md](../AUTH.md)。除注册、登录、刷新和授权回调外，业务接口都必须携带 `Authorization: Bearer <accessToken>`。

## 接口示例

创建导入任务：

```http
POST /api/v1/resumes/import
Content-Type: application/json
Authorization: Bearer <accessToken>

{"fileName":"resume.pdf","contentType":"application/pdf"}
```

上传文件：

```http
PUT /uploads/{uploadToken}
Content-Type: application/pdf
```

查询解析任务：

```http
GET /api/v1/resumes/{resumeId}/parse-task
```

读取或保存结构化简历：

```http
GET   /api/v1/resumes/{resumeId}/profile
PATCH /api/v1/resumes/{resumeId}/profile
DELETE /api/v1/resumes/{resumeId}
```

投递中心统计：

```http
GET  /api/v1/applications/dashboard
POST /api/v1/applications
```

统计接口返回各平台累计汇总、每日平台明细和最近投递记录；每日明细只返回每个平台当天的投递数量，不提供每日总量字段。

数据库说明见项目根目录的 [DATABASE.md](../DATABASE.md)。服务启动时会自动创建 `data/boss.db`。

平台账号与职位：

```http
GET  /api/v1/platform-accounts
POST /api/v1/platform-accounts/{platform}/authorize
GET  /api/v1/platform-accounts/callback?state={authorizationId}
POST /api/v1/platform-accounts/{platform}/disconnect
GET  /api/v1/jobs?keyword=Java&platforms=BOSS%20直聘&city=上海
```

自动投递任务：

```http
POST /api/v1/applications/batch
GET  /api/v1/applications/tasks/{taskId}
POST /api/v1/applications/tasks/{taskId}/pause
POST /api/v1/applications/tasks/{taskId}/resume
```

## 当前限制

- 简历和任务只保存在内存中；
- 解析器返回演示结构，尚未接入 PDF、Word、OCR；
- 上传限制为 10 MB，扩展名限制为 PDF、Word 和常见图片格式；
- 简历元数据、结构化资料和投递任务已写入 SQLite 并在启动时按用户恢复；文件二进制本身仍未接入对象存储，正式环境需迁移到对象存储和队列。
- 生产环境需要收紧 CORS、将授权 Token 加密后保存，并把演示解析器替换为真实解析服务。
