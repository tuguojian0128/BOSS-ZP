# 数据库阶段说明

当前后端已加入 SQLite 持久化层，启动服务时会自动创建 `data/boss.db` 并执行版本迁移。

## 已建表

```text
users                    用户
resumes                  原始简历文件和解析状态
resume_profiles          结构化简历版本
platform_accounts        招聘平台授权状态（不保存明文密码或 Cookie）
jobs                     职位主数据
application_tasks        批量投递任务
application_records     单条投递记录
daily_application_stats 每日按平台投递数量
audit_logs               操作审计
refresh_tokens           轮换后的刷新令牌摘要
```

## 本地运行

```powershell
.tools/flutter/bin/cache/dart-sdk/bin/dart.exe run server/main.dart
```

默认数据库文件：`data/boss.db`。可以使用环境变量切换路径：

```powershell
$env:APP_DATABASE_PATH='data/dev.db'
.tools/flutter/bin/cache/dart-sdk/bin/dart.exe run server/main.dart
```

## 生产迁移建议

SQLite 适合单机开发和本地联调。生产环境建议迁移到 PostgreSQL，并保留相同的表职责和索引。数据库文件需要纳入备份策略，不能提交到代码仓库；授权 Token 必须在写入前加密，日志不得记录简历原文、密码或第三方会话凭证。

当前 schema migration 版本为 v3。v2 为 `users` 增加密码摘要、盐、账号状态和最近登录时间，并新增 `refresh_tokens`；v3 为简历增加 `content_type`、为投递任务增加 `jobs_json`，服务启动会自动从旧版本升级，不需要手动删除现有数据库。简历元数据、结构化资料和投递任务现在会在服务启动时恢复到当前用户的内存工作集，投递记录及每日平台统计持续写入 SQLite。
