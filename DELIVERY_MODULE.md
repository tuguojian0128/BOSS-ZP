# 自动投递主链路

面试管理暂不纳入当前版本。产品主链路收敛为：

```text
筛选职位 → 检查已连接平台 → 检查简历 → 用户确认 → 创建批量任务 → 逐条投递 → 记录结果 → 更新每日平台统计
```

## 前置校验

- 筛选结果包含未连接平台时，阻止开始并提示到“平台账号”；
- 没有已识别简历时，阻止开始；
- 已经投递过的职位需要去重；
- 批量任务需要用户明确确认；
- 投递过程支持暂停和继续；
- 单条失败不应阻塞其他职位；
- 每个平台遵守官方 API 限流和每日上限。

## API

```text
POST /api/v1/applications/batch
GET  /api/v1/applications/tasks/{taskId}
POST /api/v1/applications/tasks/{taskId}/pause
POST /api/v1/applications/tasks/{taskId}/resume
```

批量创建请求示例：

```json
{
  "resumeId": "resume_001",
  "jobs": [
    {"id":"boss-001","platform":"BOSS 直聘","title":"高级 Java 开发工程师","company":"星河科技"}
  ]
}
```

当前 Dart 服务使用内存任务和演示执行器；接入真实平台时，只需将执行器替换为官方授权适配器，保留任务状态和审计记录结构。

